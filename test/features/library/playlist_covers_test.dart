import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/library/application/playlist_covers.dart';

Pista _pista(int id, String? cover) => Pista(
      id: id,
      titulo: 't$id',
      artistaNombre: 'a',
      duracionSeg: 0,
      syncVersion: 0,
      origen: 'pc',
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

  group('slotsPortadaPlaylist', () {
    test('playlist vacía ⇒ sin slots', () {
      expect(slotsPortadaPlaylist(const <Pista>[]), isEmpty);
    });

    test('ninguna pista con portada ⇒ sin slots (placeholder de playlist)', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, null),
        _pista(2, ''),
        _pista(3, null),
      ];
      expect(slotsPortadaPlaylist(pistas), isEmpty);
    });

    test('cuatro distintas ⇒ cuatro slots reales', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c2'),
        _pista(3, 'c3'),
        _pista(4, 'c4'),
      ];
      expect(slotsPortadaPlaylist(pistas), <String?>['c1', 'c2', 'c3', 'c4']);
    });

    test('una portada + tres sin ⇒ rellena con respaldos (null)', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, null),
        _pista(3, null),
        _pista(4, null),
      ];
      expect(
        slotsPortadaPlaylist(pistas),
        <String?>['c1', null, null, null],
      );
    });

    test('portada repetida + dos sin ⇒ una real + dos respaldos', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c1'),
        _pista(3, null),
        _pista(4, null),
      ];
      expect(slotsPortadaPlaylist(pistas), <String?>['c1', null, null]);
    });

    test('todas iguales (sin pistas sin portada) ⇒ una sola, sin respaldos', () {
      final List<Pista> pistas = <Pista>[
        _pista(1, 'c1'),
        _pista(2, 'c1'),
        _pista(3, 'c1'),
      ];
      expect(slotsPortadaPlaylist(pistas), <String?>['c1']);
    });
  });
}
