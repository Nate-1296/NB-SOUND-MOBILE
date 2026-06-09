import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';
import '../util/responsive.dart';
import 'app_icons.dart';

/// Encabezado de vistas de detalle/overlay con botón de retroceso.
/// Espejo de `SubHeader` del diseño.
class SubHeader extends StatelessWidget {
  const SubHeader({
    super.key,
    required this.title,
    this.onBack,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final double size = 20 * context.uiScale;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            icon: Icon(AppIcons.back, size: 24, color: c.text),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: size,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.02 * size,
                color: c.text,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
