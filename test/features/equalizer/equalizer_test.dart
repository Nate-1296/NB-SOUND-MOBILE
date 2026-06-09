import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/equalizer/application/equalizer_controller.dart';

void main() {
  group('gananciasDePreset (remuestreo de la curva a N bandas)', () {
    test('curva plana da todo a 0', () {
      final List<double> g =
          gananciasDePreset(EqPreset.plano.curva!, 5, -15, 15);
      expect(g, <double>[0, 0, 0, 0, 0]);
    });

    test('respeta el número real de bandas del dispositivo', () {
      expect(gananciasDePreset(EqPreset.grave.curva!, 3, -15, 15).length, 3);
      expect(gananciasDePreset(EqPreset.grave.curva!, 10, -15, 15).length, 10);
    });

    test('graves: la primera banda es mayor que la última', () {
      final List<double> g =
          gananciasDePreset(EqPreset.grave.curva!, 5, -15, 15);
      expect(g.first, greaterThan(g.last));
    });

    test('agudos: la última banda es mayor que la primera', () {
      final List<double> g =
          gananciasDePreset(EqPreset.agudo.curva!, 5, -15, 15);
      expect(g.last, greaterThan(g.first));
    });

    test('acota a [minDb, maxDb]', () {
      final List<double> g =
          gananciasDePreset(<double>[100, -100], 4, -12, 12);
      for (final double v in g) {
        expect(v, inInclusiveRange(-12, 12));
      }
    });

    test('preset custom no tiene curva', () {
      expect(EqPreset.custom.curva, isNull);
    });
  });
}
