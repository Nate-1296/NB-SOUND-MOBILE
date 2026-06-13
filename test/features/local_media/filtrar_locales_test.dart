import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/local_media/presentation/local_media_screen.dart';

Pista _p(int id, String titulo, String artista) => Pista(
      id: id,
      titulo: titulo,
      artistaNombre: artista,
      duracionSeg: 0,
      syncVersion: 0,
      origen: 'local',
    );

void main() {
  final List<Pista> pistas = <Pista>[
    _p(-1, "Ain't No Sunshine", 'Bill Withers'),
    _p(-2, 'Bohemian Rhapsody', 'Queen'),
    _p(-3, 'Clocks', 'Coldplay'),
  ];

  test('query vacía devuelve todo', () {
    expect(filtrarLocales(pistas, ''), pistas);
  });

  test('perdona apóstrofes y mayúsculas', () {
    final List<Pista> r = filtrarLocales(pistas, 'aint no sunshine');
    expect(r.first.id, -1);
  });

  test('tolera un typo', () {
    final List<Pista> r = filtrarLocales(pistas, 'bohemian rapsody');
    expect(r.first.id, -2);
  });

  test('encuentra por artista', () {
    final List<Pista> r = filtrarLocales(pistas, 'coldplay');
    expect(r.any((Pista p) => p.id == -3), isTrue);
  });

  test('sin coincidencia razonable ⇒ vacío', () {
    expect(filtrarLocales(pistas, 'zzzzxqq'), isEmpty);
  });
}
