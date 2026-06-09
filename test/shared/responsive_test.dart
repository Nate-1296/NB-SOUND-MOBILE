import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/shared/util/responsive.dart';

void main() {
  group('breakpointFor', () {
    test('teléfono ⇒ compact', () {
      expect(breakpointFor(360), Bp.compact);
      expect(breakpointFor(599), Bp.compact);
    });
    test('tablet/landscape ⇒ medium', () {
      expect(breakpointFor(600), Bp.medium);
      expect(breakpointFor(1023), Bp.medium);
    });
    test('Chromebook/escritorio ⇒ expanded', () {
      expect(breakpointFor(1024), Bp.expanded);
      expect(breakpointFor(1600), Bp.expanded);
    });
  });

  group('gridColumns', () {
    test('escala con el ancho disponible', () {
      expect(gridColumns(360), 2);
      expect(gridColumns(560), 3);
      expect(gridColumns(760), 4);
      expect(gridColumns(1040), 5);
      expect(gridColumns(1300), 6);
    });
    test('es monótona no decreciente', () {
      int prev = 0;
      for (double w = 200; w <= 1600; w += 20) {
        final int cols = gridColumns(w);
        expect(cols, greaterThanOrEqualTo(prev));
        prev = cols;
      }
    });
  });

  group('contentMaxWidthFor', () {
    test('compact no limita (infinito); anchos sí acotan', () {
      expect(contentMaxWidthFor(400).isFinite, isFalse);
      expect(contentMaxWidthFor(800), 760);
      expect(contentMaxWidthFor(1400), 920);
    });
  });

  group('uiScaleFor', () {
    test('crece con el ancho pero se mantiene moderado', () {
      expect(uiScaleFor(400), 1.0);
      expect(uiScaleFor(800), greaterThan(1.0));
      expect(uiScaleFor(1400), greaterThan(uiScaleFor(800)));
      expect(uiScaleFor(1400), lessThanOrEqualTo(1.2));
    });
  });
}
