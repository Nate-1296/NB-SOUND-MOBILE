import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/library/application/library_providers.dart';

Pista _p(int id, {int? artistaId, String? genero}) => Pista(
      id: id,
      titulo: 'T$id',
      artistaNombre: 'A$id',
      duracionSeg: 100,
      syncVersion: 0,
      artistaId: artistaId,
      genero: genero,
    );

void main() {
  group('generarAutoplay (radio local al acabar la cola)', () {
    final Pista semilla = _p(1, artistaId: 10, genero: 'pop');
    final List<Pista> catalogo = <Pista>[
      semilla,
      _p(2, artistaId: 10, genero: 'rock'), // mismo artista
      _p(3, artistaId: 10, genero: 'pop'), // mismo artista
      _p(4, artistaId: 99, genero: 'pop'), // mismo género
      _p(5, artistaId: 99, genero: 'jazz'), // resto
      _p(6, artistaId: 99, genero: 'jazz'), // resto
    ];

    test('no incluye la semilla ni lo excluido, sin duplicados', () {
      final List<Pista> out = generarAutoplay(
        semilla: semilla,
        catalogo: catalogo,
        excluir: <int>{semilla.id, 5},
        seed: 1,
      );
      final Set<int> ids = out.map((Pista p) => p.id).toSet();
      expect(ids.contains(1), isFalse);
      expect(ids.contains(5), isFalse);
      expect(ids.length, out.length); // sin duplicados
    });

    test('prioriza mismo artista, luego género, luego resto', () {
      final List<Pista> out = generarAutoplay(
        semilla: semilla,
        catalogo: catalogo,
        excluir: <int>{semilla.id},
        n: 6,
        seed: 1,
      );
      final List<int> ids = out.map((Pista p) => p.id).toList();
      // 2 y 3 (mismo artista) deben ir antes que 4 (solo género) y 5/6 (resto).
      expect(ids.indexOf(2) < ids.indexOf(4), isTrue);
      expect(ids.indexOf(3) < ids.indexOf(4), isTrue);
      expect(ids.indexOf(4) < ids.indexOf(5), isTrue);
      expect(ids.indexOf(4) < ids.indexOf(6), isTrue);
    });

    test('respeta el límite n', () {
      final List<Pista> out = generarAutoplay(
        semilla: semilla,
        catalogo: catalogo,
        excluir: <int>{semilla.id},
        n: 2,
        seed: 1,
      );
      expect(out.length, 2);
    });

    test('catálogo vacío o n<=0 ⇒ vacío', () {
      expect(
        generarAutoplay(
            semilla: semilla, catalogo: const <Pista>[], excluir: <int>{}),
        isEmpty,
      );
      expect(
        generarAutoplay(
            semilla: semilla, catalogo: catalogo, excluir: <int>{}, n: 0),
        isEmpty,
      );
    });
  });
}
