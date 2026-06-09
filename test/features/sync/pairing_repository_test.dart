import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/features/sync/data/pairing_repository.dart';
import 'package:nb_sound_mobile/features/sync/data/qr_payload.dart';

/// Adaptador HTTP fake: responde con un cuerpo/estado fijos (sin red real).
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic> body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// SecureStore en memoria para tests.
class _FakeStore implements SecureStore {
  PairedPc? saved;

  @override
  Future<void> savePairing(PairedPc pc) async => saved = pc;
  @override
  Future<void> clear() async => saved = null;
  @override
  Future<PairedPc?> readPairing() async => saved;
  @override
  Future<String?> deviceToken() async => saved?.deviceToken;
  @override
  Future<bool> isPaired() async => saved != null;
  @override
  Future<void> updateEndpoint(String host, int port) async {}
}

DioFactory _factory(_FakeAdapter adapter) {
  return ({required String baseUrl, String? fingerprint, Future<String?> Function()? token}) {
    final Dio dio = Dio(BaseOptions(baseUrl: baseUrl));
    dio.httpClientAdapter = adapter;
    return dio;
  };
}

void main() {
  final QrPairingPayload qr = QrPairingPayload.tryParse(jsonEncode(<String, dynamic>{
    'host': '192.168.1.40',
    'puerto': 8731,
    'token': 'efimero',
    'tls': true,
    'tls_fingerprint': 'abc123',
  }))!;

  test('pair() guarda el device_token y la huella al tener éxito', () async {
    final _FakeStore store = _FakeStore();
    final PairingRepository repo = PairingRepository(
      store,
      dioFactory: _factory(_FakeAdapter(
        statusCode: 200,
        body: <String, dynamic>{
          'ok': true,
          'device_token': 'persistente-xyz',
          'dispositivo_id': 3,
          'nombre': 'Pixel 8',
        },
      )),
    );

    final PairedPc pc = await repo.pair(
      qr,
      deviceName: 'Pixel 8',
      platform: 'android',
    );

    expect(pc.deviceToken, 'persistente-xyz');
    expect(pc.fingerprint, 'abc123');
    expect(pc.host, '192.168.1.40');
    expect(store.saved?.deviceToken, 'persistente-xyz');
  });

  test('pair() con 401 lanza PairingException de token expirado', () async {
    final PairingRepository repo = PairingRepository(
      _FakeStore(),
      dioFactory: _factory(_FakeAdapter(
        statusCode: 401,
        body: <String, dynamic>{'error': 'token_invalido_o_expirado'},
      )),
    );

    expect(
      () => repo.pair(qr, deviceName: 'x', platform: 'android'),
      throwsA(isA<PairingException>().having(
        (PairingException e) => e.code,
        'code',
        'token_invalido_o_expirado',
      )),
    );
  });

  test('ping() parsea la respuesta del PC', () async {
    final PairingRepository repo = PairingRepository(
      _FakeStore(),
      dioFactory: _factory(_FakeAdapter(
        statusCode: 200,
        body: <String, dynamic>{
          'ok': true,
          'servicio': 'NB Sound',
          'version_protocolo': 1,
        },
      )),
    );
    final pong = await repo.ping(const PairedPc(
      deviceToken: 't',
      fingerprint: 'abc123',
      host: 'h',
      port: 8731,
      nombre: 'PC',
    ));
    expect(pong.ok, isTrue);
    expect(pong.versionProtocolo, 1);
  });

  group('pairPorIp (conexión manual sin cámara)', () {
    final _FakeAdapter pairOk = _FakeAdapter(
      statusCode: 200,
      body: <String, dynamic>{
        'ok': true,
        'device_token': 'tok-ip',
        'dispositivo_id': 9,
        'nombre': 'PC',
      },
    );

    test('parsea host:puerto, usa la huella aprendida y empareja', () async {
      String? hostVisto;
      int? puertoVisto;
      final _FakeStore store = _FakeStore();
      final PairingRepository repo = PairingRepository(
        store,
        dioFactory: _factory(pairOk),
        discovery: (String host, int? puerto) async {
          hostVisto = host;
          puertoVisto = puerto;
          return const DiscoveredEndpoint(
            host: '192.168.1.40',
            puerto: 8731,
            fingerprint: 'fp-aprendida',
            tls: true,
          );
        },
      );

      final PairedPc pc = await repo.pairPorIp(
        direccion: '192.168.1.40:8731',
        codigo: 'efimero',
        deviceName: 'x',
        platform: 'android',
      );

      expect(hostVisto, '192.168.1.40');
      expect(puertoVisto, 8731);
      expect(pc.deviceToken, 'tok-ip');
      expect(pc.fingerprint, 'fp-aprendida');
      expect(store.saved?.deviceToken, 'tok-ip');
    });

    test('sin puerto: lo deja descubrir (puerto null al descubridor)', () async {
      int? puertoVisto = -1;
      final PairingRepository repo = PairingRepository(
        _FakeStore(),
        dioFactory: _factory(pairOk),
        discovery: (String host, int? puerto) async {
          puertoVisto = puerto;
          return DiscoveredEndpoint(host: host, puerto: 8733, fingerprint: 'fp');
        },
      );

      await repo.pairPorIp(
        direccion: '10.0.0.5',
        codigo: 'c',
        deviceName: 'x',
        platform: 'android',
      );
      expect(puertoVisto, isNull);
    });

    test('no se encuentra el PC ⇒ PairingException(pc_no_encontrado)', () async {
      final PairingRepository repo = PairingRepository(
        _FakeStore(),
        dioFactory: _factory(pairOk),
        discovery: (String host, int? puerto) async => null,
      );
      expect(
        () => repo.pairPorIp(
            direccion: '1.2.3.4', codigo: 'c', deviceName: 'x', platform: 'android'),
        throwsA(isA<PairingException>().having(
            (PairingException e) => e.code, 'code', 'pc_no_encontrado')),
      );
    });

    test('dirección vacía ⇒ PairingException(direccion_invalida)', () async {
      final PairingRepository repo = PairingRepository(
        _FakeStore(),
        dioFactory: _factory(pairOk),
        discovery: (String host, int? puerto) async =>
            DiscoveredEndpoint(host: host, puerto: 8731),
      );
      expect(
        () => repo.pairPorIp(
            direccion: '   ', codigo: 'c', deviceName: 'x', platform: 'android'),
        throwsA(isA<PairingException>().having(
            (PairingException e) => e.code, 'code', 'direccion_invalida')),
      );
    });
  });
}
