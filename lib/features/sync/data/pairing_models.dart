import 'package:freezed_annotation/freezed_annotation.dart';

part 'pairing_models.freezed.dart';
part 'pairing_models.g.dart';

/// Respuesta de `POST /api/v1/pair` (docs/pc-contract.md §4.2).
@freezed
abstract class PairResponse with _$PairResponse {
  const factory PairResponse({
    @Default(false) bool ok,
    @Default('') String deviceToken,
    int? dispositivoId,
    @Default('') String nombre,
    String? error,
  }) = _PairResponse;

  factory PairResponse.fromJson(Map<String, dynamic> json) =>
      _$PairResponseFromJson(json);
}

/// Respuesta de `GET /api/v1/ping` (docs/pc-contract.md §4.1).
@freezed
abstract class PingResponse with _$PingResponse {
  const factory PingResponse({
    @Default(false) bool ok,
    @Default('') String servicio,
    @Default(0) int versionProtocolo,
  }) = _PingResponse;

  factory PingResponse.fromJson(Map<String, dynamic> json) =>
      _$PingResponseFromJson(json);
}
