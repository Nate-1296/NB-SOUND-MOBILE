import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/utils/duration_format.dart';
import '../features/player/application/playback.dart';
import '../features/sync/application/remote_media_provider.dart';
import '../shared/theme/nb_colors.dart';
import '../shared/util/media_source.dart';
import '../shared/widgets/bottom_nav.dart';
import '../shared/widgets/mini_player.dart';

/// Shell raíz con barra de navegación inferior persistente y mini-reproductor
/// flotante (refleja el destino activo: este teléfono o el PC).
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Shell de navegación con estado de go_router (una rama por pestaña).
  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final NowPlaying np = ref.watch(nowPlayingProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (np.hasTrack)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
              child: MiniPlayer(
                title: np.title,
                subtitle:
                    np.isRemote ? '${np.artist} · en tu PC' : np.artist,
                cover: coverImage(np.coverPath, ref.watch(remoteMediaProvider)),
                playing: np.playing,
                progress: np.progress,
                positionLabel: formatClock(np.position.inSeconds),
                durationLabel: formatClock(np.duration.inSeconds),
                onTap: () => context.push('/player'),
                onToggle: () =>
                    ref.read(playbackActionsProvider).togglePlay(),
                onNext: () => ref.read(playbackActionsProvider).next(),
              ),
            ),
          BottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
          ),
        ],
      ),
    );
  }
}
