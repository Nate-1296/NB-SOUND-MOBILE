import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/security/secure_store.dart';
import '../../../data/db/database.dart';
import '../../remote_control/application/remote_controller.dart';
import '../../remote_control/data/remote_dtos.dart';
import 'player_controller.dart';

/// Destino de reproducción (Spotify Connect): este teléfono o el PC.
enum PlaybackTarget { local, remote }

class PlaybackTargetController extends Notifier<PlaybackTarget> {
  @override
  PlaybackTarget build() => PlaybackTarget.local;

  /// Cambia a control remoto si hay un PC emparejado. Devuelve false si no.
  /// Handoff: pausa el móvil y transfiere al PC la pista y posición actuales.
  Future<bool> usarRemoto() async {
    final PairedPc? pc = await ref.read(secureStoreProvider).readPairing();
    if (pc == null) {
      return false;
    }
    // Capturar lo que suena en el móvil antes de cambiar de destino.
    final PlayerState local = ref.read(playerControllerProvider);
    final int? pistaId = local.current?.id;
    final double posSeg = local.position.inMilliseconds / 1000.0;

    final RemoteController r = ref.read(remoteControllerProvider.notifier);
    r.conectar(pc);
    state = PlaybackTarget.remote;

    // Pausar el móvil y reproducir lo mismo en el PC (transferencia real).
    if (pistaId != null) {
      ref.read(playerControllerProvider.notifier).pausar();
      r.reproducirPista(pistaId, posicionSeg: posSeg);
    }
    return true;
  }

  void usarLocal() {
    ref.read(remoteControllerProvider.notifier).desconectar();
    state = PlaybackTarget.local;
  }
}

final NotifierProvider<PlaybackTargetController, PlaybackTarget>
    playbackTargetProvider =
    NotifierProvider<PlaybackTargetController, PlaybackTarget>(
  PlaybackTargetController.new,
);

/// Vista unificada de "lo que suena", sea local o remoto.
class NowPlaying {
  const NowPlaying({
    required this.target,
    required this.hasTrack,
    required this.title,
    required this.artist,
    required this.album,
    required this.coverPath,
    required this.playing,
    required this.progress,
    required this.position,
    required this.duration,
    required this.shuffle,
    required this.repeat,
  });

  factory NowPlaying.fromLocal(PlayerState s) {
    final bool has = s.hasTrack;
    return NowPlaying(
      target: PlaybackTarget.local,
      hasTrack: has,
      title: s.current?.titulo ?? '',
      artist: s.current?.artistaNombre ?? '',
      album: s.current?.albumTitulo ?? '',
      coverPath: s.current?.coverPath,
      playing: s.playing,
      progress: s.progress,
      position: s.position,
      duration: s.duration,
      shuffle: s.shuffle,
      repeat: s.repeat,
    );
  }

  factory NowPlaying.fromRemote(RemoteState s) {
    final RemotePistaDto? p = s.pista;
    return NowPlaying(
      target: PlaybackTarget.remote,
      hasTrack: p != null,
      title: p?.titulo ?? '',
      artist: p?.artista ?? '',
      album: p?.album ?? '',
      coverPath: p?.coverUrl,
      playing: s.estado.reproduciendo,
      progress: s.progress,
      position: Duration(seconds: s.estado.posicionSeg.round()),
      duration: Duration(seconds: (p?.duracionSeg ?? 0).round()),
      shuffle: s.estado.aleatorio,
      repeat: switch (s.estado.modoRepeticion) {
        'una' => RepeatMode.one,
        'todas' => RepeatMode.all,
        _ => RepeatMode.off,
      },
    );
  }

  final PlaybackTarget target;
  final bool hasTrack;
  final String title;
  final String artist;
  final String album;
  final String? coverPath;
  final bool playing;
  final double progress;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeat;

  bool get isRemote => target == PlaybackTarget.remote;
}

/// "Lo que suena" según el destino activo.
final Provider<NowPlaying> nowPlayingProvider = Provider<NowPlaying>((Ref ref) {
  if (ref.watch(playbackTargetProvider) == PlaybackTarget.remote) {
    return NowPlaying.fromRemote(ref.watch(remoteControllerProvider));
  }
  return NowPlaying.fromLocal(ref.watch(playerControllerProvider));
});

