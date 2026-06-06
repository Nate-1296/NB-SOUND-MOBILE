import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Credenciales del PC emparejado, guardadas en almacenamiento seguro
/// (`device_token` y huella TLS nunca en la BD en claro; docs/local-data.md).
class PairedPc {
  const PairedPc({
    required this.deviceToken,
    required this.fingerprint,
    required this.host,
    required this.port,
    required this.nombre,
  });

  final String deviceToken;
  final String? fingerprint;
  final String host;
  final int port;
  final String nombre;

  String get baseUrl =>
      '${fingerprint != null ? 'https' : 'http'}://$host:$port';

  String get wsBaseUrl =>
      '${fingerprint != null ? 'wss' : 'ws'}://$host:$port';
}

/// Acceso al almacenamiento seguro del emparejamiento.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage])
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const String _kToken = 'pc_device_token';
  static const String _kFingerprint = 'pc_tls_fingerprint';
  static const String _kHost = 'pc_host';
  static const String _kPort = 'pc_port';
  static const String _kNombre = 'pc_nombre';

  Future<void> savePairing(PairedPc pc) async {
    await _s.write(key: _kToken, value: pc.deviceToken);
    await _s.write(key: _kHost, value: pc.host);
    await _s.write(key: _kPort, value: pc.port.toString());
    await _s.write(key: _kNombre, value: pc.nombre);
    if (pc.fingerprint != null) {
      await _s.write(key: _kFingerprint, value: pc.fingerprint);
    } else {
      await _s.delete(key: _kFingerprint);
    }
  }

  Future<PairedPc?> readPairing() async {
    final String? token = await _s.read(key: _kToken);
    final String? host = await _s.read(key: _kHost);
    final String? portStr = await _s.read(key: _kPort);
    final int? port = int.tryParse(portStr ?? '');
    if (token == null || host == null || port == null) {
      return null;
    }
    return PairedPc(
      deviceToken: token,
      fingerprint: await _s.read(key: _kFingerprint),
      host: host,
      port: port,
      nombre: await _s.read(key: _kNombre) ?? 'PC',
    );
  }

  Future<String?> deviceToken() => _s.read(key: _kToken);

  Future<bool> isPaired() async => (await _s.read(key: _kToken)) != null;

  /// Actualiza host/puerto tras redescubrir el PC por mDNS (sin tocar el token).
  Future<void> updateEndpoint(String host, int port) async {
    await _s.write(key: _kHost, value: host);
    await _s.write(key: _kPort, value: port.toString());
  }

  Future<void> clear() async {
    for (final String k in <String>[
      _kToken,
      _kFingerprint,
      _kHost,
      _kPort,
      _kNombre,
    ]) {
      await _s.delete(key: k);
    }
  }
}
