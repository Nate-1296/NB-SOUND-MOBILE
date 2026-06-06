import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../core/di/providers.dart';
import '../../../data/db/daos/downloads_dao.dart';
import '../../../data/db/daos/history_dao.dart';
import '../../../data/db/database.dart';
import '../../../core/security/secure_store.dart';
import '../../karaoke/application/karaoke_providers.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/data/download_repository.dart';
import '../../sync/application/remote_media_provider.dart';
import '../../sync/application/sync_controller.dart';
import 'nb_audio_handler.dart';

/// Modo de repetición (espejo del contrato WS: ninguno|una|todas).
enum RepeatMode { off, one, all }

/// Estado observable del reproductor local. El mismo contrato lo cumplirá el
/// controlador remoto (Spotify Connect) en la tanda de control remoto.
class PlayerState {
  const PlayerState({
    required this.queue,
    required this.index,
    required this.playing,
    required this.position,
    required this.duration,
    required this.shuffle,
    required this.repeat,
    this.karaoke = false,
  });

  factory PlayerState.initial() => const PlayerState(
        queue: <Pista>[],
        index: -1,
        playing: false,
        position: Duration.zero,
        duration: Duration.zero,
        shuffle: false,
        repeat: RepeatMode.off,
      );

  final List<Pista> queue;
  final int index;
  final bool playing;
  final Duration position;
  final Duration duration;
  final bool shuffle;
  final RepeatMode repeat;

  /// La pista actual suena en modo karaoke (instrumental). Aplica solo a la
  /// pista en curso; se resetea al cambiar de pista.
  final bool karaoke;

  Pista? get current =>
      (index >= 0 && index < queue.length) ? queue[index] : null;

  bool get hasTrack => current != null;

