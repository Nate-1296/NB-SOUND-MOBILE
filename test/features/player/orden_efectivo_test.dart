import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/player/application/player_controller.dart';

void main() {
  group('ordenEfectivo (cola refleja el orden de reproducción)', () {
    test('sin orden (vacío) cae al orden natural', () {
      expect(ordenEfectivo(<int>[], 3), <int>[0, 1, 2]);
    });

    test('orden válido (misma longitud) se respeta tal cual', () {
      expect(ordenEfectivo(<int>[2, 0, 1], 3), <int>[2, 0, 1]);
    });

    test('orden desincronizado (otra longitud) cae al natural', () {
      // p. ej. justo tras cambiar de cola, el orden viejo aún no se actualizó.
      expect(ordenEfectivo(<int>[0, 1], 4), <int>[0, 1, 2, 3]);
    });

    test('longitud 0 produce lista vacía', () {
      expect(ordenEfectivo(<int>[], 0), <int>[]);
    });
  });
}
