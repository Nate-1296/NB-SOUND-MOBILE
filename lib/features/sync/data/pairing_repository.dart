import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

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

/// Endpoint del PC descubierto al conectar por IP: host + puerto + huella TLS
/// aprendida (TOFU). [fingerprint] es null si el PC habla en claro (sin TLS).
class DiscoveredEndpoint {
  const DiscoveredEndpoint({
    required this.host,
    required this.puerto,
    this.fingerprint,
    this.tls = true,
  });

  final String host;
  final int puerto;
  final String? fingerprint;
  final bool tls;
}

/// Descubre un endpoint NB Sound en [host] (puerto fijo o escaneo). Inyectable
/// para tests; la implementación real hace TOFU sobre `/api/v1/ping`.
typedef EndpointDiscovery = Future<DiscoveredEndpoint?> Function(
    String host, int? puerto);

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
  PairingRepository(
    this._store, {
    DioFactory? dioFactory,
    EndpointDiscovery? discovery,
  }) : _dioFactory = dioFactory ?? NbApiClient.create {
    _discovery = discovery ?? _descubrirReal;
  }

  final SecureStore _store;
  final DioFactory _dioFactory;
  late final EndpointDiscovery _discovery;

  /// Rango de puertos del servidor del PC (docs/pc-contract.md §1).
  static const int _puertoMin = 8731;
  static const int _puertoMax = 8799;
  static const Duration _pingTimeout = Duration(milliseconds: 1500);

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

  /// Emparejamiento por IP (sin QR): descubre el endpoint en [direccion] (host o
  /// `host:puerto`), aprende la huella TLS por TOFU y llama a `/pair` con el
  /// [codigo] de un solo uso. Reusa [pair] una vez resuelto el endpoint.
  Future<PairedPc> pairPorIp({
    required String direccion,
    required String codigo,
    required String deviceName,
    required String platform,
  }) async {
    final (String host, int? puerto) = _parseDireccion(direccion);
    if (host.isEmpty) {
      throw PairingException('direccion_invalida');
    }
    final DiscoveredEndpoint? ep = await _discovery(host, puerto);
    if (ep == null) {
      throw PairingException('pc_no_encontrado');
    }
    final QrPairingPayload payload = QrPairingPayload(
      host: ep.host,
      puerto: ep.puerto,
      token: codigo,
      tls: ep.tls,
      tlsFingerprint: ep.fingerprint ?? '',
    );
    return pair(payload, deviceName: deviceName, platform: platform);
  }

  /// Descubrimiento real: escanea HTTPS (TOFU) y, como degradación, HTTP plano.
  Future<DiscoveredEndpoint?> _descubrirReal(String host, int? puerto) async {
    final List<int> puertos = puerto != null
        ? <int>[puerto]
        : <int>[for (int p = _puertoMin; p <= _puertoMax; p++) p];
    for (final bool tls in <bool>[true, false]) {
      final DiscoveredEndpoint? ep = await _escanear(host, puertos, tls: tls);
      if (ep != null) {
        return ep;
      }
    }
    return null;
  }

  Future<DiscoveredEndpoint?> _escanear(
    String host,
    List<int> puertos, {
    required bool tls,
  }) async {
    const int lote = 12;
    for (int i = 0; i < puertos.length; i += lote) {
      final int fin = (i + lote < puertos.length) ? i + lote : puertos.length;
      final List<DiscoveredEndpoint?> res = await Future.wait(
        <Future<DiscoveredEndpoint?>>[
          for (final int p in puertos.sublist(i, fin)) _ping1(host, p, tls: tls),
        ],
      );
      for (final DiscoveredEndpoint? r in res) {
        if (r != null) {
          return r; // el primero del lote (puerto más bajo)
        }
      }
    }
    return null;
  }

  /// Un intento de `/ping` a `host:puerto`. En TLS aprende la huella (TOFU:
  /// acepta el cert solo para leer su SHA-256). Devuelve el endpoint si responde
  /// como un servidor NB Sound; null en cualquier otro caso.
  Future<DiscoveredEndpoint?> _ping1(
    String host,
    int puerto, {
    required bool tls,
  }) async {
    String? fingerprint;
    final HttpClient client = HttpClient()
      ..connectionTimeout = _pingTimeout;
    if (tls) {
      client.badCertificateCallback =
          (X509Certificate cert, String h, int p) {
        fingerprint = sha256.convert(cert.der).toString();
        return true; // TOFU en descubrimiento: aceptar para fijar la huella.
      };
    }
    final Dio dio = Dio(BaseOptions(
      baseUrl: '${tls ? 'https' : 'http'}://$host:$puerto',
      connectTimeout: _pingTimeout,
      receiveTimeout: _pingTimeout,
      sendTimeout: _pingTimeout,
    ));
    dio.httpClientAdapter =
        IOHttpClientAdapter(createHttpClient: () => client);
    try {
      final Response<dynamic> res = await dio.get<dynamic>('/api/v1/ping');
      final dynamic data = res.data;
      final bool ok = data is Map && data['ok'] == true;
      final bool esNbSound = data is Map && data['servicio'] != null;
      if (res.statusCode == 200 && ok && esNbSound) {
        return DiscoveredEndpoint(
          host: host,
          puerto: puerto,
          fingerprint: tls ? fingerprint : null,
          tls: tls,
        );
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      dio.close(force: true);
    }
  }

  /// Parsea "host", "host:puerto", "https://host:puerto" o "[ipv6]:puerto".
  /// Devuelve (host, puerto?) — puerto null si no se indicó.
  static (String, int?) _parseDireccion(String direccion) {
    String s = direccion.trim();
    s = s.replaceFirst(RegExp(r'^[a-zA-Z]+://'), '');
    s = s.replaceAll(RegExp(r'/+$'), '');
    final RegExpMatch? ipv6 = RegExp(r'^\[(.+)\](?::(\d+))?$').firstMatch(s);
    if (ipv6 != null) {
      final String? p = ipv6.group(2);
      return (ipv6.group(1)!.trim(), p != null ? int.tryParse(p) : null);
    }
    final int idx = s.lastIndexOf(':');
    if (idx > 0 && idx < s.length - 1) {
      final int? p = int.tryParse(s.substring(idx + 1));
      if (p != null) {
        return (s.substring(0, idx).trim(), p);
      }
    }
    return (s.trim(), null);
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

  /// Heartbeat de presencia: ping **autenticado** (con el `device_token`) para que
  /// el PC marque este dispositivo como "conectado ahora" en su Sincronización
  /// aunque no esté en Connect (sin WS abierto). El PC actualiza `ultima_conexion`
  /// al recibirlo. Best-effort: un fallo se reintenta en el siguiente tick.
  Future<void> heartbeat(PairedPc pc) async {
    try {
      final Dio dio = _dioFactory(
        baseUrl: pc.baseUrl,
        fingerprint: pc.fingerprint,
        token: _store.deviceToken,
      );
      await dio.get<dynamic>('/api/v1/ping');
    } catch (_) {
      // Presencia best-effort: no rompe nada si el PC no responde.
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
