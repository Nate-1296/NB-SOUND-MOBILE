import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/search/fuzzy.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/library/application/library_filters.dart';

CampoBusqueda _c(String texto, double peso) {
  final String n = normalizar(texto);
  return (peso: peso, norm: n, tokens: tokenizar(n));
}

PlaylistLocal _pl(int id, String nombre) => PlaylistLocal(
      id: id,
      nombre: nombre,
      creadoEn: DateTime.utc(2020),
      actualizadoEn: DateTime.utc(2020),
    );

List<String> _nombres(List<PlaylistLocal> ls) =>
    <String>[for (final PlaylistLocal p in ls) p.nombre];

void main() {
  final List<PlaylistLocal> base = <PlaylistLocal>[
    _pl(1, 'Rock'),
    _pl(2, 'jazz'),
    _pl(3, 'Ambient'),
  ];
  final Map<int, int> conteos = <int, int>{1: 10, 2: 3, 3: 25};

  group('filtrarOrdenarPlaylistsLocales — orden', () {
    test('nombre A → Z (case-insensitive)', () {
      final List<PlaylistLocal> r = filtrarOrdenarPlaylistsLocales(
          base, '', OrdenPlaylists.nombreAsc, conteos);
      expect(_nombres(r), <String>['Ambient', 'jazz', 'Rock']);
    });

    test('nombre Z → A', () {
      final List<PlaylistLocal> r = filtrarOrdenarPlaylistsLocales(
          base, '', OrdenPlaylists.nombreDesc, conteos);
      expect(_nombres(r), <String>['Rock', 'jazz', 'Ambient']);
    });

    test('más pistas', () {
      final List<PlaylistLocal> r = filtrarOrdenarPlaylistsLocales(
          base, '', OrdenPlaylists.masPistas, conteos);
      expect(_nombres(r), <String>['Ambient', 'Rock', 'jazz']); // 25,10,3
    });

    test('menos pistas', () {
      final List<PlaylistLocal> r = filtrarOrdenarPlaylistsLocales(
          base, '', OrdenPlaylists.menosPistas, conteos);
      expect(_nombres(r), <String>['jazz', 'Rock', 'Ambient']); // 3,10,25
    });
  });

  group('filtrarOrdenarPlaylistsLocales — búsqueda difusa', () {
    test('encuentra por nombre con typo', () {
      // "rok" → "Rock" (distancia 1).
      final List<PlaylistLocal> r = filtrarOrdenarPlaylistsLocales(
          base, 'rok', OrdenPlaylists.nombreAsc, conteos);
      expect(_nombres(r), <String>['Rock']);
    });

    test('sin coincidencia ⇒ vacío', () {
      final List<PlaylistLocal> r = filtrarOrdenarPlaylistsLocales(
          base, 'zzzz', OrdenPlaylists.nombreAsc, conteos);
      expect(r, isEmpty);
    });
  });

  group('puntuarCampos — búsqueda cruzada por campos', () {
    test('coincide por un campo cruzado (artista) aunque el directo no', () {
      // Sección Álbumes: título "Un Verano Sin Ti" no coincide con "bad bunny",
      // pero el campo artista (×0.9) sí ⇒ el álbum debe puntuar alto.
      final double s = puntuarCampos(normalizar('bad bunny'), <CampoBusqueda>[
        _c('Un Verano Sin Ti', 1.0),
        _c('Bad Bunny', 0.9),
      ]);
      expect(s, greaterThan(0.45));
    });

    test('coincide por título de pista (cruce pista → álbum)', () {
      final double s = puntuarCampos(normalizar('get lucky'), <CampoBusqueda>[
        _c('Random Access Memories', 1.0),
        _c('Daft Punk', 0.9),
        _c('Get Lucky', 0.85),
        _c('Instant Crush', 0.85),
      ]);
      expect(s, greaterThan(0.45));
    });

    test('el campo directo (peso 1.0) gana al cruzado en empate', () {
      final double directo =
          puntuarCampos(normalizar('lucky'), <CampoBusqueda>[_c('Lucky', 1.0)]);
      final double cruzado =
          puntuarCampos(normalizar('lucky'), <CampoBusqueda>[_c('Lucky', 0.85)]);
      expect(directo, greaterThan(cruzado));
    });

    test('sin coincidencia en ningún campo ⇒ 0', () {
      final double s = puntuarCampos(normalizar('zzzzz'), <CampoBusqueda>[
        _c('Un Verano Sin Ti', 1.0),
        _c('Bad Bunny', 0.9),
      ]);
      expect(s, lessThan(0.45));
    });
  });

  group('etiquetas de orden', () {
    test('son legibles', () {
      expect(OrdenAlbumes.anioDesc.etiqueta, 'Más recientes');
      expect(OrdenPistas.duracionDesc.etiqueta, 'Mayor duración');
      expect(OrdenArtistas.masPistas.etiqueta, 'Más pistas');
      expect(OrdenPlaylists.nombreAsc.etiqueta, 'Nombre A → Z');
    });
  });
}
