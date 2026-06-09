import 'package:flutter/material.dart';

/// Texto que **siempre se muestra completo**: reduce el tamaño de fuente desde el
/// del [style] hasta [minFontSize] buscando el mayor que quepa en [maxLines] sin
/// recortar; si aún así no cabe, envuelve hasta [maxLines] (último recurso:
/// elipsis al tamaño mínimo). Evita el clamp de "Midnight City" → "Midnight C…".
///
/// No usa dependencias externas: mide con [TextPainter] dentro de un
/// [LayoutBuilder] con el ancho real disponible.
class AutoFitText extends StatelessWidget {
  const AutoFitText(
    this.text, {
    super.key,
    required this.style,
    this.minFontSize = 13,
    this.maxLines = 2,
    this.textAlign = TextAlign.start,
    this.stepGranularity = 1.0,
  });

  final String text;

  /// Estilo base; su `fontSize` es el tamaño máximo (debe estar definido).
  final TextStyle style;

  /// Piso de tamaño de fuente al reducir.
  final double minFontSize;

  /// Líneas máximas antes de aceptar elipsis.
  final int maxLines;

  final TextAlign textAlign;

  /// Salto entre tamaños probados (px).
  final double stepGranularity;

  @override
  Widget build(BuildContext context) {
    final double maxFont = style.fontSize ?? 16;
    final double minFont = minFontSize.clamp(1, maxFont).toDouble();
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        double chosen = minFont;
        for (double size = maxFont; size >= minFont; size -= stepGranularity) {
          if (_fits(size, maxWidth, scaler)) {
            chosen = size;
            break;
          }
        }

        return Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style.copyWith(fontSize: chosen),
        );
      },
    );
  }

  bool _fits(double fontSize, double maxWidth, TextScaler scaler) {
    final TextPainter painter = TextPainter(
      text: TextSpan(text: text, style: style.copyWith(fontSize: fontSize)),
      maxLines: maxLines,
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: maxWidth);
    final bool overflowed = painter.didExceedMaxLines ||
        painter.width > maxWidth + 0.5;
    painter.dispose();
    return !overflowed;
  }
}
