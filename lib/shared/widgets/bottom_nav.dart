import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';
import 'app_icons.dart';

/// Un destino de la barra de navegación inferior.
class NavDestinationData {
  const NavDestinationData(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Destinos en el orden del diseño (`chrome.jsx` → NAV).
const List<NavDestinationData> kNavDestinations = <NavDestinationData>[
  NavDestinationData('Inicio', AppIcons.home),
  NavDestinationData('Buscar', AppIcons.search),
  NavDestinationData('Biblioteca', AppIcons.library),
  NavDestinationData('Playlists', AppIcons.note),
];

/// Barra inferior con blur. Espejo de `BottomNav` del diseño.
class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: c.bg.withValues(alpha: 0.86),
            border: Border(top: BorderSide(color: c.line)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 9, 8, 6),
              child: Row(
                children: <Widget>[
                  for (int i = 0; i < kNavDestinations.length; i++)
                    Expanded(
                      child: _NavItem(
                        data: kNavDestinations[i],
                        active: i == currentIndex,
                        onTap: () => onTap(i),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final NavDestinationData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color color = active ? c.accent : c.text3;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(data.icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(
              data.label,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 10.5,
                fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
