import 'package:flutter/material.dart';

import 'nb_colors.dart';

/// Familias tipográficas bundleadas (ver `pubspec.yaml`).
abstract final class NbFonts {
  /// Titulares y cifras destacadas.
  static const String display = 'SpaceGrotesk';

  /// Texto de interfaz.
  static const String ui = 'Manrope';
}

/// Identificador de tema. Catálogo espejo de los temas oficiales del escritorio
/// (`nb_sound/ui/modelos_qml.py::ModeloTema._TEMAS`): 3 oscuros y 3 claros.
enum NbThemeId {
  negroPuro('Negro Puro (OLED)', Brightness.dark),
  arcillaNocturna('Arcilla Nocturna', Brightness.dark),
  hieloOled('Hielo OLED', Brightness.dark),
  arcillaCalida('Arcilla Cálida', Brightness.light),
  blancoEditorial('Blanco Editorial', Brightness.light),
  marfilGrafito('Marfil Grafito', Brightness.light);

  const NbThemeId(this.label, this.brightness);

  /// Nombre legible para la UI de selección de tema.
  final String label;

  /// Claridad de la paleta (afecta ColorScheme y overlays del sistema).
  final Brightness brightness;

  /// Resuelve un id por su nombre (`name`), con respaldo a [negroPuro].
  static NbThemeId fromName(String? name) => NbThemeId.values.firstWhere(
        (NbThemeId t) => t.name == name,
        orElse: () => NbThemeId.negroPuro,
      );
}

/// Catálogo de paletas. Los tokens del escritorio se mapean a [NbColors]:
/// bg←fondo, bg2←fondoElevado, bg3←superficieAlt, line/line2←borde,
/// text/text2/text3←texto/textoSec/textoMuted, accent/accent2←acento/acentoFuerte.
/// `ink` (tinta sobre el acento), `soft` y `ambient` se derivan del acento.
abstract final class NbPalettes {
  static final NbColors negroPuro = _build(
    fondo: 0xFF000000,
    fondoElevado: 0xFF0A0A0A,
    superficieAlt: 0xFF1A1A1A,
    borde: 0xFF2A2A2A,
    texto: 0xFFFFFFFF,
    textoSec: 0xFFB0B0B0,
    textoMuted: 0xFF787878,
    acento: 0xFF00E5FF,
    acentoFuerte: 0xFF00C8E0,
  );

  static final NbColors arcillaNocturna = _build(
    fondo: 0xFF1A1613,
    fondoElevado: 0xFF221D19,
    superficieAlt: 0xFF352E28,
    borde: 0xFF483F37,
    texto: 0xFFF4F1EA,
    textoSec: 0xFFCABFB0,
    textoMuted: 0xFF968B7C,
    acento: 0xFFE07A52,
    acentoFuerte: 0xFFC15F3C,
  );

  static final NbColors hieloOled = _build(
    fondo: 0xFF000000,
    fondoElevado: 0xFF05090D,
    superficieAlt: 0xFF10202E,
    borde: 0xFF254356,
    texto: 0xFFF6FBFF,
    textoSec: 0xFFB5D7E8,
    textoMuted: 0xFF7EA5BA,
    acento: 0xFF8EE8FF,
    acentoFuerte: 0xFF57D6F4,
  );

  static final NbColors arcillaCalida = _build(
    fondo: 0xFFF4F3EE,
    fondoElevado: 0xFFFAF9F4,
    superficieAlt: 0xFFEBE9E1,
    borde: 0xFFB1ADA1,
    texto: 0xFF2A2520,
    textoSec: 0xFF5C5447,
    textoMuted: 0xFF8A8273,
    acento: 0xFFC15F3C,
    acentoFuerte: 0xFFA54B2C,
  );

  static final NbColors blancoEditorial = _build(
    fondo: 0xFFF7F7F4,
    fondoElevado: 0xFFFFFFFF,
    superficieAlt: 0xFFECECEA,
    borde: 0xFFCFD2D4,
    texto: 0xFF171A1F,
    textoSec: 0xFF434A54,
    textoMuted: 0xFF68717D,
    acento: 0xFF1F6FEB,
    acentoFuerte: 0xFF175BC2,
  );

