import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;

import '../../../core/di/providers.dart';
import '../../../data/db/daos/catalog_dao.dart';
import '../../../data/db/daos/downloads_dao.dart';
import '../../../data/db/daos/history_dao.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../data/db/database.dart';
import '../../../core/security/secure_store.dart';
import '../../karaoke/application/karaoke_providers.dart';
import '../../library/application/library_providers.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/data/download_repository.dart';
import '../../offline/data/offline_store.dart';
import '../../sync/application/remote_media_provider.dart';
import '../../sync/application/sync_controller.dart';
import 'nb_audio_handler.dart';

/// Modo de repetición (espejo del contrato WS: ninguno|una|todas).
enum RepeatMode { off, one, all }

/// Orden efectivo de reproducción para [length] elementos: usa [order] si es una
/// permutación válida (misma longitud); si no (vacío o desincronizado), cae al
/// orden natural `[0, 1, …, length)`. Función pura (testeable sin reproductor).
List<int> ordenEfectivo(List<int> order, int length) {
  if (order.length == length) {
    return order;
  }
  return <int>[for (int i = 0; i < length; i++) i];
}

/// Nuevo índice de la pista en curso tras mover un elemento de [oldIndex] a
/// [newIndex] (semántica `removeAt`+`insert`). Pura y testeable.
int indiceTrasMover(int current, int oldIndex, int newIndex) {
  if (current == oldIndex) {
    return newIndex;
  }
  int cur = current;
  if (oldIndex < cur) {
    cur -= 1;
  }
  if (newIndex <= cur) {
    cur += 1;
  }
  return cur;
}

/// Nuevo índice de la pista en curso tras quitar el elemento en [index]. Pura.
int indiceTrasQuitar(int current, int index) =>
    index < current ? current - 1 : current;

