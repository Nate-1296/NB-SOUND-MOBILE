import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/utils/duration_format.dart';

void main() {
  group('formatClock', () {
    test('formatea m:ss', () {
      expect(formatClock(0), '0:00');
      expect(formatClock(5), '0:05');
      expect(formatClock(65), '1:05');
      expect(formatClock(226), '3:46');
    });

    test('redondea fracciones', () {
      expect(formatClock(59.6), '1:00');
      expect(formatClock(125.4), '2:05');
    });

    test('incluye horas cuando supera 3600s', () {
      expect(formatClock(3600), '1:00:00');
      expect(formatClock(3725), '1:02:05');
    });
  });

  group('formatLongDuration', () {
    test('formatos compactos', () {
      expect(formatLongDuration(4860), '1h 21m');
      expect(formatLongDuration(3120), '52m');
      expect(formatLongDuration(180), '3m');
      expect(formatLongDuration(45), '45s');
    });
  });
}
