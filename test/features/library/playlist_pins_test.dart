import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/library/application/playlist_pins.dart';

void main() {
  group('tokens y parseo', () {
    test('tokens tipados distinguen local de PC', () {
      expect(tokenLocal(5), 'L5');
      expect(tokenPc(5), 'P5');
      expect(tokenLocal(5) == tokenPc(5), isFalse);
    });

    test('parseTokensAncladas ignora vacíos', () {
      expect(parseTokensAncladas(null), <String>[]);
      expect(parseTokensAncladas(''), <String>[]);
      expect(parseTokensAncladas('L1,P2,,L3'), <String>['L1', 'P2', 'L3']);
    });
  });

  group('conAncladasArriba', () {
    test('mueve las ancladas al frente, preservando el orden relativo', () {
      final List<String> base = <String>['L1', 'P2', 'L3', 'P4'];
      final List<String> r = conAncladasArriba(
        base,
        <String>{'L3', 'P2'},
        (String x) => x,
      );
      // Ancladas en orden de aparición en base (P2 antes que L3), luego el resto.
      expect(r, <String>['P2', 'L3', 'L1', 'P4']);
    });

    test('sin ancladas conserva el orden', () {
      final List<String> base = <String>['L1', 'P2'];
      expect(conAncladasArriba(base, <String>{}, (String x) => x), base);
    });
  });

  group('puedeAnclar (máximo por sección)', () {
    test('admite hasta el máximo y luego no', () {
      expect(puedeAnclar(0), isTrue);
      expect(puedeAnclar(kMaxAncladasPorSeccion - 1), isTrue);
      expect(puedeAnclar(kMaxAncladasPorSeccion), isFalse);
    });
  });
}
