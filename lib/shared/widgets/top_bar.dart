import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';
import '../util/responsive.dart';

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
    this.avatarInicial = 'N',
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onProfile;
  final Widget? trailing;
  final bool large;

  /// Inicial mostrada en el avatar de perfil (la del nombre real si hay perfil).
  final String avatarInicial;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final double scale = context.uiScale;
    final double titleSize = (large ? 26.0 : 22.0) * scale;
    final double avatar = 40 * scale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Row(
        children: <Widget>[
          GestureDetector(
            onTap: onProfile,
            child: Container(
              width: avatar,
              height: avatar,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.bg3,
                shape: BoxShape.circle,
                border: Border.all(color: c.line2, width: 1.5),
              ),
              child: Text(
                avatarInicial,
                style: TextStyle(
                  fontFamily: NbFonts.display,
                  fontSize: 15 * scale,
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
                      fontSize: 12 * scale,
                      fontWeight: FontWeight.w700,
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
                    fontSize: titleSize,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.02 * titleSize,
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
