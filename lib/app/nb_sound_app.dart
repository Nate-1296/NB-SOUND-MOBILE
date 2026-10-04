import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/di/providers.dart';
import '../core/network/pinned_http_overrides.dart';
import '../core/security/secure_store.dart';
import '../core/router/app_router.dart';
import '../features/equalizer/application/equalizer_controller.dart';
import '../features/library/application/playlist_cover_prefetch.dart';
import '../features/local_media/application/local_media_providers.dart';
import '../features/player/application/player_controller.dart';
import '../features/sync/application/remote_media_provider.dart';
import '../features/sync/application/sync_controller.dart';
import '../shared/theme/nb_theme.dart';
import '../shared/theme/theme_controller.dart';
import '../shared/util/media_source.dart';
import 'player_hotkeys.dart';

/// Widget raíz: aplica el tema activo, monta el router declarativo y orquesta el
/// **auto-sync** para que todo esté en vivo sin intervención: sincroniza al
/// volver a primer plano (resume) y de forma periódica mientras la app está
/// abierta. El sync al conectar/arrancar lo dispara [SyncController]; cada sync
/// con éxito encadena el mantenimiento offline.
class NbSoundApp extends ConsumerStatefulWidget {
  const NbSoundApp({super.key});

  @override
  ConsumerState<NbSoundApp> createState() => _NbSoundAppState();
}

class _NbSoundAppState extends ConsumerState<NbSoundApp> {
  /// Cada cuánto re-sincronizar mientras la app está en primer plano.
  static const Duration _intervaloAutoSync = Duration(minutes: 5);

  /// Cada cuánto enviar el heartbeat de presencia al PC (para que la
  /// Sincronización del PC muestre este dispositivo "conectado ahora" aunque no
  /// esté en Connect). Más corto que la ventana de presencia del PC (~75 s).
  static const Duration _intervaloHeartbeat = Duration(seconds: 25);

  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  Timer? _heartbeatTimer;
  bool _enPrimerPlano = true;

  /// El prefetch de portadas de playlists solo tiene sentido una vez por sesión
  /// (la capa offline ya cachea; repetirlo solo reconsultaría la BD).
  bool _prefetchHecho = false;

