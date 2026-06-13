import 'package:drift/drift.dart';

import '../../../data/db/database.dart';
import '../data/local_media_channel.dart';
import 'local_ids.dart';

/// Etiqueta de artista/álbum cuando MediaStore no lo aporta (pista "flotante").
const String kArtistaDesconocido = 'Artista desconocido';

/// Companions resultantes de mapear un escaneo de MediaStore al catálogo local.
typedef CatalogoLocal = ({
  List<ArtistasCompanion> artistas,
  List<AlbumsCompanion> albums,
  List<PistasCompanion> pistas,
});

/// Convierte el escaneo de MediaStore en filas de catálogo con `origen='local'`
/// e **ids negativos** (ver local_ids.dart). Crea álbumes/artistas locales para
/// las pistas que sí traen esa metadata; las que no, quedan **flotantes**
/// (`albumId`/`artistaId` null). Función pura (no toca BD ni canales).
CatalogoLocal mapearEscaneo(List<LocalSong> canciones) {
  final Map<int, ArtistasCompanion> artistas = <int, ArtistasCompanion>{};
  final Map<int, AlbumsCompanion> albums = <int, AlbumsCompanion>{};
  final List<PistasCompanion> pistas = <PistasCompanion>[];

  for (final LocalSong s in canciones) {
    final int pistaId = idLocalPista(s.id);
    final int? albumId = idLocalAlbum(s.albumId);
    final int? artistaId = idLocalArtista(s.artistId);

    // Artista local (si MediaStore aporta artistId).
    if (artistaId != null && !artistas.containsKey(artistaId)) {
      artistas[artistaId] = ArtistasCompanion.insert(
        id: Value<int>(artistaId),
        nombre: s.artist ?? kArtistaDesconocido,
        origen: const Value<String>(origenLocal),
      );
    }
    // Álbum local (si MediaStore aporta albumId). La carátula queda null por
    // ahora → muestra el placeholder tipado; la extracción de la carátula
    // embebida (vía el canal nativo `artwork` + esquema `localart://`) es el
    // siguiente sub-paso y rellenará `coverPath` de forma incremental.
    if (albumId != null && !albums.containsKey(albumId)) {
      albums[albumId] = AlbumsCompanion.insert(
        id: Value<int>(albumId),
        titulo: s.album ?? 'Álbum desconocido',
        artistaId: Value<int?>(artistaId),
        anio: Value<int?>(s.year),
        origen: const Value<String>(origenLocal),
      );
    }

    pistas.add(
      PistasCompanion.insert(
        id: Value<int>(pistaId),
        titulo: s.title,
        artistaNombre: s.artist ?? kArtistaDesconocido,
        albumTitulo: Value<String?>(s.album),
        albumId: Value<int?>(albumId),
        artistaId: Value<int?>(artistaId),
        trackNumber: Value<int?>(s.track),
        duracionSeg: Value<double>(s.durationMs / 1000.0),
        anio: Value<int?>(s.year),
        audioPath: Value<String?>(s.uri),
        origen: const Value<String>(origenLocal),
      ),
    );
  }

  return (
    artistas: artistas.values.toList(growable: false),
    albums: albums.values.toList(growable: false),
    pistas: pistas,
  );
}
