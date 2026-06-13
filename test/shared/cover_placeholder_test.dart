import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/shared/theme/nb_colors.dart';
import 'package:nb_sound_mobile/shared/widgets/cover_placeholder.dart';

const NbColors _c = NbColors(
  bg: Color(0xFF101010),
  bg2: Color(0xFF181818),
  bg3: Color(0xFF222222),
  line: Color(0xFF2A2A2A),
  line2: Color(0xFF333333),
  text: Color(0xFFFFFFFF),
  text2: Color(0xFFCCCCCC),
  text3: Color(0xFF888888),
  accent: Color(0xFFC25939),
  accent2: Color(0xFFE0794F),
  ink: Color(0xFF000000),
  soft: Color(0xFF202020),
  ambient: Color(0xFF402020),
);

void main() {
  group('iconForCoverKind', () {
    test('cada tipo tiene un icono distinto', () {
      final Set<int> codepoints = <int>{
        for (final CoverKind k in CoverKind.values)
          iconForCoverKind(k).codePoint,
      };
      expect(codepoints.length, CoverKind.values.length);
    });
  });

  group('coverPlaceholderGradient', () {
    test('es determinista para la misma semilla', () {
      final LinearGradient a = coverPlaceholderGradient(_c, 42);
      final LinearGradient b = coverPlaceholderGradient(_c, 42);
      expect(a.colors, b.colors);
      expect(a.begin, b.begin);
      expect(a.end, b.end);
    });

    test('siempre devuelve dos colores armónicos con el tema', () {
      for (final Object? seed in <Object?>[null, 0, 1, 2, 3, 4, 99, 'texto']) {
        final LinearGradient g = coverPlaceholderGradient(_c, seed);
        expect(g.colors.length, 2);
      }
    });

    test('distintas semillas pueden variar el degradado', () {
      // No todas las semillas producen el mismo resultado (variedad visual).
      final Set<List<Color>> variantes = <List<Color>>{};
      final Set<String> firmas = <String>{};
      for (int i = 0; i < 10; i++) {
        final LinearGradient g = coverPlaceholderGradient(_c, i);
        firmas.add('${g.colors}|${g.begin}');
        variantes.add(g.colors);
      }
      expect(firmas.length, greaterThan(1));
    });
  });
}
