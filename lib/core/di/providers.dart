import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/daos/catalog_dao.dart';
import '../../data/db/daos/downloads_dao.dart';
import '../../data/db/daos/favorites_dao.dart';
import '../../data/db/daos/history_dao.dart';
import '../../data/db/daos/local_playlists_dao.dart';
import '../../data/db/daos/sync_state_dao.dart';
import '../../data/db/database.dart';
import '../security/secure_store.dart';

/// Instancia única de la BD local. Se sobreescribe en `main` con la base ya
/// abierta y sembrada, para garantizar disponibilidad síncrona en los DAOs.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((Ref ref) {
  throw UnimplementedError(
    'databaseProvider debe sobreescribirse en main() con la BD abierta.',
  );
});

/// Almacenamiento seguro de credenciales del PC (compartido sync/offline).
final Provider<SecureStore> secureStoreProvider =
    Provider<SecureStore>((Ref ref) => SecureStore());

/// Directorio de audio descargado. Se sobreescribe en `main`.
final Provider<Directory> appAudioDirProvider = Provider<Directory>((Ref ref) {
  throw UnimplementedError(
    'appAudioDirProvider debe sobreescribirse en main().',
  );
});

final Provider<CatalogDao> catalogDaoProvider =
    Provider<CatalogDao>((Ref ref) => ref.watch(databaseProvider).catalogDao);

final Provider<HistoryDao> historyDaoProvider =
    Provider<HistoryDao>((Ref ref) => ref.watch(databaseProvider).historyDao);

final Provider<FavoritesDao> favoritesDaoProvider = Provider<FavoritesDao>(
  (Ref ref) => ref.watch(databaseProvider).favoritesDao,
);

final Provider<DownloadsDao> downloadsDaoProvider = Provider<DownloadsDao>(
  (Ref ref) => ref.watch(databaseProvider).downloadsDao,
);

final Provider<SyncStateDao> syncStateDaoProvider = Provider<SyncStateDao>(
  (Ref ref) => ref.watch(databaseProvider).syncStateDao,
);

final Provider<LocalPlaylistsDao> localPlaylistsDaoProvider =
    Provider<LocalPlaylistsDao>(
  (Ref ref) => ref.watch(databaseProvider).localPlaylistsDao,
);
