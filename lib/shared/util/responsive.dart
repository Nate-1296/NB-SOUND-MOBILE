import 'package:flutter/widgets.dart';

/// Adaptación a tamaño de pantalla. La app corre en teléfonos, tablets,
/// Chromebooks y en orientación horizontal: en pantallas anchas el contenido
/// aprovecha **todo el ancho** (sin márgenes vacíos a los lados), las rejillas y
/// los carruseles ganan columnas/ítems, las tarjetas y fotos crecen y los títulos
/// se agrandan. Filosofía: en grande se muestran *más cosas* y *más grandes*, no
/// lo mismo centrado con espacio desperdiciado.

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
/// Chromebooks y orientación horizontal (hasta 7 en monitores anchos).
int gridColumns(double width) {
  if (width >= 1600) {
    return 7;
  }
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

/// Ancho máximo recomendado para contenido de una sola columna. La app usa **todo
/// el ancho** en cualquier tamaño (el usuario pidió evitar el "centrado con huecos
/// laterales" en tablet/Chromebook/landscape): siempre infinito. Se conserva la
/// función (y el widget [MaxWidth]) por compatibilidad de call-sites; en pantallas
/// anchas la densidad se gana con más columnas/ítems y tarjetas más grandes, no
/// acotando el ancho.
double contentMaxWidthFor(double width) => double.infinity;

/// Factor de escala tipográfica para títulos/íconos según el ancho. Crece de forma
/// notable en pantallas grandes (el usuario pidió tamaños mayores en tablet/
/// Chromebook), manteniéndose 1.0 en teléfono.
double uiScaleFor(double width) {
  switch (breakpointFor(width)) {
    case Bp.compact:
      return 1.0;
    case Bp.medium:
      return 1.12;
    case Bp.expanded:
      return 1.22;
  }
}

/// Factor de tamaño para tarjetas/fotos de carrusel (portadas, círculos de
/// artista). Más agresivo que [uiScaleFor]: en pantallas anchas las tarjetas son
/// claramente mayores (sin perder resolución, porque el `cacheWidth` se deriva del
/// tamaño lógico × densidad).
double cardScaleFor(double width) {
  switch (breakpointFor(width)) {
    case Bp.compact:
      return 1.0;
    case Bp.medium:
      return 1.3;
    case Bp.expanded:
      return 1.6;
  }
}

/// Escala una cuenta base de ítems (cuántas pistas/álbumes mostrar en un carril)
/// según el ancho: en pantallas grandes se muestran muchos más. Redondea al entero.
int scaledCount(double width, int base) {
  switch (breakpointFor(width)) {
    case Bp.compact:
      return base;
    case Bp.medium:
      return (base * 1.6).round();
    case Bp.expanded:
      return (base * 2.4).round();
  }
}

/// Acceso ergonómico a las métricas responsive desde un `BuildContext`.
extension ResponsiveContext on BuildContext {
  double get _w => MediaQuery.sizeOf(this).width;

  Bp get bp => breakpointFor(_w);

  /// True a partir de tablet/landscape (≥ medium).
  bool get isWide => bp != Bp.compact;

  /// Ancho máximo de contenido de una columna (hoy siempre infinito: full-width).
  double get contentMaxWidth => contentMaxWidthFor(_w);

  /// Escala tipográfica (1.0 en teléfono, hasta 1.22 en pantallas anchas).
  double get uiScale => uiScaleFor(_w);

  /// Escala de tarjetas/fotos de carrusel (hasta 1.6 en pantallas anchas).
  double get cardScale => cardScaleFor(_w);

  /// Columnas para rejillas de portadas en el ancho actual.
  int get gridCols => gridColumns(_w);

  /// Escala una cuenta base de ítems según el ancho actual.
  int countFor(int base) => scaledCount(_w, base);
}

/// Centra y limita el ancho del [child] en pantallas anchas. Por defecto es
/// **transparente** (la app usa todo el ancho); solo acota si se le pasa un [max]
/// finito explícito. Se conserva para no romper call-sites y para casos puntuales
/// donde sí convenga acotar (p. ej. un formulario estrecho).
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.max});

  final Widget child;

  /// Ancho máximo explícito; si es null usa [contentMaxWidthFor] (hoy infinito).
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