  /// Progreso normalizado 0..1.
  double get progress {
    final int ms = duration.inMilliseconds;
    if (ms <= 0) {
      return 0;
    }
    return (position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  PlayerState copyWith({
    List<Pista>? queue,
    int? index,
    bool? playing,
    Duration? position,
    Duration? duration,
    bool? shuffle,
    RepeatMode? repeat,
    bool? karaoke,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      karaoke: karaoke ?? this.karaoke,
    );
  }
}

/// Provider del handler de audio; se sobreescribe en `main` tras
/// `AudioService.init`.
final Provider<NbAudioHandler> audioHandlerProvider =
    Provider<NbAudioHandler>((Ref ref) {
  throw UnimplementedError(
    'audioHandlerProvider debe sobreescribirse en main() tras AudioService.init',
  );
});

class PlayerController extends Notifier<PlayerState> {
  late final NbAudioHandler _handler;
  late final HistoryDao _history;
  late final DownloadsDao _downloads;
  late final DownloadRepository _downloadRepo;
  int? _lastRecordedIndex;

  @override
  PlayerState build() {
    _handler = ref.watch(audioHandlerProvider);
    _history = ref.watch(historyDaoProvider);
    _downloads = ref.watch(downloadsDaoProvider);
    _downloadRepo = ref.watch(downloadRepositoryProvider);

    final List<StreamSubscription<Object?>> subs =
        <StreamSubscription<Object?>>[
      _handler.playbackState.listen(_onPlayback),
      _handler.positionStream.listen(_onPosition),
      _handler.durationStream.listen(_onDuration),
      _handler.shuffleStream.listen(_onShuffle),
      _handler.loopStream.listen(_onLoop),
    ];
    ref.onDispose(() {
      for (final StreamSubscription<Object?> s in subs) {
        s.cancel();
      }
    });

    return PlayerState.initial();
  }

  // ── Comandos ─────────────────────────────────────────────────────────────
  Future<void> reproducir(List<Pista> pistas, int index) async {
    // El handler resuelve las pistas `/api/...` (sincronizadas, no descargadas)
    // a streaming con el PC emparejado activo. Reproducción nueva = sin karaoke.
    _handler.remote = ref.read(remoteMediaProvider);
    _handler.karaokeId = null;
    // El estado conserva las pistas originales (UI); al handler se le pasan con
    // el audio resuelto al archivo local cuando está descargado.
    final List<Pista> fuentes = await _resolverFuentes(pistas);
    state = state.copyWith(queue: pistas, index: index, karaoke: false);
    _lastRecordedIndex = null;
    await _handler.loadQueue(fuentes, index);
    _registrarHistorial(index);
  }

  /// Alterna el modo karaoke de la pista en curso: reproduce el instrumental
  /// (`/stems`) por streaming conservando la posición, o vuelve al audio normal.
  /// Devuelve false si se pedía activar pero no hay karaoke disponible (sin PC o
  /// la pista no tiene stems) — la UI lo refleja.
  Future<bool> toggleKaraoke() async {
    final Pista? pista = state.current;
    if (pista == null) {
      return false;
    }
    final bool turningOn = !state.karaoke;
    final PairedPc? pc = ref.read(syncControllerProvider).pc;
    if (turningOn) {
      if (pc == null) {
        return false;
      }
      final bool ok =
          await ref.read(stemsRepositoryProvider).disponible(pc, pista.id);
      if (!ok) {
        return false;
      }
    }
    final Duration pos = state.position;
    _handler.remote = ref.read(remoteMediaProvider);
    _handler.karaokeId = turningOn ? pista.id : null;
    final List<Pista> fuentes = await _resolverFuentes(state.queue);
    await _handler.loadQueue(fuentes, state.index, initialPosition: pos);
    state = state.copyWith(karaoke: turningOn);
    return true;
  }

  /// Sustituye `audioPath` por el archivo local en las pistas ya descargadas.
  Future<List<Pista>> _resolverFuentes(List<Pista> pistas) async {
    final Set<int> descargadas = await _downloads.watchDescargadas().first;
    if (descargadas.isEmpty) {
      return pistas;
    }
    return <Pista>[
      for (final Pista p in pistas)
        if (descargadas.contains(p.id))
          p.copyWith(audioPath: Value(_downloadRepo.fileFor(p.id).path))
        else
          p,
    ];
  }

  Future<void> reproducirPista(Pista pista) => reproducir(<Pista>[pista], 0);

  void alternarReproduccion() =>
      state.playing ? _handler.pause() : _handler.play();

  /// Pausa la reproducción local (usado en el handoff al PC).
  void pausar() => _handler.pause();

  void siguiente() => _handler.skipToNext();

  void anterior() {
    if (state.position.inSeconds > 3) {
      _handler.seek(Duration.zero);
    } else {
      _handler.skipToPrevious();
    }
  }

  void irACola(int index) => _handler.skipToQueueItem(index);

  void buscar(double progress) {
    final int ms = (state.duration.inMilliseconds * progress).round();
    _handler.seek(Duration(milliseconds: ms));
  }

  void alternarAleatorio() => _handler.setShuffleMode(
        state.shuffle
            ? AudioServiceShuffleMode.none
            : AudioServiceShuffleMode.all,
      );

  void cicloRepeticion() {
    final RepeatMode next = switch (state.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _handler.setRepeatMode(switch (next) {
      RepeatMode.off => AudioServiceRepeatMode.none,
      RepeatMode.one => AudioServiceRepeatMode.one,
      RepeatMode.all => AudioServiceRepeatMode.all,
    });
  }

  // ── Reacción a los streams del handler ────────────────────────────────────
  void _onPlayback(PlaybackState ps) {
    final int idx = ps.queueIndex ?? state.index;
    final bool cambioPista =
        idx >= 0 && idx < state.queue.length && idx != state.index;
    if (cambioPista) {
      _registrarHistorial(idx);
    }
    // El karaoke aplica solo a la pista en curso: al cambiar de pista se resetea
    // (la cola ya trae las demás como audio normal).
    if (cambioPista && state.karaoke) {
      _handler.karaokeId = null;
      state = state.copyWith(playing: ps.playing, index: idx, karaoke: false);
      return;
    }
    state = state.copyWith(playing: ps.playing, index: idx);
  }

  void _onPosition(Duration p) => state = state.copyWith(position: p);

  void _onDuration(Duration? d) =>
      state = state.copyWith(duration: d ?? Duration.zero);

  void _onShuffle(bool v) => state = state.copyWith(shuffle: v);

  void _onLoop(LoopMode mode) => state = state.copyWith(
        repeat: switch (mode) {
          LoopMode.off => RepeatMode.off,
          LoopMode.one => RepeatMode.one,
          LoopMode.all => RepeatMode.all,
        },
      );

  void _registrarHistorial(int index) {
    if (_lastRecordedIndex == index) {
      return;
    }
    if (index < 0 || index >= state.queue.length) {
      return;
    }
    _lastRecordedIndex = index;
    final Pista p = state.queue[index];
    unawaited(_history.registrarReproduccion(p.id));
  }
}

final NotifierProvider<PlayerController, PlayerState> playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
