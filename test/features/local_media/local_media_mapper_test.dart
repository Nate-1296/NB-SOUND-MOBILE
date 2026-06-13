import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/local_media/application/local_ids.dart';
import 'package:nb_sound_mobile/features/local_media/application/local_media_mapper.dart';
import 'package:nb_sound_mobile/features/local_media/data/local_media_channel.dart';

LocalSong _song(
  int id, {
  String title = 'T',
  String? artist,
  int? artistId,
  String? album,
  int? albumId,
  int durationMs = 200000,
}) =>
    LocalSong(
      id: id,
      uri: 'content://media/external/audio/media/$id',
      title: title,
      durationMs: durationMs,
      artist: artist,
      artistId: artistId,
      album: album,
      albumId: albumId,
    );

void main() {
  group('mapearEscaneo', () {
    test('canción con álbum y artista → filas locales con ids negativos', () {
      final CatalogoLocal cat = mapearEscaneo(<LocalSong>[
        _song(100,
            title: 'Tema', artist: 'Banda', artistId: 7, album: 'Disco', albumId: 50),
      ]);
      expect(cat.pistas, hasLength(1));
      expect(cat.albums, hasLength(1));
      expect(cat.artistas, hasLength(1));

      final p = cat.pistas.first;
      expect(p.id.value, idLocalPista(100));
      expect(p.id.value < 0, isTrue);
      expect(p.titulo.value, 'Tema');
      expect(p.artistaNombre.value, 'Banda');
      expect(p.albumId.value, idLocalAlbum(50));
      expect(p.artistaId.value, idLocalArtista(7));
      expect(p.audioPath.value, 'content://media/external/audio/media/100');
      expect(p.origen.value, origenLocal);
      // Carátula embebida diferida: queda null → placeholder tipado.
      expect(p.coverPath.value, isNull);

      expect(cat.albums.first.id.value, idLocalAlbum(50));
      expect(cat.albums.first.origen.value, origenLocal);
      expect(cat.artistas.first.id.value, idLocalArtista(7));
    });

    test('canción flotante (sin álbum/artista) → sin filas de álbum/artista', () {
      final CatalogoLocal cat = mapearEscaneo(<LocalSong>[
        _song(101, title: 'Suelta'),
      ]);
      expect(cat.pistas, hasLength(1));
      expect(cat.albums, isEmpty);
      expect(cat.artistas, isEmpty);
      final p = cat.pistas.first;
      expect(p.albumId.value, isNull);
      expect(p.artistaId.value, isNull);
      expect(p.artistaNombre.value, kArtistaDesconocido);
    });

    test('varias pistas del mismo álbum → un solo álbum/artista', () {
      final CatalogoLocal cat = mapearEscaneo(<LocalSong>[
        _song(1, artist: 'A', artistId: 1, album: 'X', albumId: 9),
        _song(2, artist: 'A', artistId: 1, album: 'X', albumId: 9),
        _song(3, artist: 'A', artistId: 1, album: 'X', albumId: 9),
      ]);
      expect(cat.pistas, hasLength(3));
      expect(cat.albums, hasLength(1));
      expect(cat.artistas, hasLength(1));
    });
  });
}
