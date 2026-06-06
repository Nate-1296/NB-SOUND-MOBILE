import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';

/// Encabezado de sección con acción opcional. Espejo de `SectionHead`.
class SectionHead extends StatelessWidget {
  const SectionHead({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.big = false,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: big ? 21 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02 * (big ? 21 : 18),
                color: c.text,
              ),
            ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: c.text3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
