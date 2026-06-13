import 'package:freezed_annotation/freezed_annotation.dart';

part 'remote_dtos.freezed.dart';
part 'remote_dtos.g.dart';

// Frames del WebSocket de control (docs/pc-contract.md §5). El PC publica
// `estado` (esquema plano) y, ante `queue`, un frame `cola`.

/// Pista activa que publica el PC.
@freezed
abstract class RemotePistaDto with _$RemotePistaDto {
  const factory RemotePistaDto({
    @Default(0) int id,
    @Default('') String titulo,
    @Default('') String artista,
    @Default('') String album,
    @Default(0) double duracionSeg,
    String? coverUrl,
  }) = _RemotePistaDto;

  factory RemotePistaDto.fromJson(Map<String, dynamic> json) =>
      _$RemotePistaDtoFromJson(json);
}

/// Frame de estado del reproductor del PC (push → móvil).
@freezed
abstract class RemoteEstadoDto with _$RemoteEstadoDto {
  const factory RemoteEstadoDto({
    @Default(false) bool reproduciendo,
    RemotePistaDto? pista,
    @Default(0) double posicionSeg,
    @Default(0) int volumen,
    @Default('ninguno') String modoRepeticion,
    @Default(false) bool aleatorio,
    @Default(false) bool karaokeActivo,
    @Default(0) int indiceCola,
    // El PC está en sesión de DJ Privado: tiene el control global del audio y los
    // comandos del móvil quedan bloqueados hasta que la sesión termine. El campo
    // es aditivo; si el PC no lo envía (versión vieja), por defecto false.
    @Default(false) bool djActivo,
  }) = _RemoteEstadoDto;

  factory RemoteEstadoDto.fromJson(Map<String, dynamic> json) =>
      _$RemoteEstadoDtoFromJson(json);
}

/// Frame de cola (respuesta a `queue`).
@freezed
abstract class RemoteColaDto with _$RemoteColaDto {
  const factory RemoteColaDto({
    @Default(<RemotePistaDto>[]) List<RemotePistaDto> items,
    @Default(0) int indice,
  }) = _RemoteColaDto;

  factory RemoteColaDto.fromJson(Map<String, dynamic> json) =>
      _$RemoteColaDtoFromJson(json);
}
