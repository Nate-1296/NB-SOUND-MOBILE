import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/assets_dao.dart';
import 'daos/catalog_dao.dart';
import 'daos/downloads_dao.dart';
import 'daos/favorites_dao.dart';
import 'daos/followed_playlists_dao.dart';
import 'daos/history_dao.dart';
import 'daos/local_playlists_dao.dart';
import 'daos/sync_state_dao.dart';
import 'tables.dart';

part 'database.g.dart';

/// Base de datos local (Drift/SQLite). Réplica de catálogo + fuente de verdad
/// del historial/favoritos del móvil. Ver docs/local-data.md.
@DriftDatabase(
  tables: <Type>[
    Artistas,
    Albums,
    Pistas,
    Playlists,
    PlaylistPistas,
    PlaylistsLocales,
    PlaylistLocalPistas,
    PlaylistsGuardadas,
    HistorialLocal,
    FavoritosLocal,
    DescargasAudio,
    AssetsDescargados,
    SyncEstado,
    PcEmparejado,
  ],
  daos: <Type>[
    CatalogDao,
    HistoryDao,
    FavoritesDao,
    DownloadsDao,
    AssetsDao,
    SyncStateDao,
    LocalPlaylistsDao,
    FollowedPlaylistsDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  /// Constructor para tests con BD en memoria.
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) => m.createAll(),
        onUpgrade: (Migrator m, int from, int to) async {
          // v2: playlists locales del teléfono (editables, fuera del sync).
          if (from < 2) {
            await m.createTable(playlistsLocales);
            await m.createTable(playlistLocalPistas);
          }
          // v3: descarga offline completa (letra + karaoke por pista + imágenes).
          if (from < 3) {
            await m.addColumn(descargasAudio, descargasAudio.lyricsEstado);
            await m.addColumn(descargasAudio, descargasAudio.stemsEstado);
            await m.addColumn(descargasAudio, descargasAudio.stemsBytes);
            await m.addColumn(descargasAudio, descargasAudio.stemsTotalBytes);
            await m.createTable(assetsDescargados);
          }
          // v4: playlists del PC guardadas/seguidas (estado propio del móvil).
          if (from < 4) {
            await m.createTable(playlistsGuardadas);
          }
        },
      );

  static QueryExecutor _open() {
    return LazyDatabase(() async {
      final Directory dir = await getApplicationDocumentsDirectory();
      final File file = File(p.join(dir.path, 'nb_sound.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}
