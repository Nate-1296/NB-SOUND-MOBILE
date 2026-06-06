import 'package:dio/dio.dart';

import '../../../core/security/secure_store.dart';

/// Comprueba la disponibilidad del instrumental de karaoke
/// (docs/pc-contract.md §4.8: `GET /track/{id}/stems`, 404 `sin_stems`).
/// La reproducción del stem la hace just_audio por streaming; aquí solo se
/// resuelve si existe, para habilitar/inhabilitar el toggle de karaoke.
class StemsRepository {
  StemsRepository({required this.dioFor});

  final Dio Function(PairedPc pc) dioFor;

  /// true si la pista tiene karaoke generado (200/206); false si 404 u otro.
  Future<bool> disponible(PairedPc pc, int pistaId) async {
    try {
      final Response<dynamic> res = await dioFor(pc).get<dynamic>(
        '/api/v1/track/$pistaId/stems',
        options: Options(
          headers: <String, dynamic>{'range': 'bytes=0-1'},
          responseType: ResponseType.bytes,
          validateStatus: (int? s) => s != null && s < 500,
        ),
      );
      final int code = res.statusCode ?? 0;
      return code == 200 || code == 206;
    } on DioException {
      return false;
    }
  }
}
