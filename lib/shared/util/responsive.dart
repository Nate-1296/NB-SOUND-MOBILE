import 'package:flutter/widgets.dart';

/// Adaptación a tamaño de pantalla. La app corre en teléfonos, tablets,
/// Chromebooks y en orientación horizontal: en pantallas anchas el contenido de
/// una sola columna se centra y limita su ancho (para que las listas no se
/// estiren), las rejillas ganan columnas y los títulos crecen un poco.

/// Punto de quiebre según el ancho disponible.
enum Bp { compact, medium, expanded }

/// Clasifica un ancho en [Bp]. Pública para tests sin `BuildContext`.
Bp breakpointFor(double width) {
  if (width >= 1024) {
    return Bp.expanded;
  }
  if (width >= 600) {
    return Bp.medium;
  }
  return Bp.compact;
}

/// Número de columnas para rejillas de portadas según el ancho disponible.
/// Mantiene tarjetas de tamaño cómodo en teléfonos (2) y aprovecha tablets,
/// Chromebooks y orientación horizontal.
int gridColumns(double width) {
  if (width >= 1280) {
    return 6;
  }
  if (width >= 1000) {
    return 5;
  }
  if (width >= 720) {
    return 4;
  }
  if (width >= 520) {
    return 3;
  }
  return 2;
}

/// Ancho máximo recomendado para contenido de una sola columna (listas, detalle).
/// En compacto ocupa todo el ancho; en pantallas anchas se acota para mantener
/// líneas legibles y evitar el "vacío" lateral de estirar a pantalla completa.
double contentMaxWidthFor(double width) {
  switch (breakpointFor(width)) {
    case Bp.compact:
      return double.infinity;
    case Bp.medium:
      return 760;
    case Bp.expanded:
      return 920;
  }
}

/// Factor de escala tipográfica suave para títulos/íconos en pantallas anchas.
double uiScaleFor(double width) {
  switch (breakpointFor(width)) {
    case Bp.compact:
      return 1.0;
    case Bp.medium:
      return 1.06;
    case Bp.expanded:
      return 1.12;
  }
}

/// Acceso ergonómico a las métricas responsive desde un `BuildContext`.
extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;

  Bp get bp => breakpointFor(_w);

  /// True a partir de tablet/landscape (≥ medium).
  bool get isWide => bp != Bp.compact;

  /// Ancho máximo de contenido de una columna para este ancho de pantalla.
  double get contentMaxWidth => contentMaxWidthFor(_w);

  /// Escala tipográfica suave (1.0 en teléfono, hasta 1.12 en pantallas anchas).
  double get uiScale => uiScaleFor(_w);
}

/// Centra y limita el ancho del [child] en pantallas anchas. En teléfonos es
/// transparente (ocupa todo el ancho). Útil para envolver bodies de una columna
/// (listas, detalle) sin tocar su contenido interno.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.max});

  final Widget child;

  /// Ancho máximo; por defecto el recomendado para el ancho de pantalla actual.
  final double? max;

  @override
  Widget build(BuildContext context) {
    final double limite = max ?? context.contentMaxWidth;
    if (!limite.isFinite) {
      return child;
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: limite),
        child: child,
      ),
    );
  }
}
