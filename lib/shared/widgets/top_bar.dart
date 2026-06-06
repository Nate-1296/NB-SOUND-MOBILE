import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';

/// Barra superior de las vistas raíz. Espejo de `TopBar` del diseño: avatar de
/// perfil a la izquierda, título y acción opcional a la derecha.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onProfile,
    this.trailing,
    this.large = false,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onProfile;
  final Widget? trailing;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.bg3,
                shape: BoxShape.circle,
                border: Border.all(color: c.line2, width: 1.5),
              ),
              child: Text(
                'N',
                style: TextStyle(
                  fontFamily: NbFonts.display,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: c.accent,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (subtitle != null)
                  Text(
                    subtitle!.toUpperCase(),
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.3,
                      color: c.text3,
                    ),
                  ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NbFonts.display,
                    fontSize: large ? 22 : 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * (large ? 22 : 19),
                    color: c.text,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
