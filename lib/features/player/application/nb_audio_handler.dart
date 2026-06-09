import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../../data/db/database.dart';
import '../../../shared/util/media_source.dart';

/// Handler de `audio_service` que envuelve un [AudioPlayer] de `just_audio`.
/// Gestiona la cola, la reproducción en background y los controles del sistema
/// (notificación / pantalla de bloqueo). No depende de la BD: el registro de
/// historial vive en el controlador Riverpod.
///
/// En modo [preview] (escritorio/web, donde just_audio/audio_service no tienen
/// implementación) no se crea el [AudioPlayer]: la cola y el `mediaItem` se
/// actualizan para que la UI se pueda previsualizar, pero no hay audio real.
class NbAudioHandler extends BaseAudioHandler with SeekHandler {
  NbAudioHandler({this.preview = false}) {
    if (preview) {
      return;
    }
    final AudioPlayer player = AudioPlayer();
    _player = player;
    player.playbackEventStream.listen(_broadcastState);
    player.currentIndexStream.listen((int? index) {
      final List<MediaItem> q = queue.value;
      if (index != null && index >= 0 && index < q.length) {
        mediaItem.add(q[index]);
      }
    });
    player.processingStateStream.listen((ProcessingState s) {
      if (s == ProcessingState.completed) {
        _broadcastState(player.playbackEvent);
      }
    });
  }

  final bool preview;
  AudioPlayer? _player;

  /// PC emparejado activo (para resolver pistas en streaming `/api/...`). Lo fija
  /// el [PlayerController] antes de cargar la cola; null si no hay PC.
  RemoteMedia? remote;

  /// Id de la pista que debe sonar en modo karaoke (instrumental `/stems`), o
  /// null. Lo fija el [PlayerController] al alternar karaoke antes de recargar.
  int? karaokeId;

  /// Resuelve el archivo local del instrumental de una pista (lo fija el
  /// [PlayerController] desde `OfflineStore`). Si existe se reproduce el karaoke
  /// offline; si no, se hace streaming de `/stems`.
  File Function(int pistaId)? stemFileFor;

  Stream<Duration> get positionStream =>
      _player?.positionStream ?? const Stream<Duration>.empty();
  Stream<Duration?> get durationStream =>
      _player?.durationStream ?? const Stream<Duration?>.empty();
  Stream<bool> get shuffleStream =>
      _player?.shuffleModeEnabledStream ?? const Stream<bool>.empty();
  Stream<LoopMode> get loopStream =>
      _player?.loopModeStream ?? const Stream<LoopMode>.empty();

  /// Carga una cola de pistas y empieza a reproducir desde [initialIndex].
  /// [initialPosition] permite reanudar en una posición concreta (p. ej. al
  /// alternar karaoke sin perder el punto de la canción).
  Future<void> loadQueue(
    List<Pista> pistas,
    int initialIndex, {
    Duration? initialPosition,
  }) async {
    final List<MediaItem> items =
        pistas.map(_toMediaItem).toList(growable: false);
    queue.add(items);
    if (initialIndex >= 0 && initialIndex < items.length) {
      mediaItem.add(items[initialIndex]);
    }
    final AudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    await player.setAudioSources(
      pistas.map(_toAudioSource).toList(growable: false),
      initialIndex: initialIndex < 0 ? 0 : initialIndex,
      initialPosition: initialPosition,
    );
    await player.play();
  }

  MediaItem _toMediaItem(Pista p) {
    final String? cover = p.coverPath;
    Uri? artUri;
    if (cover != null && cover.isNotEmpty && cover.startsWith('http')) {
      // Solo portadas http absolutas (seed). Las `/api/...` requieren auth y la
      // notificación del sistema no la envía: se omiten para no fallar (401).
      artUri = Uri.tryParse(cover);
    }
    return MediaItem(
      id: p.id.toString(),
      title: p.titulo,
      artist: p.artistaNombre,
      album: p.albumTitulo,
      duration: Duration(milliseconds: (p.duracionSeg * 1000).round()),
      artUri: artUri,
      extras: <String, dynamic>{'pistaId': p.id, 'coverPath': cover},
    );
  }

  AudioSource _toAudioSource(Pista p) {
    // Resolución de la fuente: karaoke (instrumental `/stems`) · descargada
    // (file) · sincronizada del PC (`/api/...` → streaming) · seed (asset, solo
    // en builds de desarrollo con NB_SEED; la media de ejemplo no se empaqueta).
    final MediaItem tag = _toMediaItem(p);
    final RemoteMedia? r = remote;
    if (p.id == karaokeId) {
      // Karaoke: instrumental local si está descargado (offline); si no, streaming
      // de `/stems` con el PC. Si no hay ni local ni PC, cae al audio normal.
      final File? local = stemFileFor?.call(p.id);
      if (local != null && local.existsSync()) {
        return AudioSource.file(local.path, tag: tag);
      }
      if (r != null) {
        return AudioSource.uri(
          Uri.parse(r.urlFor('/api/v1/track/${p.id}/stems')),
          headers: r.authHeaders,
          tag: tag,
        );
      }
    }
    final String? path = p.audioPath;
    if (path != null && path.startsWith('assets/')) {
      return AudioSource.asset(path, tag: tag);
    }
    if (path != null && path.startsWith('http')) {
      return AudioSource.uri(Uri.parse(path), tag: tag);
    }
    if (path == null || path.startsWith('/api/')) {
      // Sincronizada del PC: streaming con auth. Sin ruta explícita se deriva
      // del id. Sin PC no es reproducible; se devuelve la URI relativa para que
      // just_audio falle de forma controlada (error de reproducción), sin
      // recurrir a un asset de demo.
      final String rel = path ?? '/api/v1/track/${p.id}/audio';
      return r != null
          ? AudioSource.uri(Uri.parse(r.urlFor(rel)),
              headers: r.authHeaders, tag: tag)
          : AudioSource.uri(Uri.parse(rel), tag: tag);
    }
    // Ruta de archivo local de una descarga (la fija el PlayerController).
    return AudioSource.file(path, tag: tag);
  }

  // ── Controles (móvil + sistema) ─────────────────────────────────────────
  @override
  Future<void> play() async => _player?.play();

  @override
  Future<void> pause() async => _player?.pause();

  @override
  Future<void> seek(Duration position) async => _player?.seek(position);

  @override
  Future<void> skipToNext() async => _player?.seekToNext();

  @override
  Future<void> skipToPrevious() async => _player?.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) async =>
      _player?.seek(Duration.zero, index: index);

  @override
  Future<void> stop() async {
    await _player?.stop();
    await super.stop();
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async =>
      _player?.setShuffleModeEnabled(shuffleMode == AudioServiceShuffleMode.all);

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    final AudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await player.setLoopMode(LoopMode.off);
      case AudioServiceRepeatMode.one:
        await player.setLoopMode(LoopMode.one);
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await player.setLoopMode(LoopMode.all);
    }
  }

  Future<void> dispose() async => _player?.dispose();

  void _broadcastState(PlaybackEvent event) {
    final AudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    final bool playing = player.playing;
    playbackState.add(
      playbackState.value.copyWith(
        controls: <MediaControl>[
          MediaControl.skipToPrevious,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        systemActions: const <MediaAction>{
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const <int>[0, 1, 2],
        processingState: _mapProcessingState(player.processingState),
        playing: playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: event.currentIndex,
      ),
    );
  }

  static AudioProcessingState _mapProcessingState(ProcessingState s) {
    switch (s) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }
}
