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

  /// Pistas por una lista de ids, en una sola consulta (id → Pista). El orden de
  /// la cola lo reconstruye el llamador; las ids inexistentes simplemente faltan.
  Future<Map<int, Pista>> getPistasPorIds(List<int> ids) async {
    if (ids.isEmpty) {
      return const <int, Pista>{};
    }
    final List<Pista> filas =
        await (select(pistas)..where((t) => t.id.isIn(ids))).get();
    return <int, Pista>{for (final Pista p in filas) p.id: p};
  }

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

  Future<int> contarPistas() async {
    final count = pistas.id.count();
    final row = await (selectOnly(pistas)
          ..addColumns(<Expression<Object>>[count]))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Nº de pistas por playlist del PC (playlistId → conteo), para ordenar/filtrar.
  Stream<Map<int, int>> watchConteosPlaylists() {
    final Expression<int> count = playlistPistas.pistaId.count();
    final query = selectOnly(playlistPistas)
      ..addColumns(<Expression<Object>>[playlistPistas.playlistId, count])
      ..groupBy(<Expression<Object>>[playlistPistas.playlistId]);
    return query.watch().map((List<TypedResult> rows) => <int, int>{
          for (final TypedResult row in rows)
            row.read(playlistPistas.playlistId)!: row.read(count) ?? 0,
        });
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
