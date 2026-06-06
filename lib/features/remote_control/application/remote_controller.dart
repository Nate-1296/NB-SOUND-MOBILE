import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/network/tls_pinning.dart';
import '../../../core/security/secure_store.dart';
import '../data/remote_dtos.dart';

/// Fábrica del canal WS (inyectable; los tests conectan a un servidor local).
typedef WsConnect = WebSocketChannel Function(
  Uri url, {
  String? fingerprint,
  String? token,
});

WebSocketChannel _defaultConnect(
  Uri url, {
  String? fingerprint,
  String? token,
}) {
  return IOWebSocketChannel.connect(
    url,
    customClient: pinnedHttpClient(fingerprint),
    headers: <String, dynamic>{
      if (token != null) 'Authorization': 'Bearer $token',
    },
  );
}

enum RemoteConnection { disconnected, connecting, connected, error }

/// Estado en vivo del reproductor del PC (espejo del frame `estado`).
class RemoteState {
  const RemoteState({
    this.connection = RemoteConnection.disconnected,
    this.estado = const RemoteEstadoDto(),
    this.cola = const <RemotePistaDto>[],
  });

  final RemoteConnection connection;
  final RemoteEstadoDto estado;
  final List<RemotePistaDto> cola;

  bool get conectado => connection == RemoteConnection.connected;
  RemotePistaDto? get pista => estado.pista;

  double get progress {
    final double dur = estado.pista?.duracionSeg ?? 0;
    if (dur <= 0) {
      return 0;
    }
    return (estado.posicionSeg / dur).clamp(0.0, 1.0);
  }

  RemoteState copyWith({
    RemoteConnection? connection,
    RemoteEstadoDto? estado,
    List<RemotePistaDto>? cola,
  }) =>
      RemoteState(
        connection: connection ?? this.connection,
        estado: estado ?? this.estado,
        cola: cola ?? this.cola,
      );
}

/// Cliente del WebSocket `/api/v1/control` (docs/pc-contract.md §5): refleja el
/// estado que publica el PC y envía comandos; reconexión con backoff.
class RemoteController extends Notifier<RemoteState> {
  RemoteController({WsConnect? connect}) : _connect = connect ?? _defaultConnect;

  final WsConnect _connect;
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _reconnect;
  int _attempt = 0;
  bool _wantConnected = false;
  PairedPc? _pc;

  @override
  RemoteState build() {
    ref.onDispose(_teardown);
    return const RemoteState();
  }

  /// Conecta al PC [pc] (idempotente).
  void conectar(PairedPc pc) {
    _pc = pc;
    _wantConnected = true;
    _attempt = 0;
    _open();
  }

  void desconectar() {
    _wantConnected = false;
    _teardown();
    state = const RemoteState();
  }

  // ── Comandos (docs §5.2) ─────────────────────────────────────────────────
  void playPause() => _comando('play_pause');
  void siguiente() => _comando('next');
  void anterior() => _comando('prev');
  void detener() => _comando('stop');
  void buscarSeg(double posicionSeg) =>
      _comando('seek', <String, dynamic>{'posicion_seg': posicionSeg});
  void setVolumen(int volumen) =>
      _comando('set_volume', <String, dynamic>{'volumen': volumen});
  void reproducirIndice(int indice) =>
      _comando('play_index', <String, dynamic>{'indice': indice});
  void setRepeticion(String modo) =>
      _comando('repeat', <String, dynamic>{'modo': modo});
  void setAleatorio(bool activo) =>
      _comando('shuffle', <String, dynamic>{'activo': activo});
  void pedirCola() => _comando('queue');

  /// Handoff: reproducir en el PC la pista [pistaId] de la biblioteca, saltando
  /// a [posicionSeg] (transferir lo que sonaba en el móvil).
  void reproducirPista(int pistaId, {double posicionSeg = 0}) =>
      _comando('reproducir_pista', <String, dynamic>{
        'pista_id': pistaId,
        'posicion_seg': posicionSeg,
      });

  /// Encolar en el PC la pista [pistaId] desde el móvil.
  void encolarPista(int pistaId) =>
      _comando('encolar_pista', <String, dynamic>{'pista_id': pistaId});

  /// Busca por progreso normalizado 0..1.
  void buscarProgreso(double progreso) {
    final double dur = state.estado.pista?.duracionSeg ?? 0;
    buscarSeg(dur * progreso.clamp(0.0, 1.0));
  }

  void cicloRepeticion() {
    const List<String> modos = <String>['ninguno', 'todas', 'una'];
    final int i = modos.indexOf(state.estado.modoRepeticion);
    setRepeticion(modos[(i + 1) % modos.length]);
  }

  // ── Interno ──────────────────────────────────────────────────────────────
  void _open() {
    final PairedPc? pc = _pc;
    if (pc == null || !_wantConnected) {
      return;
    }
    _teardownChannel();
    state = state.copyWith(connection: RemoteConnection.connecting);
    try {
      final WebSocketChannel ch = _connect(
        Uri.parse('${pc.wsBaseUrl}/api/v1/control'),
        fingerprint: pc.fingerprint,
        token: pc.deviceToken,
      );
      _channel = ch;
      _sub = ch.stream.listen(
        _onMessage,
        onError: (_) => _onClosed(),
        onDone: _onClosed,
        cancelOnError: true,
      );
      state = state.copyWith(connection: RemoteConnection.connected);
    } catch (_) {
      _onClosed();
    }
  }

  void _onMessage(dynamic raw) {
    if (raw is! String) {
      return;
    }
    final Object? decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }
    switch (decoded['tipo']) {
      case 'estado':
        state = state.copyWith(
          connection: RemoteConnection.connected,
          estado: RemoteEstadoDto.fromJson(decoded),
        );
      case 'cola':
        final RemoteColaDto cola = RemoteColaDto.fromJson(decoded);
        state = state.copyWith(cola: cola.items);
      default:
        break; // ack / error: el estado autoritativo llega en 'estado'
    }
  }

  void _onClosed() {
    _attempt += 1;
    if (!_wantConnected) {
      state = state.copyWith(connection: RemoteConnection.disconnected);
      return;
    }
    state = state.copyWith(connection: RemoteConnection.connecting);
    final int seconds = (1 << (_attempt - 1)).clamp(1, 16);
    _reconnect?.cancel();
    _reconnect = Timer(Duration(seconds: seconds), _open);
  }

  void _comando(String accion, [Map<String, dynamic>? args]) {
    final WebSocketChannel? ch = _channel;
    if (ch == null) {
      return;
    }
    ch.sink.add(jsonEncode(<String, dynamic>{
      'tipo': 'comando',
      'accion': accion,
      ...?args,
    }));
  }

  void _teardownChannel() {
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
  }

  void _teardown() {
    _reconnect?.cancel();
    _reconnect = null;
    _teardownChannel();
  }
}

final NotifierProvider<RemoteController, RemoteState> remoteControllerProvider =
    NotifierProvider<RemoteController, RemoteState>(RemoteController.new);
