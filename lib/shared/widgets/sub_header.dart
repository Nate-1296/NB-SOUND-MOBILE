import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            // go_router pop: respeta TODA la pila de navegación (incluido pasar
            // de un detalle directo desde una pestaña, donde `Navigator.maybePop`
            // del navegador anidado no tenía nada que sacar y la flecha no
            // devolvía). Fallback a Inicio si no hay a dónde volver.
            onPressed: onBack ?? () => _volver(context),
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

/// Vuelve a la vista anterior usando go_router (no el navegador anidado); si no
/// hay pila, va a Inicio.
void _volver(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/inicio');
  }
}