/// Plan de reproducción remota de una colección: qué pista se reproduce ahora en
/// el PC y qué pistas se encolan a continuación. Como el contrato del PC solo
/// ofrece `reproducir_pista` (1) y `encolar_pista` (1), una colección se manda
/// como reproducir [index] + encolar `index+1..fin` (las anteriores no se
/// encolan, igual que Spotify al tocar la pista i de un álbum). Pura y testeable.
({int play, List<int> next}) planColeccionRemota(List<int> ids, int index) {
  final int i = index < 0
      ? 0
      : (index >= ids.length ? ids.length - 1 : index);
  return (
    play: ids[i],
    next: <int>[for (int j = i + 1; j < ids.length; j++) ids[j]],
  );
}

/// Fachada de comandos que enruta al controlador local o remoto.
class PlaybackActions {
  PlaybackActions(this._ref);
  final Ref _ref;

  bool get _remote =>
      _ref.read(playbackTargetProvider) == PlaybackTarget.remote;

  RemoteController get _r => _ref.read(remoteControllerProvider.notifier);
  PlayerController get _l => _ref.read(playerControllerProvider.notifier);

  /// Reproduce una colección desde [index]. Punto único que decide destino: en
  /// local carga la cola en el teléfono; con Connect activo la manda al PC
  /// (reproducir + encolar el resto). Reemplaza los `playerController.reproducir`
  /// directos de los call-sites, que ignoraban el destino.
  Future<void> reproducirColeccion(List<Pista> pistas, int index) async {
    if (pistas.isEmpty) {
      return;
    }
    if (_remote) {
      final ({int play, List<int> next}) plan = planColeccionRemota(
        <int>[for (final Pista p in pistas) p.id],
        index,
      );
      _r.reproducirPista(plan.play);
      for (final int id in plan.next) {
        _r.encolarPista(id);
      }
      return;
    }
    await _l.reproducir(pistas, index);
  }

  /// Reproduce una colección desde el principio y la deja en aleatorio. Enruta al
  /// destino activo (en local activa el aleatorio global si estaba apagado; en
  /// remoto lo fuerza en el PC).
  Future<void> reproducirColeccionAleatorio(List<Pista> pistas) async {
    if (pistas.isEmpty) {
      return;
    }
    await reproducirColeccion(pistas, 0);
    if (_remote) {
      _r.setAleatorio(true);
    } else if (!_ref.read(playerControllerProvider).shuffle) {
      await _l.alternarAleatorio();
    }
  }

  /// Añade una colección entera a la cola del destino activo.
  Future<void> encolarColeccion(List<Pista> pistas) async {
    if (pistas.isEmpty) {
      return;
    }
    if (_remote) {
      for (final Pista p in pistas) {
        _r.encolarPista(p.id);
      }
      return;
    }
    await _l.encolarColeccion(pistas);
  }

  /// Reproduce una sola pista (listas sueltas, `comoColeccion:false`). En remoto
  /// la manda al PC; en local arranca una cola de una pista.
  Future<void> reproducirPistaUnica(Pista pista) async {
    if (_remote) {
      _r.reproducirPista(pista.id);
      return;
    }
    await _l.reproducirPista(pista);
  }

  void togglePlay() => _remote ? _r.playPause() : _l.alternarReproduccion();
  void next() => _remote ? _r.siguiente() : _l.siguiente();
  void prev() => _remote ? _r.anterior() : _l.anterior();
  void seekProgress(double p) =>
      _remote ? _r.buscarProgreso(p) : _l.buscar(p);
  void toggleShuffle() => _remote
      ? _r.setAleatorio(!_ref.read(remoteControllerProvider).estado.aleatorio)
      : _l.alternarAleatorio();
  void cycleRepeat() => _remote ? _r.cicloRepeticion() : _l.cicloRepeticion();
}

final Provider<PlaybackActions> playbackActionsProvider =
    Provider<PlaybackActions>((Ref ref) => PlaybackActions(ref));