/// Mapea una cola remota del PC (sus [ids] en orden + el [indice] en curso) a
/// pistas de la biblioteca local para traerla al teléfono (Spotify Connect). Las
/// ids que no existan en el catálogo (no sincronizadas) se omiten; el índice se
/// reubica sobre la lista resultante apuntando a la pista en curso, o —si esa no
/// existe localmente— a la siguiente disponible. Pura y testeable (sin BD ni
/// reproductor).
({List<Pista> pistas, int index}) mapearColaRemota(
  List<int> ids,
  int indice,
  Map<int, Pista> porId,
) {
  final List<Pista> pistas = <Pista>[];
  int nuevoIndice = -1;
  for (int i = 0; i < ids.length; i++) {
    // Posición que ocuparía la pista en curso (o la siguiente, si esta falta).
    if (i == indice) {
      nuevoIndice = pistas.length;
    }
    final Pista? p = porId[ids[i]];
    if (p != null) {
      pistas.add(p);
    }
  }
  if (pistas.isEmpty) {
    return (pistas: pistas, index: 0);
  }
  if (nuevoIndice < 0 || nuevoIndice >= pistas.length) {
    nuevoIndice = pistas.length - 1;
  }
  return (pistas: pistas, index: nuevoIndice);
}

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
    this.order = const <int>[],
    this.karaoke = false,
    this.velocidad = 1.0,
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

  /// Orden efectivo de reproducción (índices de [queue] en el orden en que
  /// sonarán). Vacío = orden natural. Con aleatorio activo, refleja la baraja
  /// real, de modo que la Cola muestre qué sigue de verdad.
  final List<int> order;

  /// Cola en el orden efectivo de reproducción. Si [order] no es válido (vacío o
  /// desincronizado de [queue]), cae al orden natural.
  List<Pista> get colaOrdenada =>
      <Pista>[for (final int i in ordenEfectivo(order, queue.length)) queue[i]];

  /// La pista actual suena en modo karaoke (instrumental). Aplica solo a la
  /// pista en curso; se resetea al cambiar de pista.
  final bool karaoke;

  /// Velocidad de reproducción (1.0 = normal).
  final double velocidad;

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
    List<int>? order,
    bool? karaoke,
    double? velocidad,
  }) {
    return PlayerState(
      queue: queue ?? this.queue,
      index: index ?? this.index,
      playing: playing ?? this.playing,
      position: position ?? this.position,
      duration: duration ?? this.duration,
      shuffle: shuffle ?? this.shuffle,
      repeat: repeat ?? this.repeat,
      order: order ?? this.order,
      karaoke: karaoke ?? this.karaoke,
      velocidad: velocidad ?? this.velocidad,
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

/// Aleatorio inicial (preferencia persistida). Se sobreescribe en `main()` tras
/// leer la BD; por defecto, desactivado. Igual patrón que `initialThemeProvider`.
final Provider<bool> initialShuffleProvider = Provider<bool>((Ref ref) => false);

/// Repetición inicial (preferencia persistida). Se sobreescribe en `main()`.
final Provider<RepeatMode> initialRepeatProvider =
    Provider<RepeatMode>((Ref ref) => RepeatMode.off);

class PlayerController extends Notifier<PlayerState> {
  late final NbAudioHandler _handler;
  late final HistoryDao _history;
  late final DownloadsDao _downloads;
  late final DownloadRepository _downloadRepo;
  late final OfflineStore _store;
  late final CatalogDao _catalog;
  int? _lastRecordedIndex;
  bool _autoplayCargando = false;

  @override
  PlayerState build() {
    _handler = ref.watch(audioHandlerProvider);
    _history = ref.watch(historyDaoProvider);
    _downloads = ref.watch(downloadsDaoProvider);
    _downloadRepo = ref.watch(downloadRepositoryProvider);
    _store = ref.read(offlineStoreProvider);
    _catalog = ref.read(catalogDaoProvider);
    // Permite al handler resolver el instrumental de karaoke descargado (offline).
    _handler.stemFileFor = _store.stemFile;
    // Portada local para la notificación del sistema: la auth de las portadas
    // `/api/...` no llega al sistema, así que solo sirve un archivo local.
    _handler.localCoverFor = (int albumId) {
      final File f = _store.coverFile(albumId);
      return f.existsSync() ? f : null;
    };
    // Botón de favorito en la notificación/lockscreen: estado y toggle de la pista
    // en curso. Se refresca cuando cambian los favoritos (o la pista).
    _handler.esFavoritaActual = () {
      final int? id = state.current?.id;
      if (id == null) {
        return false;
      }
      return (ref.read(favoritasIdsProvider).value ?? const <int>{}).contains(id);
    };
    _handler.onToggleFavorita = () {
      final int? id = state.current?.id;
      if (id == null) {
        return;
      }
      final bool esFav =
          (ref.read(favoritasIdsProvider).value ?? const <int>{}).contains(id);
      ref.read(favoritesDaoProvider).setFavorita(id, !esFav);
    };
    ref.listen<AsyncValue<Set<int>>>(
      favoritasIdsProvider,
      (_, _) => _handler.refreshControls(),
    );

    final List<StreamSubscription<Object?>> subs =
        <StreamSubscription<Object?>>[
      _handler.playbackState.listen(_onPlayback),
      _handler.positionStream.listen(_onPosition),
      _handler.durationStream.listen(_onDuration),
      _handler.shuffleStream.listen(_onShuffle),
      _handler.loopStream.listen(_onLoop),
      _handler.effectiveOrderStream.listen(_onOrder),
    ];
    ref.onDispose(() {
      for (final StreamSubscription<Object?> s in subs) {
        s.cancel();
      }
    });

    // Estado global de aleatorio/repetición (persistido, sobrevive reinicios y
    // aplica a toda reproducción, no por colección). Se fija en el handler ahora
    // (son flags de player, válidos aun sin cola) y se refleja en el estado inicial.
    final bool shuffle0 = ref.read(initialShuffleProvider);
    final RepeatMode repeat0 = ref.read(initialRepeatProvider);
    _handler.setShuffleMode(
      shuffle0 ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    _handler.setRepeatMode(_repeatToService(repeat0));

    // Restaura "lo que sonaba" (cola + índice + posición) en pausa, como Spotify.
    // No bloquea el primer estado; se aplica cuando el catálogo resuelve las ids.
    Future<void>(_restaurarSesion);

    return PlayerState.initial().copyWith(shuffle: shuffle0, repeat: repeat0);
  }

  static AudioServiceRepeatMode _repeatToService(RepeatMode m) => switch (m) {
        RepeatMode.off => AudioServiceRepeatMode.none,
        RepeatMode.one => AudioServiceRepeatMode.one,
        RepeatMode.all => AudioServiceRepeatMode.all,
      };

  void _persistir(String clave, String valor) =>
      ref.read(syncStateDaoProvider).setValor(clave, valor);

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
    guardarSesion();
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
      // Disponible si el instrumental está descargado (offline) o, en su defecto,
      // si el PC lo ofrece por streaming.
      final bool localOk = await _downloads.tieneStems(pista.id);
      if (!localOk) {
        if (pc == null) {
          return false;
        }
        final bool ok =
            await ref.read(stemsRepositoryProvider).disponible(pc, pista.id);
        if (!ok) {
          return false;
        }
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

  /// Traspaso desde el PC (Spotify Connect): reproduce localmente la pista
  /// [pistaId] que sonaba en el PC, arrancando en [posicionSeg] y respetando si
  /// estaba [reproducir]ndo o en pausa. Resuelve la id contra el catálogo (a
  /// streaming desde el PC o al archivo descargado); si la pista no existe en la
  /// biblioteca del teléfono, no hace nada (no hay nada que traspasar).
  Future<void> reproducirIdRemota(
    int pistaId, {
    double posicionSeg = 0,
    bool reproducir = true,
  }) async {
    final Map<int, Pista> porId = await _catalog.getPistasPorIds(<int>[pistaId]);
    final Pista? pista = porId[pistaId];
    if (pista == null) {
      return;
    }
    _handler.remote = ref.read(remoteMediaProvider);
    _handler.karaokeId = null;
    final List<Pista> fuentes = await _resolverFuentes(<Pista>[pista]);
    state = state.copyWith(queue: <Pista>[pista], index: 0, karaoke: false);
    _lastRecordedIndex = null;
    await _handler.loadQueue(
      fuentes,
      0,
      initialPosition:
          Duration(milliseconds: (posicionSeg * 1000).round().clamp(0, 1 << 31)),
      autoPlay: reproducir,
    );
    _registrarHistorial(0);
    guardarSesion();
  }

  /// Traspaso de la COLA del PC al reproductor local (Spotify Connect): mapea
  /// [ids] (la cola del PC, en orden) a pistas de la biblioteca, reubica el
  /// [indice] en curso y reproduce desde ahí en [posicionSeg] respetando
  /// [reproducir]. Las pistas que no existan localmente se omiten; si ninguna
  /// existe, no hace nada (no había nada que traer). Reemplaza el traspaso de una
  /// sola pista para que la cola entera persista al volver al teléfono.
  Future<void> reproducirColaRemota(
    List<int> ids,
    int indice, {
    double posicionSeg = 0,
    bool reproducir = true,
  }) async {
    if (ids.isEmpty) {
      return;
    }
    final Map<int, Pista> porId = await _catalog.getPistasPorIds(ids);
    final ({List<Pista> pistas, int index}) m =
        mapearColaRemota(ids, indice, porId);
    if (m.pistas.isEmpty) {
      return;
    }
    _handler.remote = ref.read(remoteMediaProvider);
    _handler.karaokeId = null;
    final List<Pista> fuentes = await _resolverFuentes(m.pistas);
    state = state.copyWith(queue: m.pistas, index: m.index, karaoke: false);
    _lastRecordedIndex = null;
    await _handler.loadQueue(
      fuentes,
      m.index,
      initialPosition: Duration(
          milliseconds: (posicionSeg * 1000).round().clamp(0, 1 << 31)),
      autoPlay: reproducir,
    );
    _registrarHistorial(m.index);
    guardarSesion();
  }

  // ── Manipulación de cola (estilo Spotify) ────────────────────────────────
  /// Añade [pista] al final de la cola. Si no hay nada sonando, arranca esa pista.
  Future<void> addToQueue(Pista pista) async {
    if (state.queue.isEmpty) {
      await reproducir(<Pista>[pista], 0);
      return;
    }
    _handler.remote = ref.read(remoteMediaProvider);
    final List<Pista> resueltas = await _resolverFuentes(<Pista>[pista]);
    await _handler.addToQueueEnd(resueltas.first);
    state = state.copyWith(queue: <Pista>[...state.queue, pista]);
    guardarSesion();
  }

  /// Añade una colección entera al final de la cola. Si no hay nada sonando,
  /// arranca la colección. Encola en **un solo lote** (no N operaciones), para
  /// que encolar un álbum/artista no bloquee la UI.
  Future<void> encolarColeccion(List<Pista> pistas) async {
    if (pistas.isEmpty) {
      return;
    }
    if (state.queue.isEmpty) {
      await reproducir(pistas, 0);
      return;
    }
    _handler.remote = ref.read(remoteMediaProvider);
    final List<Pista> resueltas = await _resolverFuentes(pistas);
    await _handler.addAllToQueueEnd(resueltas);
    state = state.copyWith(queue: <Pista>[...state.queue, ...pistas]);
    guardarSesion();
  }

  /// Inserta [pista] justo después de la pista en curso ("reproducir a
  /// continuación"). Si no hay nada sonando, arranca esa pista.
  Future<void> reproducirACont(Pista pista) async {
    if (state.queue.isEmpty) {
      await reproducir(<Pista>[pista], 0);
      return;
    }
    _handler.remote = ref.read(remoteMediaProvider);
    final List<Pista> resueltas = await _resolverFuentes(<Pista>[pista]);
    final int idx =
        ((state.index < 0 ? -1 : state.index) + 1).clamp(0, state.queue.length);
    await _handler.insertAt(idx, resueltas.first);
    final List<Pista> q = List<Pista>.of(state.queue)..insert(idx, pista);
    // La pista en curso no se desplaza (idx > index): el índice se mantiene.
    state = state.copyWith(queue: q);
    guardarSesion();
  }

  /// Quita de la cola la pista en [index] (no se permite quitar la pista en
  /// curso, igual que Spotify).
  Future<void> quitarDeCola(int index) async {
    if (index < 0 || index >= state.queue.length || index == state.index) {
      return;
    }
    await _handler.removeFromQueue(index);
    final List<Pista> q = List<Pista>.of(state.queue)..removeAt(index);
    state =
        state.copyWith(queue: q, index: indiceTrasQuitar(state.index, index));
    guardarSesion();
  }

  /// Reordena la cola moviendo la pista de [oldIndex] a [newIndex] (semántica
  /// `removeAt`+`insert`, como `ReorderableListView.onReorderItem`).
  Future<void> moverEnCola(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= state.queue.length || oldIndex == newIndex) {
      return;
    }
    final List<Pista> q = List<Pista>.of(state.queue);
    final Pista moved = q.removeAt(oldIndex);
    final int dest = newIndex.clamp(0, q.length);
    q.insert(dest, moved);
    await _handler.moveInQueue(oldIndex, dest);
    state = state.copyWith(
      queue: q,
      index: indiceTrasMover(state.index, oldIndex, dest),
    );
    guardarSesion();
  }

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

  /// Salta a una posición concreta (p. ej. al tocar una línea de la letra).
  void buscarPosicion(Duration pos) =>
      _handler.seek(pos < Duration.zero ? Duration.zero : pos);

  /// Fija la velocidad de reproducción (0.5–2.0).
  Future<void> setVelocidad(double v) async {
    final double speed = v.clamp(0.25, 3.0);
    await _handler.setSpeed(speed);
    state = state.copyWith(velocidad: speed);
  }

  /// Vacía la cola dejando solo la pista en curso ("borrar cola" de Spotify):
  /// conserva la posición y el estado de reproducción.
  Future<void> limpiarCola() async {
    final Pista? actual = state.current;
    if (actual == null || state.queue.length <= 1) {
      return;
    }
    final Duration pos = state.position;
    final bool sonaba = state.playing;
    _handler.remote = ref.read(remoteMediaProvider);
    final List<Pista> fuentes = await _resolverFuentes(<Pista>[actual]);
    state = state.copyWith(queue: <Pista>[actual], index: 0);
    _lastRecordedIndex = 0;
    await _handler.loadQueue(fuentes, 0,
        initialPosition: pos, autoPlay: sonaba);
    guardarSesion();
  }

  Future<void> alternarAleatorio() async {
    final bool next = !state.shuffle;
    // Al ACTIVAR, regenera una baraja nueva (si no, just_audio reutiliza el mismo
    // orden barajado y "aleatorio" quedaba como una segunda cola fija). La pista en
    // curso se conserva como inicio de la nueva baraja.
    if (next) {
      await _handler.reshuffle();
    }
    await _handler.setShuffleMode(
      next ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none,
    );
    _persistir(SyncStateDao.kAleatorio, next ? '1' : '0');
  }

  void cicloRepeticion() {
    final RepeatMode next = switch (state.repeat) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    _handler.setRepeatMode(_repeatToService(next));
    _persistir(SyncStateDao.kRepeticion, next.name);
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
    } else {
      state = state.copyWith(playing: ps.playing, index: idx);
    }
    if (cambioPista) {
      guardarSesion();
      _quizaAutoplay(idx);
      _handler.refreshControls();
    }
  }

  /// Autoplay: al llegar a la última pista de la cola sin repetición, la extiende
  /// con "radio" local (temas relacionados) para no quedarse en silencio.
  void _quizaAutoplay(int idx) {
    if (state.repeat == RepeatMode.off && idx >= state.queue.length - 1) {
      unawaited(_extenderAutoplay());
    }
  }

  Future<void> _extenderAutoplay() async {
    if (_autoplayCargando) {
      return;
    }
    final Pista? semilla = state.current;
    if (semilla == null) {
      return;
    }
    final List<Pista> catalogo =
        ref.read(pistasProvider).value ?? const <Pista>[];
    if (catalogo.length <= state.queue.length) {
      return;
    }
    _autoplayCargando = true;
    try {
      final Set<int> excluir = <int>{for (final Pista p in state.queue) p.id};
      final List<Pista> extra = generarAutoplay(
        semilla: semilla,
        catalogo: catalogo,
        excluir: excluir,
      );
      // Encola la tanda de "radio" en un solo lote (no pista a pista).
      await encolarColeccion(extra);
    } finally {
      _autoplayCargando = false;
    }
  }

  void _onPosition(Duration p) => state = state.copyWith(position: p);

  void _onDuration(Duration? d) =>
      state = state.copyWith(duration: d ?? Duration.zero);

  void _onShuffle(bool v) => state = state.copyWith(shuffle: v);

  void _onOrder(List<int> o) => state = state.copyWith(order: o);

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
    unawaited(_ensureArtwork(p));
  }

  /// Asegura una portada local para la pista en curso y la fija en la notificación
  /// del sistema. Si está descargada, se usa directamente; si se reproduce en
  /// streaming, se materializa la portada (descarga ligera del asset) y se aplica.
  /// Best-effort: cualquier fallo se ignora (la notificación queda sin carátula).
  Future<void> _ensureArtwork(Pista pista) async {
    final int? albumId = pista.albumId;
    if (albumId == null) {
      return;
    }
    final File local = _store.coverFile(albumId);
    if (local.existsSync()) {
      _handler.setCurrentArt(pista.id, local.path);
      return;
    }
    final PairedPc? pc = ref.read(syncControllerProvider).pc;
    if (pc == null) {
      return;
    }
    try {
      final File? file = await _downloadRepo.ensureCover(pc, albumId);
      if (file != null && state.current?.id == pista.id) {
        _handler.setCurrentArt(pista.id, file.path);
      }
    } catch (_) {
      // Materialización oportunista: si falla, la notificación queda sin portada.
    }
  }

  // ── Persistencia de sesión (restaurar lo que sonaba al reabrir) ────────────
  /// Serializa la cola (ids), el índice y la posición a kv. Se llama al cambiar
  /// de pista/cola y al pasar a segundo plano (captura la posición real). No
  /// persiste en cada tick de posición (evita escrituras constantes a SQLite).
  void guardarSesion() {
    final List<Pista> q = state.queue;
    if (q.isEmpty) {
      // Sin cola: limpia la sesión para no restaurar algo vacío.
      _persistir(SyncStateDao.kSesion, '');
      return;
    }
    _persistir(
      SyncStateDao.kSesion,
      jsonEncode(<String, dynamic>{
        'ids': <int>[for (final Pista p in q) p.id],
        'index': state.index,
        'posMs': state.position.inMilliseconds,
      }),
    );
  }

  /// Restaura la sesión guardada **en pausa**. Resuelve las ids contra el catálogo
  /// en una sola consulta; las pistas que ya no existan se omiten. Best-effort.
  Future<void> _restaurarSesion() async {
    if (state.queue.isNotEmpty) {
      return;
    }
    final String? raw =
        await ref.read(syncStateDaoProvider).getValor(SyncStateDao.kSesion);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return;
      }
      final List<int> ids = <int>[
        for (final Object? x in (decoded['ids'] as List? ?? const <Object?>[]))
          if (x is num) x.toInt(),
      ];
      if (ids.isEmpty) {
        return;
      }
      final int index = (decoded['index'] as num?)?.toInt() ?? 0;
      final int posMs = (decoded['posMs'] as num?)?.toInt() ?? 0;
      final Map<int, Pista> porId = await _catalog.getPistasPorIds(ids);
      final List<Pista> pistas = <Pista>[
        for (final int id in ids)
          if (porId[id] case final Pista p) p,
      ];
      if (pistas.isEmpty || state.queue.isNotEmpty) {
        return;
      }
      final int idx = index.clamp(0, pistas.length - 1);
      _handler.remote = ref.read(remoteMediaProvider);
      _handler.karaokeId = null;
      final List<Pista> fuentes = await _resolverFuentes(pistas);
      state = state.copyWith(queue: pistas, index: idx, karaoke: false);
      // No registrar historial al restaurar (no es una reproducción nueva).
      _lastRecordedIndex = idx;
      await _handler.loadQueue(
        fuentes,
        idx,
        initialPosition: Duration(milliseconds: posMs < 0 ? 0 : posMs),
        autoPlay: false,
      );
    } catch (_) {
      // Sesión corrupta o incompatible: se ignora (arranca sin nada sonando).
    }
  }
}

final NotifierProvider<PlayerController, PlayerState> playerControllerProvider =
    NotifierProvider<PlayerController, PlayerState>(PlayerController.new);
