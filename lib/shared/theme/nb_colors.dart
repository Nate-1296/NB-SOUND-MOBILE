import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño NB Sound, expuestos como
/// [ThemeExtension] para que cualquier widget los lea vía
/// `Theme.of(context).extension<NbColors>()` (o el helper `context.nb`).
///
/// Espejo de las variables CSS del diseño (`state.jsx`): `--bg`, `--bg2`,
/// `--bg3`, `--line`, `--line2`, `--text`, `--text2`, `--text3`, `--accent`,
/// `--accent2`, `--ink`, `--soft`, `--ambient`.
@immutable
class NbColors extends ThemeExtension<NbColors> {
  const NbColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.line,
    required this.line2,
    required this.text,
    required this.text2,
    required this.text3,
    required this.accent,
    required this.accent2,
    required this.ink,
    required this.soft,
    required this.ambient,
  });

  /// Fondo base de la app.
  final Color bg;

  /// Superficie elevada (tarjetas, hojas inferiores).
  final Color bg2;

  /// Superficie aún más elevada (chips, botones secundarios).
  final Color bg3;

  /// Línea/borde sutil.
  final Color line;

  /// Línea/borde con más contraste.
  final Color line2;

  /// Texto primario.
  final Color text;

  /// Texto secundario.
  final Color text2;

  /// Texto terciario / deshabilitado.
  final Color text3;

  /// Color de acento de la paleta.
  final Color accent;

  /// Variante más oscura del acento (estados presionados).
  final Color accent2;

  /// Color de "tinta" sobre el acento (texto/íconos encima del accent).
  final Color ink;

  /// Tinte translúcido del acento (fondos suaves activos).
  final Color soft;

  /// Resplandor ambiental del acento (sombras de glow).
  final Color ambient;

  @override
  NbColors copyWith({
    Color? bg,
    Color? bg2,
    Color? bg3,
    Color? line,
    Color? line2,
    Color? text,
    Color? text2,
    Color? text3,
    Color? accent,
    Color? accent2,
    Color? ink,
    Color? soft,
    Color? ambient,
  }) {
    return NbColors(
      bg: bg ?? this.bg,
      bg2: bg2 ?? this.bg2,
      bg3: bg3 ?? this.bg3,
      line: line ?? this.line,
      line2: line2 ?? this.line2,
      text: text ?? this.text,
      text2: text2 ?? this.text2,
      text3: text3 ?? this.text3,
      accent: accent ?? this.accent,
      accent2: accent2 ?? this.accent2,
      ink: ink ?? this.ink,
      soft: soft ?? this.soft,
      ambient: ambient ?? this.ambient,
    );
  }

  @override
  NbColors lerp(covariant ThemeExtension<NbColors>? other, double t) {
    if (other is! NbColors) {
      return this;
    }
    return NbColors(
      bg: Color.lerp(bg, other.bg, t)!,
      bg2: Color.lerp(bg2, other.bg2, t)!,
      bg3: Color.lerp(bg3, other.bg3, t)!,
      line: Color.lerp(line, other.line, t)!,
      line2: Color.lerp(line2, other.line2, t)!,
      text: Color.lerp(text, other.text, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accent2: Color.lerp(accent2, other.accent2, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      ambient: Color.lerp(ambient, other.ambient, t)!,
    );
  }
}

/// Acceso ergonómico a los tokens activos: `context.nb.accent`.
extension NbColorsContext on BuildContext {
  NbColors get nb => Theme.of(this).extension<NbColors>()!;
}
