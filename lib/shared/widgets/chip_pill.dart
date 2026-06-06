import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';

/// Chip/píldora de filtro. Espejo de `Chip` del diseño.
class ChipPill extends StatelessWidget {
  const ChipPill({
    super.key,
    required this.label,
    this.active = false,
    this.icon,
    this.onTap,
  });

  final String label;
  final bool active;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Material(
      color: active ? c.soft : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? c.accent : c.line2,
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(icon != null ? 11 : 15, 8, 15, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 15, color: active ? c.accent : c.text2),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: active ? c.accent : c.text2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
