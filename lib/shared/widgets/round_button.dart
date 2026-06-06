import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';

/// Botón circular de control. Espejo de `RoundBtn` del diseño.
class RoundButton extends StatelessWidget {
  const RoundButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 46,
    this.iconSize = 22,
    this.primary = false,
    this.ghost = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;

  /// Botón de acción principal (fondo accent, ícono ink).
  final bool primary;

  /// Botón fantasma (sin fondo).
  final bool ghost;

  /// Color del ícono (sobrescribe el predeterminado).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color bg = primary
        ? c.accent
        : ghost
            ? Colors.transparent
            : c.bg3;
    final Color fg = color ?? (primary ? c.ink : c.text);

    return Material(
      color: bg,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: fg),
        ),
      ),
    );
  }
}
