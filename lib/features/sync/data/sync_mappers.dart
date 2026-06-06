import 'package:drift/drift.dart';

import '../../../data/db/database.dart';
import '../../../data/models/manifest_dto.dart';

// Mapea los DTOs del manifest (docs/pc-contract.md §4.3) a companions de Drift.
// Las `*_url` relativas del PC se guardan en las columnas `*_path`; el resolver
// de medios las trata como "remotas no descargadas" hasta la tanda offline.

ArtistasCompanion toArtistaCompanion(ArtistaDto d) => ArtistasCompanion.insert(
      id: Value(d.id),
      nombre: d.nombre,
      imagenPath: Value(d.imagenUrl),
      syncVersion: Value(d.syncVersion),
    );

AlbumsCompanion toAlbumCompanion(AlbumDto d) => AlbumsCompanion.insert(
      id: Value(d.id),
      titulo: d.titulo,
      artistaId: Value(d.artistaId),
      tipo: Value(d.tipo),
      anio: Value(d.anio),
      coverPath: Value(d.coverUrl),
      syncVersion: Value(d.syncVersion),
    );

PistasCompanion toPistaCompanion(PistaDto d) => PistasCompanion.insert(
      id: Value(d.id),
      titulo: d.titulo,
      artistaNombre: d.artistaNombre,
      albumTitulo: Value(d.albumTitulo),
      albumId: Value(d.albumId),
      artistaId: Value(d.artistaId),
      trackNumber: Value(d.trackNumber),
      duracionSeg: Value(d.duracionSeg),
      anio: Value(d.anio),
      genero: Value(d.genero),
      isrc: Value(d.isrc),
      hashSha256: Value(d.hashSha256),
      bpm: Value(d.bpm),
      energy: Value(d.energy),
      keyMusical: Value(d.key),
      coverPath: Value(d.coverUrl),
      lyricsPath: Value(d.lyricsUrl),
      audioPath: Value(d.audioUrl),
      syncVersion: Value(d.syncVersion),
    );

PlaylistsCompanion toPlaylistCompanion(PlaylistDto d) =>
    PlaylistsCompanion.insert(
      id: Value(d.id),
      nombre: d.nombre,
      tipo: Value(d.tipo),
      autoKey: Value(d.autoKey),
      syncVersion: Value(d.syncVersion),
    );

/// Filas de pertenencia de una playlist, en el orden de `pistaIds`.
List<PlaylistPistasCompanion> toPlaylistPistas(PlaylistDto d) =>
    <PlaylistPistasCompanion>[
      for (int i = 0; i < d.pistaIds.length; i++)
        PlaylistPistasCompanion.insert(
          playlistId: d.id,
          pistaId: d.pistaIds[i],
          posicion: i,
        ),
    ];
