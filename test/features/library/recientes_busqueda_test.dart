import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/library/application/recientes_busqueda.dart';

void main() {
  group('ItemBusqueda', () {
    test('roundtrip JSON conserva los campos', () {
      const ItemBusqueda it = ItemBusqueda(
        tipo: TipoItemBusqueda.album,
        id: 42,
        titulo: 'Random Access Memories',
        subtitulo: 'Álbum',
        cover: '/api/asset/cover/42',
      );
      final ItemBusqueda back = ItemBusqueda.fromJson(it.toJson());
      expect(back.tipo, TipoItemBusqueda.album);
      expect(back.id, 42);
      expect(back.titulo, 'Random Access Memories');
      expect(back.subtitulo, 'Álbum');
      expect(back.cover, '/api/asset/cover/42');
    });

    test('playlist sin cover serializa sin la clave', () {
      const ItemBusqueda it = ItemBusqueda(
        tipo: TipoItemBusqueda.playlist,
        id: 7,
        titulo: 'Mix',
        subtitulo: 'Playlist',
      );
      expect(it.toJson().containsKey('cover'), isFalse);
      expect(ItemBusqueda.fromJson(it.toJson()).cover, isNull);
    });

    test('circular solo para artistas', () {
      const ItemBusqueda artista = ItemBusqueda(
        tipo: TipoItemBusqueda.artista,
        id: 1,
        titulo: 'Daft Punk',
        subtitulo: 'Artista',
      );
      const ItemBusqueda pista = ItemBusqueda(
        tipo: TipoItemBusqueda.pista,
        id: 2,
        titulo: 'Get Lucky',
        subtitulo: 'Canción',
      );
      expect(artista.circular, isTrue);
      expect(pista.circular, isFalse);
    });

    test('mismo() identifica por tipo + id (no por título)', () {
      const ItemBusqueda a = ItemBusqueda(
        tipo: TipoItemBusqueda.album,
        id: 5,
        titulo: 'A',
        subtitulo: 'Álbum',
      );
      const ItemBusqueda b = ItemBusqueda(
        tipo: TipoItemBusqueda.album,
        id: 5,
        titulo: 'A renombrado',
        subtitulo: 'Álbum',
      );
      const ItemBusqueda c = ItemBusqueda(
        tipo: TipoItemBusqueda.pista,
        id: 5,
        titulo: 'A',
        subtitulo: 'Canción',
      );
      expect(a.mismo(b), isTrue);
      expect(a.mismo(c), isFalse);
    });
  });
}
