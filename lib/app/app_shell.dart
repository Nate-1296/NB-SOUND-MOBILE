import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/theme/nb_colors.dart';
import '../shared/widgets/bottom_nav.dart';
import '../shared/widgets/mini_player_bar.dart';

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

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(bottom: false, child: navigationShell),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const MiniPlayerBar(),
          BottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: _onTap,
          ),
        ],
      ),
    );
  }
}
