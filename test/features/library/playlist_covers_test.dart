import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/library/application/playlist_covers.dart';

Pista _pista(int id, String? cover) => Pista(
      id: id,
      titulo: 't$id',
      artistaNombre: 'a',
      duracionSeg: 0,
      syncVersion: 0,
      coverPath: cover,
    );

void main() {
  group('portadasDistintas', () {
    test('toma las 4 primeras distintas', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c2'),
        _pista(3, 'c3'),
        _pista(4, 'c4'),
        _pista(5, 'c5'),
      ];
      expect(portadasDistintas(pistas), <String>['c1', 'c2', 'c3', 'c4']);
    });

    test('salta portadas repetidas mirando la siguiente', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c1'),
        _pista(3, 'c2'),
        _pista(4, 'c1'),
        _pista(5, 'c3'),
        _pista(6, 'c4'),
      ];
      expect(portadasDistintas(pistas), <String>['c1', 'c2', 'c3', 'c4']);
    });

    test('salta pistas sin portada (null o vacía)', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, null),
        _pista(2, ''),
        _pista(3, 'c1'),
        _pista(4, null),
        _pista(5, 'c2'),
      ];
      expect(portadasDistintas(pistas), <String>['c1', 'c2']);
    });

    test('todas iguales ⇒ una sola (no se repite)', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c1'),
        _pista(3, 'c1'),
      ];
      expect(portadasDistintas(pistas), <String>['c1']);
    });

    test('respeta el máximo', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c2'),
        _pista(3, 'c3'),
      ];
      expect(portadasDistintas(pistas, max: 2), <String>['c1', 'c2']);
    });
  });
}
