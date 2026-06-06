import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/pinned_http_overrides.dart';
import '../core/router/app_router.dart';
import '../features/sync/application/remote_media_provider.dart';
import '../shared/theme/nb_theme.dart';
import '../shared/theme/theme_controller.dart';
import '../shared/util/media_source.dart';

/// Widget raíz: aplica el tema activo y monta el router declarativo.
class NbSoundApp extends ConsumerWidget {
  const NbSoundApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbThemeId themeId = ref.watch(themeControllerProvider);
    final router = ref.watch(appRouterProvider);

    // Mantiene la huella TLS global sincronizada con el PC emparejado, para que
    // el pinning de NetworkImage/just_audio (HttpOverrides) use el cert correcto.
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    NbHttpOverrides.fingerprint = remote?.fingerprint;

    return MaterialApp.router(
      title: 'NB Sound',
      debugShowCheckedModeBanner: false,
      theme: NbTheme.build(themeId),
      routerConfig: router,
    );
  }
}
