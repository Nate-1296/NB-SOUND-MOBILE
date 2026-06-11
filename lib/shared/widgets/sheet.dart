import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';

/// Presenta una hoja inferior de menú **siempre completa**: scrollable si su
/// contenido es alto y acotada al alto de pantalla, de modo que nunca quede
/// cortada por la parte de abajo (era el defecto de los `showModalBottomSheet`
/// con `Column` fijo: al superar el ~50% por defecto, las últimas opciones
/// quedaban fuera de pantalla).
///
/// - `isScrollControlled: true` libera el límite del 50% y la deja crecer hasta
///   el tope que fijamos (88% del alto).
/// - El contenido se envuelve en `SafeArea` + `SingleChildScrollView`, así que si
///   hay más opciones que altura disponible, se hace scroll en vez de recortarse.
/// - `useRootNavigator: true` la coloca sobre el mini-reproductor y la barra de
///   navegación (si no, sus opciones de abajo quedan tapadas).
///
/// [child] debe ser el contenido del menú (normalmente un `Column` con
/// `mainAxisSize: MainAxisSize.min`); NO debe traer su propio `SafeArea` ni
/// scroll: los aporta este helper.
Future<T?> mostrarHojaMenu<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  final NbColors c = context.nb;
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: c.bg2,
    showDragHandle: true,
    isScrollControlled: true,
    useRootNavigator: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
    ),
    builder: (BuildContext sheetContext) => SafeArea(
      child: SingleChildScrollView(
        child: builder(sheetContext),
      ),
    ),
  );
}
