import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Catálogo mínimo: 3 pistas para referenciar.
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      for (int i = 1; i <= 3; i++)
        PistasCompanion.insert(
          id: Value(i),
          titulo: 'T$i',
          artistaNombre: 'A',
        ),
    ]);
  });
  tearDown(() => db.close());

  test('crear, añadir (idempotente) y leer en orden', () async {
    final int pl = await db.localPlaylistsDao.crear('Mi playlist');
    await db.localPlaylistsDao.anadirPista(pl, 1);
    await db.localPlaylistsDao.anadirPista(pl, 2);
    await db.localPlaylistsDao.anadirPista(pl, 1); // duplicado: se ignora

    final List<Pista> pistas =
        await db.localPlaylistsDao.watchPistas(pl).first;
    expect(pistas.map((Pista p) => p.id).toList(), <int>[1, 2]);
  });

  test('quitar renumera y conserva el orden', () async {
    final int pl = await db.localPlaylistsDao.crear('X');
    for (final int id in <int>[1, 2, 3]) {
      await db.localPlaylistsDao.anadirPista(pl, id);
    }
    await db.localPlaylistsDao.quitarPista(pl, 2);

    final List<Pista> pistas =
        await db.localPlaylistsDao.watchPistas(pl).first;
    expect(pistas.map((Pista p) => p.id).toList(), <int>[1, 3]);
  });

  test('reordenar aplica el nuevo orden', () async {
    final int pl = await db.localPlaylistsDao.crear('X');
    for (final int id in <int>[1, 2, 3]) {
      await db.localPlaylistsDao.anadirPista(pl, id);
    }
    await db.localPlaylistsDao.reordenar(pl, <int>[3, 1, 2]);

    final List<Pista> pistas =
        await db.localPlaylistsDao.watchPistas(pl).first;
    expect(pistas.map((Pista p) => p.id).toList(), <int>[3, 1, 2]);
  });

  test('renombrar y borrar', () async {
    final int pl = await db.localPlaylistsDao.crear('Vieja');
    await db.localPlaylistsDao.anadirPista(pl, 1);
    await db.localPlaylistsDao.renombrar(pl, 'Nueva');
    expect((await db.localPlaylistsDao.watchPlaylist(pl).first)?.nombre, 'Nueva');

    await db.localPlaylistsDao.borrar(pl);
    expect(await db.localPlaylistsDao.watchPlaylist(pl).first, isNull);
    expect(await db.localPlaylistsDao.watchPistas(pl).first, isEmpty);
  });

  test('conteos por playlist', () async {
    final int a = await db.localPlaylistsDao.crear('A');
    final int b = await db.localPlaylistsDao.crear('B');
    await db.localPlaylistsDao.anadirPista(a, 1);
    await db.localPlaylistsDao.anadirPista(a, 2);
    await db.localPlaylistsDao.anadirPista(b, 3);

    final Map<int, int> conteos = await db.localPlaylistsDao.watchConteos().first;
    expect(conteos[a], 2);
    expect(conteos[b], 1);
  });
}
