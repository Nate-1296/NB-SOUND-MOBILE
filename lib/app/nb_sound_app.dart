import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/di/providers.dart';
import '../core/network/pinned_http_overrides.dart';
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

  AppLifecycleListener? _lifecycle;
  Timer? _timer;
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
        _enPrimerPlano = resumed;
      },
    );
    _timer = Timer.periodic(_intervaloAutoSync, (_) {
      if (_enPrimerPlano) {
        _sincronizar();
      }
    });
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

  @override
  void dispose() {
    _timer?.cancel();
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
