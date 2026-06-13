import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nsd/nsd.dart' show Service;

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../offline/application/download_providers.dart';
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
      await ref.read(syncStateDaoProvider).setValor(
            SyncStateDao.kUltimaSync,
            DateTime.now().toUtc().toIso8601String(),
          );
      // Propaga al estado offline lo que el PC cambió/borró: limpia media huérfana
      // de los tombstones y resetea recursos descargados (portada/letra/karaoke)
      // que cambiaron, para rebajarlos con el contenido nuevo. Devuelve qué pistas
      // re-encolar. Se aplica ANTES del mantenimiento para que la cola vea los
      // recursos ya reseteados como incompletos.
      Set<int> reencolar = const <int>{};
      try {
        reencolar = await ref.read(offlinePropagationProvider).aplicar(result);
      } catch (_) {
        // Propagación best-effort: nunca rompe la sync.
      }
      // Mantenimiento offline en vivo: rebaja lo reseteado, reintenta fallidas,
      // mantiene las playlists guardadas y, si está activado, completa el espejo
      // de toda la biblioteca.
      unawaited(_mantenerOffline(reencolar));
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

  /// Encola el mantenimiento offline tras una sync con éxito. Best-effort: nunca
  /// rompe la sync. [reencolar] son las pistas que la propagación reseteó (rebajar
  /// su nueva portada/letra/karaoke). Ver [DownloadQueueController].
  Future<void> _mantenerOffline([Set<int> reencolar = const <int>{}]) async {
    try {
      final DownloadQueueController q =
          ref.read(downloadQueueProvider.notifier);
      if (reencolar.isNotEmpty) {
        await q.encolarPistas(reencolar);
      }
      await q.reintentarFallidas();
      await q.mantenerPlaylistsGuardadas();
      final String? todo =
          await ref.read(syncStateDaoProvider).getValor(SyncStateDao.kDescargarTodo);
      if (todo == '1') {
        await q.encolarTodo();
      }
    } catch (_) {
      // El mantenimiento es oportunista: cualquier fallo se reintenta en la
      // próxima sync.
    }
  }

  Future<void> _loadExisting() async {
    final PairedPc? pc = await _store.readPairing();
    if (pc != null && state.phase == SyncPhase.intro) {
      state = SyncState(phase: SyncPhase.connected, pc: pc);
      // Auto-sync al recuperar un emparejamiento previo (arranque de la app).
      unawaited(syncNow());
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
        deviceName: await _deviceName(),
        platform: _platform(),
      );
      state = SyncState(phase: SyncPhase.connected, pc: pc);
      unawaited(syncNow());
    } on PairingException catch (e) {
      state = SyncState(phase: SyncPhase.error, errorCode: e.code);
    }
  }

  /// Emparejamiento manual por **IP** (sin cámara): se introduce la dirección del
  /// PC (host o `host:puerto`) y el código de un solo uso. La app descubre el
  /// puerto si no se indicó (rango 8731–8799), aprende y fija la huella TLS por
  /// TOFU, y llama a `/pair` con el código. Útil en dispositivos sin cámara o con
  /// la cámara dañada.
  Future<void> conectarPorIp(String direccion, String codigo) async {
    if (state.phase == SyncPhase.connecting) {
      return;
    }
    final String dir = direccion.trim();
    final String code = codigo.trim();
    if (dir.isEmpty || code.isEmpty) {
      state = const SyncState(phase: SyncPhase.error, errorCode: 'datos_incompletos');
      return;
    }
    state = const SyncState(phase: SyncPhase.connecting);
    try {
      final PairedPc pc = await _repo.pairPorIp(
        direccion: dir,
        codigo: code,
        deviceName: await _deviceName(),
        platform: _platform(),
      );
      state = SyncState(phase: SyncPhase.connected, pc: pc);
      unawaited(syncNow());
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
        unawaited(syncNow());
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

  /// Nombre legible del dispositivo para que el PC lo muestre en su lista de
  /// emparejados (en vez del genérico "Android · NB Sound"). Best-effort: si el
  /// plugin no responde (p. ej. en tests sin canal de plataforma), cae al
  /// nombre genérico por plataforma.
  ///
  /// - Android: "Fabricante Modelo" (p. ej. "Google Pixel 7", "Samsung SM-G991B").
  /// - iOS: el nombre que el usuario puso al equipo (UIDevice.name).
  Future<String> _deviceName() async {
    try {
      final DeviceInfoPlugin info = DeviceInfoPlugin();
      switch (_platform()) {
        case 'android':
          final AndroidDeviceInfo a = await info.androidInfo;
          return _nombreLegible(a.manufacturer, a.model);
        case 'ios':
          final IosDeviceInfo i = await info.iosInfo;
          final String n = i.name.trim();
          return n.isNotEmpty ? n : _nombreLegible('Apple', i.model);
      }
    } catch (_) {
      // Plugin no disponible / sin canal de plataforma: usa el genérico.
    }
    return _deviceNameGenerico();
  }

  String _deviceNameGenerico() {
    switch (_platform()) {
      case 'android':
        return 'Android · NB Sound';
      case 'ios':
        return 'iPhone · NB Sound';
      default:
        return 'NB Sound móvil';
    }
  }

  /// Combina fabricante y modelo evitando repeticiones ("samsung SM-G991B" ->
  /// "Samsung SM-G991B"; "Google Pixel 7" cuando el modelo ya no trae marca).
  String _nombreLegible(String fabricante, String modelo) {
    final String f = fabricante.trim();
    final String m = modelo.trim();
    if (m.isEmpty) {
      return f.isEmpty ? 'NB Sound móvil' : _capitalizar(f);
    }
    if (f.isEmpty || m.toLowerCase().startsWith(f.toLowerCase())) {
      return m;
    }
    return '${_capitalizar(f)} $m';
  }

  String _capitalizar(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

final NotifierProvider<SyncController, SyncState> syncControllerProvider =
    NotifierProvider<SyncController, SyncState>(SyncController.new);
