import 'package:dio/dio.dart';

import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import 'pairing_models.dart';
import 'qr_payload.dart';

/// Fábrica de [Dio] inyectable (los tests pasan una con mock adapter).
typedef DioFactory = Dio Function({
  required String baseUrl,
  String? fingerprint,
  Future<String?> Function()? token,
});

/// Error de emparejamiento con un código estable para la UI.
class PairingException implements Exception {
  PairingException(this.code);
  final String code;
  @override
  String toString() => 'PairingException($code)';
}

/// Cliente del handshake: `POST /api/v1/pair`, `GET /api/v1/ping` y persistencia
/// segura de las credenciales (docs/pc-contract.md §2, §4.1–4.2).
class PairingRepository {
  PairingRepository(this._store, {DioFactory? dioFactory})
      : _dioFactory = dioFactory ?? NbApiClient.create;

  final SecureStore _store;
  final DioFactory _dioFactory;

  Future<PairedPc> pair(
    QrPairingPayload qr, {
    required String deviceName,
    required String platform,
  }) async {
    final Dio dio = _dioFactory(
      baseUrl: qr.baseUrl,
      fingerprint: qr.pinnedFingerprint,
    );
    final Response<dynamic> res;
    try {
      res = await dio.post<dynamic>(
        '/api/v1/pair',
        data: <String, dynamic>{
          'token': qr.token,
          'nombre_dispositivo': deviceName,
          'plataforma': platform,
        },
      );
    } on DioException catch (e) {
      throw PairingException(_codeFor(e));
    }

    final PairResponse pr = PairResponse.fromJson(_asMap(res.data));
    if (!pr.ok || pr.deviceToken.isEmpty) {
      throw PairingException(pr.error ?? 'respuesta_invalida');
    }

    final PairedPc pc = PairedPc(
      deviceToken: pr.deviceToken,
      fingerprint: qr.pinnedFingerprint,
      host: qr.host,
      port: qr.puerto,
      nombre: pr.nombre.isEmpty ? qr.servicio : pr.nombre,
    );
    await _store.savePairing(pc);
    return pc;
  }

  Future<PingResponse> ping(PairedPc pc) async {
    final Dio dio = _dioFactory(
      baseUrl: pc.baseUrl,
      fingerprint: pc.fingerprint,
    );
    final Response<dynamic> res = await dio.get<dynamic>('/api/v1/ping');
    return PingResponse.fromJson(_asMap(res.data));
  }

  Future<bool> reachable(PairedPc pc) async {
    try {
      return (await ping(pc)).ok;
    } on DioException {
      return false;
    }
  }

  Future<void> unpair() => _store.clear();

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};

  static String _codeFor(DioException e) {
    if (e.response?.statusCode == 401) {
      return 'token_invalido_o_expirado';
    }
    return 'error_red';
  }
}
