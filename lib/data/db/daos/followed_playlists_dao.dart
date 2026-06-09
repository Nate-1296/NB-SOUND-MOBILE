import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'followed_playlists_dao.g.dart';

/// Estado "guardada/seguida" de las playlists del PC (réplica). Es estado propio
/// del móvil: guardar una playlist del PC la hace vivir en "Tus playlists",
/// mantenerse al día por el sync del catálogo y descargarse para offline.
@DriftAccessor(tables: <Type>[PlaylistsGuardadas])
class FollowedPlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$FollowedPlaylistsDaoMixin {
  FollowedPlaylistsDao(super.db);

  /// Ids de las playlists del PC guardadas (reactivo).
  Stream<Set<int>> watchGuardadasIds() =>
      select(playlistsGuardadas).watch().map((List<PlaylistGuardada> rows) =>
          rows.map((PlaylistGuardada r) => r.playlistId).toSet());

  Future<bool> estaGuardada(int playlistId) async {
    final PlaylistGuardada? row = await (select(playlistsGuardadas)
          ..where((t) => t.playlistId.equals(playlistId)))
        .getSingleOrNull();
    return row != null;
  }

  /// Marca la playlist como guardada (idempotente).
  Future<void> guardar(int playlistId) =>
      into(playlistsGuardadas).insertOnConflictUpdate(
        PlaylistsGuardadasCompanion.insert(
          playlistId: Value(playlistId),
          guardadaEn: DateTime.now().toUtc(),
        ),
      );

  /// Deja de seguir la playlist (no toca sus descargas).
  Future<void> dejarDeSeguir(int playlistId) =>
      (delete(playlistsGuardadas)..where((t) => t.playlistId.equals(playlistId)))
          .go();
}
