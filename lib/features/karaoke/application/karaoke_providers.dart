import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../../sync/application/sync_controller.dart';
import '../data/stems_repository.dart';

final Provider<StemsRepository> stemsRepositoryProvider =
    Provider<StemsRepository>((Ref ref) {
  final SecureStore store = ref.watch(secureStoreProvider);
  return StemsRepository(
    dioFor: (PairedPc pc) => NbApiClient.create(
      baseUrl: pc.baseUrl,
      fingerprint: pc.fingerprint,
      token: store.deviceToken,
    ),
  );
});

/// true si la pista tiene karaoke disponible en el PC emparejado. false si no
/// hay PC o no hay stems. Se usa para habilitar el toggle de karaoke.
final stemsDisponibleProvider =
    FutureProvider.family<bool, int>((Ref ref, int pistaId) async {
  final PairedPc? pc = ref.watch(syncControllerProvider).pc;
  if (pc == null) {
    return false;
  }
  return ref.watch(stemsRepositoryProvider).disponible(pc, pistaId);
});
