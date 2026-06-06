import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/data/db/seed/dev_seed.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    await db.close();
  });

  test('CatalogDao: upsert idempotente y el PC gana en metadata', () async {
    await db.catalogDao.upsertArtistas(<ArtistasCompanion>[
      ArtistasCompanion.insert(id: const Value(1), nombre: 'Daft Punk'),
    ]);
    // Mismo id, nuevo nombre → debe sobrescribir, no duplicar.
    await db.catalogDao.upsertArtistas(<ArtistasCompanion>[
      ArtistasCompanion.insert(id: const Value(1), nombre: 'Daft Punk (PC)'),
    ]);

    final List<Artista> artistas = await db.catalogDao.watchArtistas().first;
    expect(artistas.length, 1);
    expect(artistas.single.nombre, 'Daft Punk (PC)');
  });

  test('HistoryDao: append + recientes distintos por orden temporal', () async {
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(id: const Value(1), titulo: 'A', artistaNombre: 'X'),
      PistasCompanion.insert(id: const Value(2), titulo: 'B', artistaNombre: 'X'),
    ]);
    await db.historyDao.registrarReproduccion(1);
    await db.historyDao.registrarReproduccion(2);
    await db.historyDao.registrarReproduccion(1);

    final List<Pista> recientes = await db.historyDao.watchRecientes().first;
    // La más reciente (1) primero, distintas, sin repetir.
    expect(recientes.map((Pista p) => p.id).toList(), <int>[1, 2]);

    final List<HistorialEntry> pendientes = await db.historyDao.noSubidos();
    expect(pendientes.length, 3); // el historial es append, no se deduplica
  });

  test('FavoritesDao: merge last-write-wins por timestamp', () async {
    final DateTime older = DateTime.utc(2026, 1, 1);
    final DateTime newer = DateTime.utc(2026, 2, 1);

    await db.favoritesDao.setFavorita(1, true, cuando: newer);
    // Escritura más antigua: se ignora (no pisa la más nueva).
    await db.favoritesDao.setFavorita(1, false, cuando: older);
    expect(await db.favoritesDao.esFavorita(1), isTrue);

    // Escritura más nueva: sí aplica.
    await db.favoritesDao.setFavorita(1, false, cuando: DateTime.utc(2026, 3, 1));
    expect(await db.favoritesDao.esFavorita(1), isFalse);
  });

  test('Seed de desarrollo: puebla el catálogo y es idempotente', () async {
    await seedDevData(db);
    expect(await db.catalogDao.contarPistas(), 22);

    final List<Album> albums = await db.catalogDao.watchAlbums().first;
    expect(albums.length, 12);

    final List<Pista> favoritas = await db.favoritesDao.watchFavoritas().first;
    expect(favoritas, isNotEmpty); // el seed marca varias pistas como favoritas

    // Segunda invocación no duplica (upserts idempotentes).
    await seedDevData(db);
    expect(await db.catalogDao.contarPistas(), 22);
  });

  test('Playlists del seed tienen pistas en orden', () async {
    await seedDevData(db);
    // Playlist 2 = "This is Bad Bunny": todas las pistas del artista 1.
    final List<Pista> pistas =
        await db.catalogDao.watchPistasDePlaylist(2).first;
    expect(pistas, isNotEmpty);
    expect(pistas.every((Pista p) => p.artistaId == 1), isTrue);
  });
}
