import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/local_media/application/local_dedupe.dart';
import 'package:nb_sound_mobile/features/local_media/application/local_ids.dart';

PistaDedupe _p(int id, String t, String a, String? al, double d) =>
    PistaDedupe(id: id, titulo: t, artista: a, album: al, duracionSeg: d);

void main() {
  group('local_ids', () {
    test('ids locales son negativos y distinguibles', () {
      expect(esIdLocal(idLocalPista(123)), isTrue);
      expect(esIdLocal(5), isFalse);
      expect(idLocalPista(123), -123);
      expect(mediaStoreIdDePista(idLocalPista(123)), 123);
    });

    test('álbum/artista null o ≤0 ⇒ flotante (null)', () {
      expect(idLocalAlbum(null), isNull);
      expect(idLocalAlbum(0), isNull);
      expect(idLocalAlbum(-3), isNull);
      expect(idLocalAlbum(7), -7);
      expect(idLocalArtista(9), -9);
    });

    test('coverPathLocal round-trip', () {
      final String cp = coverPathLocal(42);
      expect(cp, 'localart://42');
      expect(mediaStoreIdDeCover(cp), 42);
      expect(mediaStoreIdDeCover('/api/v1/asset/cover/3'), isNull);
      expect(mediaStoreIdDeCover(null), isNull);
    });
  });

  group('mapaDuplicadosLocales', () {
    test('match exacto normalizado + duración dentro de tolerancia', () {
      final List<PistaDedupe> locales = <PistaDedupe>[
        _p(-1, 'Canción Á', 'Artista', 'Álbum', 200),
      ];
      final List<PistaDedupe> pc = <PistaDedupe>[
        _p(10, 'cancion a', 'artista', 'album', 205), // +5s, acentos/caja
      ];
      expect(mapaDuplicadosLocales(locales, pc), <int, int>{-1: 10});
    });

    test('duración fuera de tolerancia ⇒ no es duplicado', () {
      final List<PistaDedupe> locales = <PistaDedupe>[
        _p(-1, 'X', 'A', 'B', 100),
      ];
      final List<PistaDedupe> pc = <PistaDedupe>[
        _p(10, 'X', 'A', 'B', 115), // +15s
      ];
      expect(mapaDuplicadosLocales(locales, pc), isEmpty);
    });

    test('distinto álbum ⇒ no es duplicado', () {
      final List<PistaDedupe> locales = <PistaDedupe>[
        _p(-1, 'X', 'A', 'Album1', 100),
      ];
      final List<PistaDedupe> pc = <PistaDedupe>[
        _p(10, 'X', 'A', 'Album2', 100),
      ];
      expect(mapaDuplicadosLocales(locales, pc), isEmpty);
    });

    test('elige la sincronizada más cercana en duración', () {
      final List<PistaDedupe> locales = <PistaDedupe>[
        _p(-1, 'X', 'A', 'B', 200),
      ];
      final List<PistaDedupe> pc = <PistaDedupe>[
        _p(10, 'X', 'A', 'B', 208), // +8
        _p(11, 'X', 'A', 'B', 202), // +2 (más cercana)
      ];
      expect(mapaDuplicadosLocales(locales, pc), <int, int>{-1: 11});
    });

    test('listas vacías ⇒ sin duplicados', () {
      expect(mapaDuplicadosLocales(const <PistaDedupe>[], const <PistaDedupe>[]),
          isEmpty);
      expect(
          mapaDuplicadosLocales(<PistaDedupe>[_p(-1, 'X', 'A', 'B', 1)],
              const <PistaDedupe>[]),
          isEmpty);
    });
  });
}
