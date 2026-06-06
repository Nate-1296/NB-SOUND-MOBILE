import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secure_store.dart';
import '../../../shared/util/media_source.dart';
import 'sync_controller.dart';

/// [RemoteMedia] del PC emparejado activo (base URL + token + huella), o null si
/// no hay emparejamiento. Reactivo: se deriva del estado de [syncControllerProvider]
/// (única fuente de verdad del emparejamiento), de modo que portadas, streaming,
/// letra y stems se rehabilitan/inhabilitan automáticamente al conectar/desconectar.
final Provider<RemoteMedia?> remoteMediaProvider = Provider<RemoteMedia?>((Ref ref) {
  final PairedPc? pc = ref.watch(syncControllerProvider).pc;
  if (pc == null) {
    return null;
  }
  return RemoteMedia(
    baseUrl: pc.baseUrl,
    token: pc.deviceToken,
    fingerprint: pc.fingerprint,
  );
});
