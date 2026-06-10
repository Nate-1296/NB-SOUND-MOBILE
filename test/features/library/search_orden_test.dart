import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/library/application/search_providers.dart';

void main() {
  group('ordenarSecciones (de + a - coincidencia)', () {
    test('artista con mejor match va primero ("Bad Bu" ⇒ Bad Bunny)', () {
      final List<TipoResultado> orden = ordenarSecciones(
          artistas: 0.95, albums: 0.4, pistas: 0.5, playlists: 0.1);
      expect(orden.first, TipoResultado.artistas);
    });

    test('canción exacta va primero', () {
      final List<TipoResultado> orden = ordenarSecciones(
          artistas: 0.3, albums: 0.2, pistas: 1.0, playlists: 0.1);
      expect(orden.first, TipoResultado.pistas);
    });

    test('playlist con mejor match va primero', () {
      final List<TipoResultado> orden = ordenarSecciones(
          artistas: 0.3, albums: 0.2, pistas: 0.4, playlists: 0.9);
      expect(orden.first, TipoResultado.playlists);
    });

    test('secciones sin coincidencia (0) quedan al final', () {
      final List<TipoResultado> orden = ordenarSecciones(
          artistas: 0, albums: 0.7, pistas: 0, playlists: 0);
      expect(orden.first, TipoResultado.albums);
    });

    test('siempre devuelve todas las secciones', () {
      final List<TipoResultado> orden = ordenarSecciones(
          artistas: 0.5, albums: 0.5, pistas: 0.5, playlists: 0.5);
      expect(orden.toSet(), TipoResultado.values.toSet());
    });
  });
}
