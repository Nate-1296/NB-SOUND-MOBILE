import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' show Service;

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../data/discovery_service.dart';
import '../data/pairing_repository.dart';
import '../data/qr_payload.dart';
import '../data/sync_repository.dart';

/// Fases del flujo de emparejamiento (espejo de screens-sync del diseño).
enum SyncPhase { intro, scanning, connecting, connected, error }

class SyncState {
  const SyncState({
    this.phase = SyncPhase.intro,
    this.pc,
    this.errorCode,
    this.syncing = false,
    this.lastSync,
    this.syncError,
  });

  final SyncPhase phase;
  final PairedPc? pc;
  final String? errorCode;

  /// True mientras corre una sincronización (manifest + subida).
  final bool syncing;
  final SyncResult? lastSync;
  final String? syncError;
}

final Provider<PairingRepository> pairingRepositoryProvider =
    Provider<PairingRepository>(
  (Ref ref) => PairingRepository(ref.watch(secureStoreProvider)),
);

final Provider<DiscoveryService> discoveryServiceProvider =
    Provider<DiscoveryService>((Ref ref) => DiscoveryService());

final Provider<SyncRepository> syncRepositoryProvider =
    Provider<SyncRepository>((Ref ref) {
  final SecureStore store = ref.watch(secureStoreProvider);
  return SyncRepository(
    db: ref.watch(databaseProvider),
    dioFor: (PairedPc pc) => NbApiClient.create(
      baseUrl: pc.baseUrl,
      fingerprint: pc.fingerprint,
      token: store.deviceToken,
    ),
  );
});

/// Máquina de estados del emparejamiento + reconexión.
class SyncController extends Notifier<SyncState> {
  late final PairingRepository _repo;
  late final SecureStore _store;
  late final DiscoveryService _discovery;
  late final SyncRepository _sync;

  @override
  SyncState build() {
    _repo = ref.watch(pairingRepositoryProvider);
    _store = ref.watch(secureStoreProvider);
    _discovery = ref.watch(discoveryServiceProvider);
    _sync = ref.watch(syncRepositoryProvider);
    // Carga un emparejamiento previo (no bloquea el primer estado).
    Future<void>(_loadExisting);
    return const SyncState();
  }

  /// Baja el catálogo (manifest delta) y sube historial/favoritos.
  Future<void> syncNow() async {
    final PairedPc? pc = state.pc;
    if (pc == null || state.syncing) {
      return;
    }
    state = SyncState(phase: SyncPhase.connected, pc: pc, syncing: true);
    try {
      final SyncResult result = await _sync.sync(pc);
      state = SyncState(phase: SyncPhase.connected, pc: pc, lastSync: result);
    } on DioException catch (e) {
      state = SyncState(
        phase: SyncPhase.connected,
        pc: pc,
        syncError: e.response?.statusCode == 401
            ? 'token_invalido_o_expirado'
            : 'error_red',
      );
    } catch (_) {
      state = SyncState(
        phase: SyncPhase.connected,
        pc: pc,
        syncError: 'error_sync',
      );
    }
  }

  Future<void> _loadExisting() async {
    final PairedPc? pc = await _store.readPairing();
    if (pc != null && state.phase == SyncPhase.intro) {
      state = SyncState(phase: SyncPhase.connected, pc: pc);
    }
  }

  void startScan() => state = const SyncState(phase: SyncPhase.scanning);

  void cancel() => state = SyncState(
        phase: state.pc != null ? SyncPhase.connected : SyncPhase.intro,
        pc: state.pc,
      );

  /// Procesa el texto del QR detectado (un solo intento por escaneo).
  Future<void> onQrDetected(String raw) async {
    if (state.phase != SyncPhase.scanning) {
      return;
    }
    final QrPairingPayload? qr = QrPairingPayload.tryParse(raw);
    if (qr == null) {
      state = const SyncState(phase: SyncPhase.error, errorCode: 'qr_invalido');
      return;
    }
    state = const SyncState(phase: SyncPhase.connecting);
    try {
      final PairedPc pc = await _repo.pair(
        qr,
        deviceName: _deviceName(),
        platform: _platform(),
      );
      state = SyncState(phase: SyncPhase.connected, pc: pc);
    } on PairingException catch (e) {
      state = SyncState(phase: SyncPhase.error, errorCode: e.code);
    }
  }

  Future<void> disconnect() async {
    await _repo.unpair();
    state = const SyncState(phase: SyncPhase.intro);
  }

  /// Reintenta alcanzar el PC; si su IP cambió, lo redescubre por mDNS.
  Future<void> reconnect() async {
    final PairedPc? pc = state.pc;
    if (pc == null) {
      return;
    }
    if (await _repo.reachable(pc)) {
      return;
    }
    final Service? svc = await _discovery.findFirst();
    final String? host = svc?.host;
    final int? port = svc?.port;
    if (host != null && port != null) {
      await _store.updateEndpoint(host, port);
      final PairedPc? updated = await _store.readPairing();
      if (updated != null) {
        state = SyncState(phase: SyncPhase.connected, pc: updated);
      }
    }
  }

  String _platform() {
    if (kIsWeb) {
      return 'desconocida';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return 'desconocida';
    }
  }

  String _deviceName() {
    switch (_platform()) {
      case 'android':
        return 'Android · NB Sound';
      case 'ios':
        return 'iPhone · NB Sound';
      default:
        return 'NB Sound móvil';
    }
  }
}

final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
