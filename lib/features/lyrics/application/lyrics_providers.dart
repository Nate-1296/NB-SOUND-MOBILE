import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../../sync/application/sync_controller.dart';
import '../data/lyrics_models.dart';
import '../data/lyrics_repository.dart';

/// Directorio de letras cacheadas (`<docs>/lyrics`), hermano del de audio.
final Provider<Directory> lyricsDirProvider = Provider<Directory>((Ref ref) {
  final Directory audioDir = ref.watch(appAudioDirProvider);
  return Directory(p.join(audioDir.parent.path, 'lyrics'));
});

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