  static final NbColors marfilGrafito = _build(
    fondo: 0xFFF1EFE8,
    fondoElevado: 0xFFFBFAF5,
    superficieAlt: 0xFFE6E2D8,
    borde: 0xFFC7C0B2,
    texto: 0xFF1F2225,
    textoSec: 0xFF4D5359,
    textoMuted: 0xFF747B82,
    acento: 0xFF2F6F7E,
    acentoFuerte: 0xFF245867,
  );

  static NbColors byId(NbThemeId id) => switch (id) {
        NbThemeId.negroPuro => negroPuro,
        NbThemeId.arcillaNocturna => arcillaNocturna,
        NbThemeId.hieloOled => hieloOled,
        NbThemeId.arcillaCalida => arcillaCalida,
        NbThemeId.blancoEditorial => blancoEditorial,
        NbThemeId.marfilGrafito => marfilGrafito,
      };

  /// Construye una [NbColors] desde los tokens del escritorio, derivando
  /// line/line2 del borde y soft/ambient/ink del acento.
  static NbColors _build({
    required int fondo,
    required int fondoElevado,
    required int superficieAlt,
    required int borde,
    required int texto,
    required int textoSec,
    required int textoMuted,
    required int acento,
    required int acentoFuerte,
  }) {
    final Color accent = Color(acento);
    final Color bordeC = Color(borde);
    // Tinta legible sobre el acento según su luminancia.
    final Color ink = accent.computeLuminance() > 0.55
        ? const Color(0xFF0A0A0A)
        : const Color(0xFFFFFFFF);
    return NbColors(
      bg: Color(fondo),
      bg2: Color(fondoElevado),
      bg3: Color(superficieAlt),
      line: bordeC.withValues(alpha: 0.5),
      line2: bordeC,
      text: Color(texto),
      text2: Color(textoSec),
      text3: Color(textoMuted),
      accent: accent,
      accent2: Color(acentoFuerte),
      ink: ink,
      soft: accent.withValues(alpha: 0.14),
      ambient: accent.withValues(alpha: 0.22),
    );
  }
}

/// Construye el [ThemeData] de la app a partir de una paleta de tokens.
abstract final class NbTheme {
  static ThemeData build(NbThemeId id) {
    final NbColors c = NbPalettes.byId(id);
    final Brightness brightness = id.brightness;
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: c.accent,
      brightness: brightness,
      surface: c.bg,
      onSurface: c.text,
      primary: c.accent,
      onPrimary: c.ink,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: NbFonts.ui,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[c],
      textTheme: _textTheme(c),
      iconTheme: IconThemeData(color: c.text, size: 22),
      dividerColor: c.line,
    );
  }

  static TextTheme _textTheme(NbColors c) {
    TextStyle display(double size, FontWeight w) => TextStyle(
          fontFamily: NbFonts.display,
          fontSize: size,
          fontWeight: w,
          letterSpacing: -0.02 * size,
          color: c.text,
          height: 1.1,
        );
    TextStyle ui(double size, FontWeight w, Color color) => TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: size,
          fontWeight: w,
          color: color,
        );

    return TextTheme(
      displaySmall: display(24, FontWeight.w800),
      headlineMedium: display(22, FontWeight.w800),
      headlineSmall: display(19, FontWeight.w800),
      titleLarge: display(18, FontWeight.w700),
      titleMedium: ui(15, FontWeight.w600, c.text),
      titleSmall: ui(13.5, FontWeight.w600, c.text),
      bodyLarge: ui(15, FontWeight.w500, c.text),
      bodyMedium: ui(13.5, FontWeight.w500, c.text2),
      bodySmall: ui(12.5, FontWeight.w500, c.text3),
      labelLarge: ui(13.5, FontWeight.w600, c.text),
      labelMedium: ui(12, FontWeight.w600, c.text2),
      labelSmall: ui(11, FontWeight.w600, c.text3),
    );
  }
}
