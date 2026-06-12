import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/search/fuzzy.dart';

void main() {
  group('normalizar', () {
    test('minúsculas, sin acentos, puntuación a espacio', () {
      expect(normalizar('Café  Tacvba!'), 'cafe tacvba');
      expect(normalizar('  Ñandú  '), 'nandu');
      expect(normalizar('AC/DC'), 'ac dc');
      expect(normalizar('Sigur Rós'), 'sigur ros');
    });
    test('vacío y solo símbolos', () {
      expect(normalizar(''), '');
      expect(normalizar('—··—'), '');
    });
    test('los apóstrofes no parten palabras (símbolos perdonados)', () {
      // "Ain't" y "aint" deben normalizar igual para que la búsqueda perdone el
      // apóstrofe (recto o tipográfico).
      expect(normalizar("If It Ain't Me"), 'if it aint me');
      expect(normalizar('If It Ain’t Me'), 'if it aint me');
      expect(normalizar('if it aint me'), 'if it aint me');
      expect(normalizar("Don't"), 'dont');
    });
  });

  group("búsqueda perdona apóstrofes (caso del usuario)", () {
    test('"if it aint me" encuentra "If It Ain\'t Me"', () {
      final String objetivo = normalizar("If It Ain't Me");
      final List<String> tokens = tokenizar(objetivo);
      // Sin apóstrofe en la query coincide exactamente (1.0); con apóstrofe igual.
      expect(puntuarTexto(normalizar('if it aint me'), objetivo, tokens), 1.0);
      expect(puntuarTexto(normalizar("if it ain't me"), objetivo, tokens), 1.0);
    });
  });

  group('distanciaAcotada', () {
    test('iguales ⇒ 0', () {
      expect(distanciaAcotada('midnight', 'midnight', 2), 0);
    });
    test('dentro de la cota', () {
      expect(distanciaAcotada('midnght', 'midnight', 2), 1); // borrar 1
      expect(distanciaAcotada('mxdnxght', 'midnight', 2), 2); // 2 sustituciones
    });
    test('supera la cota ⇒ -1', () {
      expect(distanciaAcotada('xyz', 'midnight', 2), -1);
      expect(distanciaAcotada('midnight', 'morning', 2), -1);
    });
  });

  group('puntuarTexto (ranking)', () {
    List<String> tk(String s) => tokenizar(normalizar(s));

    test('exacto = 1.0', () {
      expect(puntuarTexto('midnight city', 'midnight city', tk('midnight city')),
          1.0);
    });

    test('prefijo > subcadena > token-substring', () {
      final double prefijo =
          puntuarTexto('mid', 'midnight city', tk('midnight city'));
      final double subcadena =
          puntuarTexto('ght', 'midnight city', tk('midnight city'));
      expect(prefijo, greaterThan(subcadena));
      expect(prefijo, greaterThan(0.85));
    });

    test('typo en un token sigue coincidiendo (tolerancia)', () {
      // "midnght" → token "midnight" con distancia 1.
      final double s =
          puntuarTexto('midnght', 'midnight city', tk('midnight city'));
      expect(s, greaterThan(0.3));
    });

    test('coincidencia exacta puntúa por encima de un typo', () {
      final double exacto =
          puntuarTexto('midnight', 'midnight city', tk('midnight city'));
      final double conTypo =
          puntuarTexto('midnght', 'midnight city', tk('midnight city'));
      expect(exacto, greaterThan(conTypo));
    });

    test('sin relación ⇒ 0', () {
      expect(
        puntuarTexto('zzqwx', 'midnight city', tk('midnight city')),
        0,
      );
    });

    test('acentos no estorban (se comparan ya normalizados)', () {
      final String objetivo = normalizar('Rosalía');
      final double s = puntuarTexto('rosalia', objetivo, tokenizar(objetivo));
      expect(s, 1.0);
    });
  });

  group('maxDistPara', () {
    test('más permisivo cuanto más larga la consulta', () {
      expect(maxDistPara(2), 0);
      expect(maxDistPara(3), 1);
      expect(maxDistPara(5), 2);
      expect(maxDistPara(9), 3);
    });
  });
}
