import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../../offline/application/download_providers.dart';
import '../../sync/application/sync_controller.dart';
import '../data/lyrics_models.dart';
import '../data/lyrics_repository.dart';

/// Directorio de letras cacheadas (`<docs>/lyrics`). Misma convención que usa el
/// repositorio de descargas, vía [offlineStoreProvider], para que la letra que se
/// descarga sea exactamente la que lee [LyricsRepository] offline.
final Provider<Directory> lyricsDirProvider = Provider<Directory>(
  (Ref ref) => ref.watch(offlineStoreProvider).lyricsDir,
);

final Provider<LyricsRepository> lyricsRepositoryProvider =
    Provider<LyricsRepository>((Ref ref) {
  final SecureStore store = ref.watch(secureStoreProvider);
  return LyricsRepository(
    lyricsDir: ref.watch(lyricsDirProvider),
    dioFor: (PairedPc pc) => NbApiClient.create(
      baseUrl: pc.baseUrl,
      fingerprint: pc.fingerprint,
      token: store.deviceToken,
    ),
  );
});

/// Letra de una pista (cache-first). Re-evalúa al conectar/desconectar el PC.
final lyricsProvider = FutureProvider.family<Lyrics?, int>((Ref ref, int pistaId) {
  final PairedPc? pc = ref.watch(syncControllerProvider).pc;
  return ref.watch(lyricsRepositoryProvider).load(pc, pistaId);
});
