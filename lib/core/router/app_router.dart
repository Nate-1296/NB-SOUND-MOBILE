import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/app_shell.dart';
import '../../features/library/presentation/screens/album_detail_screen.dart';
import '../../features/library/presentation/screens/artist_detail_screen.dart';
import '../../features/library/presentation/screens/biblioteca_screen.dart';
import '../../features/library/presentation/screens/buscar_screen.dart';
import '../../features/library/presentation/screens/favoritas_screen.dart';
import '../../features/library/presentation/screens/inicio_screen.dart';
import '../../features/library/presentation/screens/local_playlist_detail_screen.dart';
import '../../features/library/presentation/screens/playlist_detail_screen.dart';
import '../../features/library/presentation/screens/playlists_screen.dart';
import '../../features/equalizer/presentation/ecualizador_screen.dart';
import '../../features/offline/presentation/descargas_screen.dart';
import '../../features/player/application/playback.dart';
import '../../features/player/presentation/player_screen.dart';
import '../../features/profile/presentation/configuracion_screen.dart';
import '../../features/profile/presentation/general_screen.dart';
import '../../features/profile/presentation/icono_app_screen.dart';
import '../../features/profile/presentation/perfil_screen.dart';
import '../../features/profile/presentation/temas_screen.dart';
import '../../features/sync/presentation/sync_screen.dart';
import '../../shared/theme/nb_colors.dart';
import '../../shared/widgets/mini_player_bar.dart';

final GlobalKey<NavigatorState> _rootKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

/// Convierte un parámetro de ruta a entero, con fallback defensivo a 0.
int _intParam(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '') ?? 0;

/// Router de la app. Pestañas en un [StatefulShellRoute] (bottom nav
/// persistente); detalle y overlays (player/perfil/sync) sobre el navegador
/// raíz a pantalla completa.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/inicio',
    routes: <RouteBase>[
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: <RouteBase>[
              GoRoute(
                path: '/inicio',
                builder: (BuildContext context, GoRouterState state) =>
                    const InicioScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/buscar',
                builder: (BuildContext context, GoRouterState state) =>
                    const BuscarScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/biblioteca',
                builder: (BuildContext context, GoRouterState state) =>
                    const BibliotecaScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/playlists',
                builder: (BuildContext context, GoRouterState state) =>
                    const PlaylistsScreen(),
              ),
            ],
          ),
        ],
      ),
      // Vistas de detalle (álbum/artista/playlist) bajo un ShellRoute que les
      // ancla el mini-reproductor debajo del contenido (nunca lo tapa: queda como
      // hermano, no como overlay). No aplica a player/perfil/sync/descargas.
      ShellRoute(
        parentNavigatorKey: _rootKey,
        builder: (
          BuildContext context,
          GoRouterState state,
          Widget child,
        ) {
          return _DetailWithMiniPlayer(child: child);
        },
        routes: <RouteBase>[
          GoRoute(
            path: '/album/:id',
            builder: (BuildContext context, GoRouterState state) =>
                AlbumDetailScreen(albumId: _intParam(state, 'id')),
          ),
          GoRoute(
            path: '/artist/:id',
            builder: (BuildContext context, GoRouterState state) =>
                ArtistDetailScreen(artistId: _intParam(state, 'id')),
          ),
          GoRoute(
            path: '/playlist/:id',
            builder: (BuildContext context, GoRouterState state) =>
                PlaylistDetailScreen(playlistId: _intParam(state, 'id')),
          ),
          GoRoute(
            path: '/playlist-local/:id',
            builder: (BuildContext context, GoRouterState state) =>
                LocalPlaylistDetailScreen(playlistId: _intParam(state, 'id')),
          ),
          GoRoute(
            path: '/favoritas',
            builder: (BuildContext context, GoRouterState state) =>
                const FavoritasScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/player',
        parentNavigatorKey: _rootKey,
        pageBuilder: (BuildContext context, GoRouterState state) =>
            CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 320),
          child: const PlayerScreen(),
          transitionsBuilder: _slideUp,
        ),
      ),
      GoRoute(
        path: '/profile',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const GeneralScreen(),
      ),
      GoRoute(
        path: '/perfil',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const PerfilScreen(),
      ),
      GoRoute(
        path: '/configuracion',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const ConfiguracionScreen(),
      ),
      GoRoute(
        path: '/ecualizador',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const EcualizadorScreen(),
      ),
      GoRoute(
        path: '/temas',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const TemasScreen(),
      ),
      GoRoute(
        path: '/icono-app',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const IconoAppScreen(),
      ),
      GoRoute(
        path: '/sync',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const SyncScreen(),
      ),
      GoRoute(
        path: '/descargas',
        parentNavigatorKey: _rootKey,
        builder: (BuildContext context, GoRouterState state) =>
            const DescargasScreen(),
      ),
    ],
  );
});

/// Envuelve una vista de detalle con el mini-reproductor anclado debajo. Cuando
/// hay algo sonando, cede el inset inferior del sistema a la barra (poniendo a 0
/// el `padding.bottom` del contenido) para que no quede un hueco doble entre la
/// última pista y el mini. Sin nada sonando, el contenido conserva su SafeArea.
class _DetailWithMiniPlayer extends ConsumerWidget {
  const _DetailWithMiniPlayer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool hasTrack =
        ref.watch(nowPlayingProvider.select((NowPlaying np) => np.hasTrack));
    if (!hasTrack) {
      return child;
    }
    final MediaQueryData mq = MediaQuery.of(context);
    return ColoredBox(
      color: context.nb.bg,
      child: Column(
        children: <Widget>[
          Expanded(
            child: MediaQuery(
              data: mq.copyWith(
                padding: mq.padding.copyWith(bottom: 0),
                viewPadding: mq.viewPadding.copyWith(bottom: 0),
              ),
              child: child,
            ),
          ),
          const MiniPlayerBar(safeAreaBottom: true),
        ],
      ),
    );
  }
}

/// Transición de deslizamiento hacia arriba (estilo reproductor).
Widget _slideUp(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final Animation<Offset> offset = Tween<Offset>(
    begin: const Offset(0, 1),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
  return SlideTransition(position: offset, child: child);
}
