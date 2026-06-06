import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_dto.freezed.dart';
part 'history_dto.g.dart';

// DTOs de `POST /api/v1/history` (docs/pc-contract.md §4.9). El historial se
// inserta siempre (append); los favoritos siguen last-write-wins por timestamp.

/// Ítem de historial a subir.
@freezed
abstract class HistorialItemDto with _$HistorialItemDto {
  const factory HistorialItemDto({
    required int pistaId,
    required String reproducidoEn,
    double? duracionSeg,
    @Default(false) bool completada,
  }) = _HistorialItemDto;

  factory HistorialItemDto.fromJson(Map<String, dynamic> json) =>
      _$HistorialItemDtoFromJson(json);
}

/// Ítem de favorito a subir (con timestamp para el merge).
@freezed
abstract class FavoritoItemDto with _$FavoritoItemDto {
  const factory FavoritoItemDto({
    required int pistaId,
    required bool favorita,
    required String actualizadaEn,
  }) = _FavoritoItemDto;

  factory FavoritoItemDto.fromJson(Map<String, dynamic> json) =>
      _$FavoritoItemDtoFromJson(json);
}

/// Cuerpo de la petición de subida.
@freezed
abstract class HistoryUploadRequest with _$HistoryUploadRequest {
  const factory HistoryUploadRequest({
    @Default(<HistorialItemDto>[]) List<HistorialItemDto> historial,
    @Default(<FavoritoItemDto>[]) List<FavoritoItemDto> favoritos,
  }) = _HistoryUploadRequest;

  factory HistoryUploadRequest.fromJson(Map<String, dynamic> json) =>
      _$HistoryUploadRequestFromJson(json);
}

/// Respuesta de la subida.
@freezed
abstract class HistoryUploadResponse with _$HistoryUploadResponse {
  const factory HistoryUploadResponse({
    @Default(false) bool ok,
    @Default(0) int historialInsertado,
    @Default(0) int favoritosAplicados,
    @Default(0) int favoritosIgnorados,
  }) = _HistoryUploadResponse;

  factory HistoryUploadResponse.fromJson(Map<String, dynamic> json) =>
      _$HistoryUploadResponseFromJson(json);
}
