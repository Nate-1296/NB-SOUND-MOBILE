import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/library/application/library_providers.dart';

void main() {
  group('rotarVentana (Inicio dinámico)', () {
    final List<int> base = <int>[0, 1, 2, 3, 4];

    test('offset 0 devuelve el prefijo', () {
      expect(rotarVentana(base, 0, 3), <int>[0, 1, 2]);
    });

    test('rota dando la vuelta', () {
      expect(rotarVentana(base, 4, 3), <int>[4, 0, 1]);
    });

    test('offsets distintos dan ventanas distintas (sensación dinámica)', () {
      expect(rotarVentana(base, 0, 3) == rotarVentana(base, 2, 3), isFalse);
    });

    test('count mayor que la lista no repite de más', () {
      expect(rotarVentana(base, 1, 99).length, base.length);
    });

    test('lista vacía o count 0 ⇒ vacío', () {
      expect(rotarVentana(<int>[], 3, 4), <int>[]);
      expect(rotarVentana(base, 1, 0), <int>[]);
    });
  });
}
