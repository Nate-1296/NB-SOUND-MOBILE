import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/library/application/library_providers.dart';

void main() {
  group('saludoPorHora', () {
    test('mañana (5–11)', () {
      expect(saludoPorHora(5), 'Buenos días');
      expect(saludoPorHora(11), 'Buenos días');
    });
    test('tarde (12–19)', () {
      expect(saludoPorHora(12), 'Buenas tardes');
      expect(saludoPorHora(19), 'Buenas tardes');
    });
    test('noche (20–4)', () {
      expect(saludoPorHora(20), 'Buenas noches');
      expect(saludoPorHora(0), 'Buenas noches');
      expect(saludoPorHora(4), 'Buenas noches');
    });
  });
}
