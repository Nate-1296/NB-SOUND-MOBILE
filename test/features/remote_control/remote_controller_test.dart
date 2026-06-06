import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/features/remote_control/application/remote_controller.dart';
import 'package:nb_sound_mobile/features/remote_control/data/remote_dtos.dart';
import 'package:web_socket_channel/io.dart';

Future<void> _waitUntil(
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final DateTime end = DateTime.now().add(timeout);
  while (!cond() && DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

void main() {
  group('DTOs del WS', () {
    test('RemoteEstadoDto parsea el esquema plano del contrato', () {
      final RemoteEstadoDto e = RemoteEstadoDto.fromJson(<String, dynamic>{
        'tipo': 'estado',
        'reproduciendo': true,
        'pista': <String, dynamic>{
          'id': 123,
          'titulo': 'One More Time',
          'artista': 'Daft Punk',
          'album': 'Discovery',
          'duracion_seg': 320.4,
          'cover_url': '/api/v1/asset/cover/10',
        },
        'posicion_seg': 42.3,
        'volumen': 80,
        'modo_repeticion': 'todas',
        'aleatorio': true,
        'karaoke_activo': false,
        'indice_cola': 4,
      });
      expect(e.reproduciendo, isTrue);
      expect(e.pista?.titulo, 'One More Time');
      expect(e.posicionSeg, 42.3);
      expect(e.volumen, 80);
      expect(e.modoRepeticion, 'todas');
      expect(e.aleatorio, isTrue);
      expect(e.indiceCola, 4);
    });

    test('RemoteColaDto parsea items + índice', () {
      final RemoteColaDto cola = RemoteColaDto.fromJson(<String, dynamic>{
        'tipo': 'cola',
        'items': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'titulo': 'A', 'artista': 'X'},
          <String, dynamic>{'id': 2, 'titulo': 'B', 'artista': 'Y'},
        ],
        'indice': 1,
      });
      expect(cola.items.length, 2);
      expect(cola.items[1].titulo, 'B');
      expect(cola.indice, 1);
    });
  });

  test('RemoteController refleja el estado del PC y envía comandos', () async {
    final HttpServer server = await HttpServer.bind('localhost', 0);
    final List<String> recibidos = <String>[];

    server.listen((HttpRequest req) async {
      final WebSocket ws = await WebSocketTransformer.upgrade(req);
      ws.listen((dynamic data) => recibidos.add(data as String));
      // Primer frame de estado al conectar.
      ws.add(jsonEncode(<String, dynamic>{
        'tipo': 'estado',
        'reproduciendo': true,
        'pista': <String, dynamic>{
          'id': 1,
          'titulo': 'Tema PC',
          'artista': 'Artista',
          'duracion_seg': 100,
        },
        'posicion_seg': 10,
        'volumen': 50,
      }));
    });
    addTearDown(() => server.close(force: true));

    final ProviderContainer container = ProviderContainer(
      overrides: [
        remoteControllerProvider.overrideWith(
          () => RemoteController(
            connect: (Uri url, {String? fingerprint, String? token}) =>
                IOWebSocketChannel.connect(url),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final RemoteController ctrl =
        container.read(remoteControllerProvider.notifier);
    ctrl.conectar(PairedPc(
      deviceToken: 't',
      fingerprint: null,
      host: 'localhost',
      port: server.port,
      nombre: 'PC',
    ));

    // El estado del PC se refleja.
    await _waitUntil(
      () => container.read(remoteControllerProvider).pista != null,
    );
    final RemoteState s = container.read(remoteControllerProvider);
    expect(s.conectado, isTrue);
    expect(s.pista?.titulo, 'Tema PC');
    expect(s.estado.volumen, 50);
    expect(s.estado.reproduciendo, isTrue);

    // Un comando viaja al PC con el esquema canónico.
    ctrl.buscarSeg(30);
    await _waitUntil(() => recibidos.isNotEmpty);
    final Map<String, dynamic> cmd =
        jsonDecode(recibidos.first) as Map<String, dynamic>;
    expect(cmd['tipo'], 'comando');
    expect(cmd['accion'], 'seek');
    expect(cmd['posicion_seg'], 30);

    ctrl.desconectar();
  });
}
