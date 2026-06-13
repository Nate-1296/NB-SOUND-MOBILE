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
        'modo_repeticion': 'todo',
        'aleatorio': true,
        'karaoke_activo': false,
        'karaoke_disponible': true,
        'indice_cola': 4,
      });
      expect(e.reproduciendo, isTrue);
      expect(e.pista?.titulo, 'One More Time');
      expect(e.posicionSeg, 42.3);
      expect(e.volumen, 80);
      expect(e.modoRepeticion, ModoRepeticionPc.todo);
      expect(e.aleatorio, isTrue);
      expect(e.karaokeDisponible, isTrue);
      expect(e.indiceCola, 4);
      expect(e.djActivo, isFalse); // ausente ⇒ default
    });

    test('karaoke_disponible ausente ⇒ default true (PC viejo)', () {
      final RemoteEstadoDto e = RemoteEstadoDto.fromJson(<String, dynamic>{
        'tipo': 'estado',
        'reproduciendo': false,
      });
      expect(e.karaokeDisponible, isTrue);
    });

    test('RemoteEstadoDto parsea dj_activo cuando el PC lo envía', () {
      final RemoteEstadoDto e = RemoteEstadoDto.fromJson(<String, dynamic>{
        'tipo': 'estado',
        'reproduciendo': false,
        'dj_activo': true,
      });
      expect(e.djActivo, isTrue);
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

    // Al conectar, el cliente pide la cola para poblar la vista espejada.
    await _waitUntil(() => recibidos.any(
        (String r) => (jsonDecode(r) as Map<String, dynamic>)['accion'] == 'queue'));

    // Un comando viaja al PC con el esquema canónico.
    ctrl.buscarSeg(30);
    await _waitUntil(() => recibidos.any(
        (String r) => (jsonDecode(r) as Map<String, dynamic>)['accion'] == 'seek'));
    final Map<String, dynamic> seek = recibidos
        .map((String r) => jsonDecode(r) as Map<String, dynamic>)
        .firstWhere((Map<String, dynamic> m) => m['accion'] == 'seek');
    expect(seek['tipo'], 'comando');
    expect(seek['posicion_seg'], 30);

    // Comandos nuevos de Connect: karaoke y cola espejada/manipulación.
    ctrl.alternarKaraoke();
    ctrl.establecerCola(<int>[3, 1, 2], 1);
    ctrl.moverEnCola(0, 2);
    ctrl.quitarDeCola(1);
    ctrl.vaciarCola();
    await _waitUntil(() => recibidos.any(
        (String r) => (jsonDecode(r) as Map<String, dynamic>)['accion'] == 'clear_queue'));

    Map<String, dynamic> porAccion(String accion) => recibidos
        .map((String r) => jsonDecode(r) as Map<String, dynamic>)
        .firstWhere((Map<String, dynamic> m) => m['accion'] == accion);

    expect(porAccion('karaoke')['tipo'], 'comando');
    final Map<String, dynamic> sq = porAccion('set_queue');
    expect(sq['ids'], <int>[3, 1, 2]);
    expect(sq['indice'], 1);
    final Map<String, dynamic> mv = porAccion('move_queue');
    expect(mv['desde'], 0);
    expect(mv['hasta'], 2);
    expect(porAccion('remove_queue')['indice'], 1);
    expect(porAccion('clear_queue')['accion'], 'clear_queue');

    // El ciclo de repetición habla el vocabulario AS-BUILT del PC: desde
    // 'ninguno' (estado inicial) el siguiente modo es 'todo', no 'todas' (que el
    // PC descartaría dejando la repetición sin poder encenderse desde el móvil).
    ctrl.cicloRepeticion();
    await _waitUntil(() => recibidos.any(
        (String r) => (jsonDecode(r) as Map<String, dynamic>)['accion'] == 'repeat'));
    final Map<String, dynamic> repeat = porAccion('repeat');
    expect(repeat['modo'], ModoRepeticionPc.todo);

    ctrl.desconectar();
  });

  group('planReconexion (backoff acotado del WS)', () {
    test('backoff exponencial acotado a 16 s', () {
      expect(planReconexion(1).delaySeconds, 1);
      expect(planReconexion(2).delaySeconds, 2);
      expect(planReconexion(3).delaySeconds, 4);
      expect(planReconexion(4).delaySeconds, 8);
      expect(planReconexion(5).delaySeconds, 16);
      expect(planReconexion(9).delaySeconds, 16); // tope
    });

    test('degrada a "error" tras agotar los intentos pero sigue reintentando',
        () {
      expect(planReconexion(5).degradar, isFalse);
      expect(planReconexion(6).degradar, isTrue);
      expect(planReconexion(20).degradar, isTrue);
      // Aun degradado, el retardo sigue siendo válido (sigue reintentando).
      expect(planReconexion(20).delaySeconds, 16);
    });
  });
}
