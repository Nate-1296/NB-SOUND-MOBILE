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
      expect(gridColumns(1700), 7);
    });
    test('es monótona no decreciente', () {
      int prev = 0;
      for (double w = 200; w <= 1800; w += 20) {
        final int cols = gridColumns(w);
        expect(cols, greaterThanOrEqualTo(prev));
        prev = cols;
      }
    });
  });

  group('contentMaxWidthFor', () {
    test('siempre full-width (infinito) en cualquier tamaño', () {
      expect(contentMaxWidthFor(400).isFinite, isFalse);
      expect(contentMaxWidthFor(800).isFinite, isFalse);
      expect(contentMaxWidthFor(1400).isFinite, isFalse);
    });
  });

  group('uiScaleFor', () {
    test('crece con el ancho', () {
      expect(uiScaleFor(400), 1.0);
      expect(uiScaleFor(800), greaterThan(1.0));
      expect(uiScaleFor(1400), greaterThan(uiScaleFor(800)));
      expect(uiScaleFor(1400), lessThanOrEqualTo(1.25));
    });
  });

  group('cardScaleFor', () {
    test('crece más que el texto en pantallas anchas', () {
      expect(cardScaleFor(400), 1.0);
      expect(cardScaleFor(800), greaterThan(1.0));
      expect(cardScaleFor(1400), greaterThan(cardScaleFor(800)));
    });
  });

  group('scaledCount', () {
    test('muestra más ítems en pantallas anchas', () {
      expect(scaledCount(400, 6), 6);
      expect(scaledCount(800, 6), greaterThan(6));
      expect(scaledCount(1400, 6), greaterThan(scaledCount(800, 6)));
    });
  });
}
