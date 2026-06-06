import 'package:freezed_annotation/freezed_annotation.dart';

part 'seleccion_dto.freezed.dart';
part 'seleccion_dto.g.dart';

/// Selección de sync por dispositivo (docs/pc-contract.md §4.4): qué metadata
/// entra al catálogo del móvil. `modo` ∈ {todo, nada, artistas, playlists}.
@freezed
abstract class SeleccionDto with _$SeleccionDto {
  const factory SeleccionDto({
    @Default('todo') String modo,
    @Default(<int>[]) List<int> artistaIds,
    @Default(<int>[]) List<int> playlistIds,
  }) = _SeleccionDto;

  factory SeleccionDto.fromJson(Map<String, dynamic> json) =>
      _$SeleccionDtoFromJson(json);
}