  @override
  void initState() {
    super.initState();
    // Prefetch de portadas de playlists al arrancar (si ya hay PC emparejado),
    // para que la pestaña Playlists y los accesos rápidos del Inicio salgan
    // instantáneos la primera vez en vez de cargarse al abrirlos.
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefetchPortadas());
    // Refresca la música local del teléfono al arrancar (incremental y no
    // bloqueante): instanciar el controlador dispara su escaneo si ya hay
    // permiso. La primera vez (sin permiso) no hace nada hasta que el usuario lo
    // concede desde Ajustes › Música local.
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => ref.read(localMediaControllerProvider.notifier));
    // Solicita permiso de notificaciones en Android 13+ (necesario para la
    // notificación multimedia del sistema en Android 13, 14, 15 y 16).
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _solicitarPermisoNotificaciones());
    // Escucha y procesa rutas lanzadas desde los widgets de la pantalla de inicio.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revisarRutaWidget());
    _lifecycle = AppLifecycleListener(
      onStateChange: (AppLifecycleState estado) {
        final bool resumed = estado == AppLifecycleState.resumed;
        // Al volver a primer plano: sincroniza para reflejar cambios del PC y
        // revisa la música local nueva del teléfono (si la auto-revisión está on).
        if (resumed && !_enPrimerPlano) {
          _sincronizar();
          ref.read(localMediaControllerProvider.notifier).revisarSiAuto();
        }
        // Al ir a segundo plano: persiste la sesión del reproductor con la
        // posición real, para restaurarla al reabrir (como Spotify).
        if (estado == AppLifecycleState.paused ||
            estado == AppLifecycleState.hidden) {
          ref.read(playerControllerProvider.notifier).guardarSesion();
        }
        // Al CERRAR la app (no solo segundo plano): detiene la reproducción para
        // que no siga sonando con la app cerrada. En Chromebook, cerrar la ventana
        // emite `detached`; el `onTaskRemoved` nativo del handler cubre el cierre
        // desde recientes. Se guarda la sesión antes (para restaurar al reabrir).
        if (estado == AppLifecycleState.detached) {
          ref.read(playerControllerProvider.notifier).guardarSesion();
          ref.read(audioHandlerProvider).stop();
        }
        _enPrimerPlano = resumed;
      },
    );
    _timer = Timer.periodic(_intervaloAutoSync, (_) {
      if (_enPrimerPlano) {
        _sincronizar();
      }
    });
    _heartbeatTimer = Timer.periodic(_intervaloHeartbeat, (_) {
      if (_enPrimerPlano) {
        _heartbeat();
      }
    });
  }

  /// Heartbeat de presencia (best-effort): mientras la app está en primer plano y
  /// hay un PC emparejado, le avisa que sigue online para que lo muestre conectado.
  void _heartbeat() {
    final PairedPc? pc = ref.read(syncControllerProvider).pc;
    if (pc == null) {
      return;
    }
    ref.read(pairingRepositoryProvider).heartbeat(pc);
  }

  /// Best-effort: `syncNow` no hace nada si no hay PC emparejado o si ya hay una
  /// sincronización en curso.
  void _sincronizar() {
    ref.read(syncControllerProvider.notifier).syncNow();
  }

  /// Materializa en disco las portadas de mosaico de todas las playlists. Una sola
  /// vez por sesión y solo cuando ya hay un PC emparejado (si aún no lo hay, se
  /// reintenta cuando el sync lo establezca). Best-effort (errores ignorados).
  void _prefetchPortadas() {
    if (_prefetchHecho || ref.read(syncControllerProvider).pc == null) {
      return;
    }
    _prefetchHecho = true;
    ref.read(playlistCoverPrefetcherProvider).prefetchPlaylists(
          ref.read(catalogDaoProvider),
          ref.read(localPlaylistsDaoProvider),
        );
  }

  Future<void> _solicitarPermisoNotificaciones() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        final PermissionStatus status = await Permission.notification.status;
        if (!status.isGranted) {
          await Permission.notification.request();
        }
      } catch (_) {
        // En caso de fallo en el canal de permisos, no bloquear el flujo.
      }
    }
  }

  Future<void> _revisarRutaWidget() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      const MethodChannel channel = MethodChannel('com.nbsound/widget');
      channel.setMethodCallHandler((MethodCall call) async {
        if (call.method == 'onNavigateToRoute') {
          final String? route = call.arguments as String?;
          if (route != null && route.isNotEmpty) {
            ref.read(appRouterProvider).go(route);
          }
        }
      });
      try {
        final String? initial =
            await channel.invokeMethod<String>('getInitialRoute');
        if (initial != null && initial.isNotEmpty) {
          ref.read(appRouterProvider).go(initial);
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _heartbeatTimer?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String themeKey = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    // Mantiene vivo el ecualizador para que su configuración persistida (bandas,
    // normalizador, omitir silencios) se aplique al reproducir aunque no se abra
    // la pantalla de ajustes. No provoca rebuilds de la app (solo lo suscribe).
    ref.listen(equalizerControllerProvider, (_, _) {});

    // Reintenta el prefetch de portadas cuando el sync establece el PC (p. ej. el
    // primer emparejamiento o una sincronización con éxito tras arrancar sin PC).
    // Y, tras cada sync con éxito, deduplica la música local contra lo
    // sincronizado (la del PC prima): es el momento en que pueden aparecer
    // nuevas pistas del PC que dupliquen alguna local.
    ref.listen(syncControllerProvider.select((SyncState s) => s.lastSync),
        (_, _) {
      _prefetchPortadas();
      ref.read(localMediaServiceProvider).deduplicar();
    });

    // Mantiene la huella TLS global sincronizada con el PC emparejado, para que
    // el pinning de NetworkImage/just_audio (HttpOverrides) use el cert correcto.
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    NbHttpOverrides.fingerprint = remote?.fingerprint;

    return MaterialApp.router(
      title: 'NB Sound',
      debugShowCheckedModeBanner: false,
      theme: NbTheme.build(themeKey),
      routerConfig: router,
      // Atajos de teclado del reproductor (Chromebook/tablets/teléfonos con
      // teclado), por encima del Navigator para capturarlos en cualquier vista.
      builder: (BuildContext context, Widget? child) =>
          PlayerHotkeys(child: child ?? const SizedBox.shrink()),
    );
  }
}
