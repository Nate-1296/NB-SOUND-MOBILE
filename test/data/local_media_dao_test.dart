import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> sembrarLocal() async {
    await db.localMediaDao.upsertLocal(
      artistasLocales: <ArtistasCompanion>[
        ArtistasCompanion.insert(
            id: const Value(-7), nombre: 'A', origen: const Value('local')),
      ],
      albumsLocales: <AlbumsCompanion>[
        AlbumsCompanion.insert(
            id: const Value(-50), titulo: 'X', origen: const Value('local')),
      ],
      pistasLocales: <PistasCompanion>[
        PistasCompanion.insert(
          id: const Value(-100),
          titulo: 'X',
          artistaNombre: 'A',
          albumId: const Value(-50),
          artistaId: const Value(-7),
          origen: const Value('local'),
        ),
      ],
    );
  }

  test('upsertLocal + pistasPorOrigen separa local de pc', () async {
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(id: const Value(10), titulo: 'PC', artistaNombre: 'A'),
    ]);
    await sembrarLocal();

    expect((await db.localMediaDao.pistasPorOrigen('local')).single.id, -100);
    expect((await db.localMediaDao.pistasPorOrigen('pc')).single.id, 10);
    expect(await db.localMediaDao.contarLocales(), 1);
  });

  test('borrarPistasLocales quita pista + membresías + favorito', () async {
    await sembrarLocal();
    final int plId = await db.into(db.playlistsLocales).insert(
          PlaylistsLocalesCompanion.insert(
            nombre: 'L',
            creadoEn: DateTime.now(),
            actualizadoEn: DateTime.now(),
          ),
        );
    await db.into(db.playlistLocalPistas).insert(
          PlaylistLocalPistasCompanion.insert(
              playlistId: plId, pistaId: -100, posicion: 0),
        );
    await db.favoritesDao.setFavorita(-100, true);

    await db.localMediaDao.borrarPistasLocales(<int>[-100]);

    expect(await db.localMediaDao.pistasPorOrigen('local'), isEmpty);
    expect(await db.select(db.playlistLocalPistas).get(), isEmpty);
    expect(await db.select(db.favoritosLocal).get(), isEmpty);
  });

  test('limpiarHuerfanosLocales borra álbum/artista locales sin pistas', () async {
    await sembrarLocal();
    await db.localMediaDao.borrarPistasLocales(<int>[-100]);
    await db.localMediaDao.limpiarHuerfanosLocales();

    expect(await db.select(db.albums).get(), isEmpty);
    expect(await db.select(db.artistas).get(), isEmpty);
  });

  test('limpiarHuerfanosLocales no toca filas del PC', () async {
    await db.catalogDao.upsertAlbums(<AlbumsCompanion>[
      AlbumsCompanion.insert(id: const Value(5), titulo: 'PC album'),
    ]);
    await sembrarLocal(); // local sin que su pista quede huérfana
    await db.localMediaDao.limpiarHuerfanosLocales();

    final List<Album> albums = await db.select(db.albums).get();
    // El álbum del PC (5) permanece; el local (-50) también (tiene su pista).
    expect(albums.map((Album a) => a.id).toSet(), <int>{5, -50});
  });

  test('remapReferencias mueve playlist y favorito a la pista del PC', () async {
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(id: const Value(10), titulo: 'X', artistaNombre: 'A'),
    ]);
    await sembrarLocal();
    final int plId = await db.into(db.playlistsLocales).insert(
          PlaylistsLocalesCompanion.insert(
            nombre: 'L',
            creadoEn: DateTime.now(),
            actualizadoEn: DateTime.now(),
          ),
        );
    await db.into(db.playlistLocalPistas).insert(
          PlaylistLocalPistasCompanion.insert(
              playlistId: plId, pistaId: -100, posicion: 0),
        );
    await db.favoritesDao.setFavorita(-100, true);

    await db.localMediaDao.remapReferencias(-100, 10);

    final List<PlaylistLocalPista> memb =
        await db.select(db.playlistLocalPistas).get();
    expect(memb.map((PlaylistLocalPista m) => m.pistaId), contains(10));
    final List<FavoritoEntry> favs = await db.select(db.favoritosLocal).get();
    expect(favs.any((FavoritoEntry f) => f.pistaId == 10 && f.esFavorita), isTrue);
  });

  test('ocultarPista quita del catálogo y la recuerda; mostrarPista la olvida',
      () async {
    await sembrarLocal();
    // mediaId = |idLocal| = 100.
    await db.localMediaDao.ocultarPista(100, 'X', 'A');

    expect(await db.localMediaDao.pistasPorOrigen('local'), isEmpty);
    expect(await db.localMediaDao.idsOcultos(), <int>{100});

    await db.localMediaDao.mostrarPista(100);
    expect(await db.localMediaDao.idsOcultos(), isEmpty);
  });

  test('fijarCoverLocal actualiza coverPath en lote', () async {
    await sembrarLocal();
    expect(
        (await db.localMediaDao.localesSinProbarCaratula()).map((Pista p) => p.id),
        contains(-100));
    await db.localMediaDao
        .fijarCoverLocal(<int, String>{-100: 'localart://100'});

    expect(await db.localMediaDao.localesSinProbarCaratula(), isEmpty);
    final Pista p = (await db.localMediaDao.pistasPorOrigen('local')).single;
    expect(p.coverPath, 'localart://100');
  });

  test('borrarTodaLocal vacía la música local', () async {
    await sembrarLocal();
    await db.localMediaDao.borrarTodaLocal();
    expect(await db.localMediaDao.pistasPorOrigen('local'), isEmpty);
    expect(await db.select(db.albums).get(), isEmpty);
  });
}
