import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import '../theme/nb_theme.dart';
import '../util/responsive.dart';

/// Rótulo de sección en mayúsculas (APARIENCIA, DISPOSITIVO, TUS PLAYLISTS,
/// DEL PC…). Unifica los rótulos que antes se definían sueltos a `fontSize 11`
/// (demasiado pequeños y poco visibles) en distintas pantallas. Más grande y con
/// más contraste; escala suave en pantallas anchas.
class SectionLabel extends StatelessWidget {
  const SectionLabel({
    super.key,
    required this.label,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 0, 12),
  });

  final String label;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: padding,
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 13.5 * context.uiScale,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
          color: c.text2,
        ),
      ),
    );
  }
}
