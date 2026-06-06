import 'package:freezed_annotation/freezed_annotation.dart';

part 'manifest_dto.freezed.dart';
part 'manifest_dto.g.dart';

// DTOs espejo del payload as-built del PC (docs/pc-contract.md §4.3).
// Tolerantes: campos desconocidos se ignoran; los timestamps se conservan como
// String ISO-8601 (el orden lexicográfico = cronológico, según el contrato).

/// Respuesta de `GET /api/v1/manifest?since=&limit=`.
@freezed
abstract class ManifestDto with _$ManifestDto {
  const factory ManifestDto({
    @Default(1) int protocolo,
    @Default(0) int since,

    /// High-water mark global del PC.
    @Default(0) int syncVersionActual,

    /// Alias de compatibilidad (mismo valor que [syncVersionActual]).
    @Default(0) int syncVersion,

    /// Cursor para la siguiente página.
    @Default(0) int nextSince,
    @Default(false) bool hasMore,
    String? generadoEn,
    @Default(<PistaDto>[]) List<PistaDto> pistas,
    @Default(<AlbumDto>[]) List<AlbumDto> albums,
    @Default(<ArtistaDto>[]) List<ArtistaDto> artistas,
    @Default(<PlaylistDto>[]) List<PlaylistDto> playlists,
    @Default(<TombstoneDto>[]) List<TombstoneDto> tombstones,
    PerfilDto? perfil,
  }) = _ManifestDto;

  factory ManifestDto.fromJson(Map<String, dynamic> json) =>
      _$ManifestDtoFromJson(json);
}

/// Pista del manifest (campos planos).
@freezed
abstract class PistaDto with _$PistaDto {
  const factory PistaDto({
    required int id,
    required String titulo,
    @Default('') String artistaNombre,
    String? albumTitulo,
    int? albumId,
    int? artistaId,
    int? trackNumber,
    @Default(0) double duracionSeg,
    int? anio,
    String? genero,
    String? isrc,
    String? mbRecordingId,
    @Default(false) bool favorita,
    String? favoritaActualizadaEn,
    String? hashSha256,
    @Default(0) int syncVersion,
    double? bpm,
    double? energy,
    String? key,
    String? audioUrl,
    String? coverUrl,
    String? lyricsUrl,
  }) = _PistaDto;

  factory PistaDto.fromJson(Map<String, dynamic> json) =>
      _$PistaDtoFromJson(json);
}

/// Álbum del manifest.
@freezed
abstract class AlbumDto with _$AlbumDto {
  const factory AlbumDto({
    required int id,
    required String titulo,
    int? artistaId,
    @Default('Album') String tipo,
    int? anio,
    @Default(0) int syncVersion,
    String? coverUrl,
  }) = _AlbumDto;

  factory AlbumDto.fromJson(Map<String, dynamic> json) =>
      _$AlbumDtoFromJson(json);
}

/// Artista del manifest.
@freezed
abstract class ArtistaDto with _$ArtistaDto {
  const factory ArtistaDto({
    required int id,
    required String nombre,
    @Default(0) int syncVersion,
    String? imagenUrl,
  }) = _ArtistaDto;

  factory ArtistaDto.fromJson(Map<String, dynamic> json) =>
      _$ArtistaDtoFromJson(json);
}

/// Playlist del manifest (read-only en v1). `pistaIds` en orden de posición.
@freezed
abstract class PlaylistDto with _$PlaylistDto {
  const factory PlaylistDto({
    required int id,
    required String nombre,
    @Default('manual') String tipo,
    String? autoKey,
    @Default(0) int syncVersion,
    @Default(<int>[]) List<int> pistaIds,
  }) = _PlaylistDto;

  factory PlaylistDto.fromJson(Map<String, dynamic> json) =>
      _$PlaylistDtoFromJson(json);
}

/// Tombstone: borrado a aplicar en local.
@freezed
abstract class TombstoneDto with _$TombstoneDto {
  const factory TombstoneDto({
    required String entidad,
    required int entidadId,
    @Default(0) int syncVersion,
  }) = _TombstoneDto;

  factory TombstoneDto.fromJson(Map<String, dynamic> json) =>
      _$TombstoneDtoFromJson(json);
}

/// Perfil del usuario en el PC.
@freezed
abstract class PerfilDto with _$PerfilDto {
  const factory PerfilDto({
    @Default('') String nombre,
    @Default('') String foto,
    EstadisticasDto? estadisticas,
  }) = _PerfilDto;

  factory PerfilDto.fromJson(Map<String, dynamic> json) =>
      _$PerfilDtoFromJson(json);
}

/// Estadísticas del perfil.
@freezed
abstract class EstadisticasDto with _$EstadisticasDto {
  const factory EstadisticasDto({
    @Default(0) int totalPistas,
    @Default(0) int totalFavoritas,
  }) = _EstadisticasDto;

  factory EstadisticasDto.fromJson(Map<String, dynamic> json) =>
      _$EstadisticasDtoFromJson(json);
}
