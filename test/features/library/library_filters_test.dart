import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/library/application/library_filters.dart';

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

  group('etiquetas de orden', () {
    test('son legibles', () {
      expect(OrdenAlbumes.anioDesc.etiqueta, 'Más recientes');
      expect(OrdenPistas.duracionDesc.etiqueta, 'Mayor duración');
      expect(OrdenArtistas.masPistas.etiqueta, 'Más pistas');
      expect(OrdenPlaylists.nombreAsc.etiqueta, 'Nombre A → Z');
    });
  });
}
