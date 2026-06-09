import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'catalog_dao.g.dart';

/// Acceso de solo lectura (para la app) a la réplica de catálogo, más los
/// upserts usados por el sync y el seed de desarrollo.
@DriftAccessor(
  tables: <Type>[
    Artistas,
    Albums,
    Pistas,
    Playlists,
    PlaylistPistas,
    PlaylistsGuardadas,
  ],
)
class CatalogDao extends DatabaseAccessor<AppDatabase> with _$CatalogDaoMixin {
  CatalogDao(super.db);

  // ── Upserts (PC gana en metadata) ──────────────────────────────────────
  Future<void> upsertArtistas(List<ArtistasCompanion> rows) =>
      batch((Batch b) => b.insertAllOnConflictUpdate(artistas, rows));

  Future<void> upsertAlbums(List<AlbumsCompanion> rows) =>
      batch((Batch b) => b.insertAllOnConflictUpdate(albums, rows));

  Future<void> upsertPistas(List<PistasCompanion> rows) =>
      batch((Batch b) => b.insertAllOnConflictUpdate(pistas, rows));

  Future<void> upsertPlaylists(List<PlaylistsCompanion> rows) =>
      batch((Batch b) => b.insertAllOnConflictUpdate(playlists, rows));

  Future<void> upsertPlaylistPistas(List<PlaylistPistasCompanion> rows) =>
      batch((Batch b) => b.insertAllOnConflictUpdate(playlistPistas, rows));

  // ── Consultas reactivas ─────────────────────────────────────────────────
  Stream<List<Album>> watchAlbums() =>
      (select(albums)..orderBy(<OrderClauseGenerator<$AlbumsTable>>[
        (t) => OrderingTerm(expression: t.titulo),
      ])).watch();

  Stream<List<Artista>> watchArtistas() =>
      (select(artistas)..orderBy(<OrderClauseGenerator<$ArtistasTable>>[
        (t) => OrderingTerm(expression: t.nombre),
      ])).watch();

  Stream<List<Pista>> watchPistas() =>
      (select(pistas)..orderBy(<OrderClauseGenerator<$PistasTable>>[
        (t) => OrderingTerm(expression: t.titulo),
      ])).watch();

  Stream<List<Playlist>> watchPlaylists() =>
      (select(playlists)..orderBy(<OrderClauseGenerator<$PlaylistsTable>>[
        (t) => OrderingTerm(expression: t.nombre),
      ])).watch();

  Future<Album?> getAlbum(int id) =>
      (select(albums)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Artista?> getArtista(int id) =>
      (select(artistas)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Playlist?> getPlaylist(int id) =>
      (select(playlists)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Pista?> getPista(int id) =>
      (select(pistas)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Pista>> watchPistasDeAlbum(int albumId) =>
      (select(pistas)
            ..where((t) => t.albumId.equals(albumId))
            ..orderBy(<OrderClauseGenerator<$PistasTable>>[
              (t) => OrderingTerm(expression: t.trackNumber),
            ]))
          .watch();

  Stream<List<Pista>> watchPistasDeArtista(int artistaId) =>
      (select(pistas)
            ..where((t) => t.artistaId.equals(artistaId))
            ..orderBy(<OrderClauseGenerator<$PistasTable>>[
              (t) => OrderingTerm(expression: t.titulo),
            ]))
          .watch();

  Stream<List<Album>> watchAlbumsDeArtista(int artistaId) =>
      (select(albums)
            ..where((t) => t.artistaId.equals(artistaId))
            ..orderBy(<OrderClauseGenerator<$AlbumsTable>>[
              (t) => OrderingTerm(expression: t.anio, mode: OrderingMode.desc),
            ]))
          .watch();

  /// Pistas de una playlist en su orden de posición.
  Stream<List<Pista>> watchPistasDePlaylist(int playlistId) {
    final query = select(playlistPistas).join(<Join<HasResultSet, dynamic>>[
      innerJoin(pistas, pistas.id.equalsExp(playlistPistas.pistaId)),
    ])
      ..where(playlistPistas.playlistId.equals(playlistId))
      ..orderBy(<OrderingTerm>[
        OrderingTerm(expression: playlistPistas.posicion),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(pistas)).toList());
  }

  /// Búsqueda local simple (case-insensitive) en pistas por título o artista.
  Stream<List<Pista>> buscarPistas(String query) {
    final String like = '%${query.toLowerCase()}%';
    return (select(pistas)
          ..where(
            (t) =>
                t.titulo.lower().like(like) |
                t.artistaNombre.lower().like(like),
          )
          ..limit(50))
        .watch();
  }

  Future<int> contarPistas() async {
    final count = pistas.id.count();
    final row = await (selectOnly(pistas)
          ..addColumns(<Expression<Object>>[count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Total de pistas del catálogo (reactivo), para el contador "N de M".
  Stream<int> watchTotalPistas() {
    final count = pistas.id.count();
    final query = selectOnly(pistas)
      ..addColumns(<Expression<Object>>[count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ── Reemplazo de pertenencia de playlist (al upsertar desde el manifest) ──
  Future<void> replacePlaylistPistas(
    int playlistId,
    List<PlaylistPistasCompanion> rows,
  ) async {
    await (delete(playlistPistas)
          ..where((t) => t.playlistId.equals(playlistId)))
        .go();
    if (rows.isNotEmpty) {
      await batch((Batch b) => b.insertAllOnConflictUpdate(playlistPistas, rows));
    }
  }

  // ── Tombstones (borrado propagado por el PC) ─────────────────────────────
  Future<void> deletePista(int id) async {
    await (delete(playlistPistas)..where((t) => t.pistaId.equals(id))).go();
    await (delete(pistas)..where((t) => t.id.equals(id))).go();
  }

  Future<void> deleteAlbum(int id) =>
      (delete(albums)..where((t) => t.id.equals(id))).go();

  Future<void> deleteArtista(int id) =>
      (delete(artistas)..where((t) => t.id.equals(id))).go();

  Future<void> deletePlaylist(int id) async {
    await (delete(playlistPistas)..where((t) => t.playlistId.equals(id))).go();
    // Si el PC borra la playlist, deja de estar "guardada" en el móvil.
    await (delete(playlistsGuardadas)..where((t) => t.playlistId.equals(id)))
        .go();
    await (delete(playlists)..where((t) => t.id.equals(id))).go();
  }
}
