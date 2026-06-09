import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/pinned_http_overrides.dart';
import '../core/router/app_router.dart';
import '../features/equalizer/application/equalizer_controller.dart';
import '../features/sync/application/remote_media_provider.dart';
import '../features/sync/application/sync_controller.dart';
import '../shared/theme/nb_theme.dart';
import '../shared/theme/theme_controller.dart';
import '../shared/util/media_source.dart';

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

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onStateChange: (AppLifecycleState estado) {
        final bool resumed = estado == AppLifecycleState.resumed;
        // Al volver a primer plano: sincroniza para reflejar cambios del PC.
        if (resumed && !_enPrimerPlano) {
          _sincronizar();
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

    // Mantiene la huella TLS global sincronizada con el PC emparejado, para que
    // el pinning de NetworkImage/just_audio (HttpOverrides) use el cert correcto.
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    NbHttpOverrides.fingerprint = remote?.fingerprint;

    return MaterialApp.router(
      title: 'NB Sound',
      debugShowCheckedModeBanner: false,
      theme: NbTheme.build(themeKey),
      routerConfig: router,
    );
  }
}
