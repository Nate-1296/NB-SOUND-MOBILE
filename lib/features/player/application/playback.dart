import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/security/secure_store.dart';
import '../../../data/db/database.dart';
import '../../local_media/application/local_ids.dart';
import '../../remote_control/application/remote_controller.dart';
import '../../remote_control/data/remote_dtos.dart';
import 'player_controller.dart';

/// Destino de reproducción (Spotify Connect): este teléfono o el PC.
enum PlaybackTarget { local, remote }

class PlaybackTargetController extends Notifier<PlaybackTarget> {
  @override
  PlaybackTarget build() => PlaybackTarget.local;

  /// Cambia a control remoto si hay un PC emparejado. Devuelve false si no.
  /// Handoff (Spotify Connect): pausa el móvil (solo un dispositivo suena) y
  /// **espeja la cola COMPLETA** en el PC —no solo la pista en curso— arrancando
  /// en la pista que sonaba y conservando su posición, de modo que la cola
  /// persista al cambiar de dispositivo.
  Future<bool> usarRemoto() async {
    final PairedPc? pc = await ref.read(secureStoreProvider).readPairing();
    if (pc == null) {
      return false;
    }
    // Captura la cola local COMPLETA (no solo la pista en curso) antes de cambiar
    // de destino: se espeja entera en el PC para que la cola no se pierda.
    final PlayerState local = ref.read(playerControllerProvider);
    final HandoffRemoto plan = planHandoffRemoto(
      local.queue,
      local.index,
      local.position.inMilliseconds / 1000.0,
    );

    final RemoteController r = ref.read(remoteControllerProvider.notifier);
    r.conectar(pc);
    state = PlaybackTarget.remote;

    if (plan.hayCola) {
      // Pausa el móvil y reemplaza la cola del PC por la del teléfono en UNA
      // difusión (`set_queue`), arrancando en la pista en curso y conservando su
      // posición. La música local (id < 0) ya quedó filtrada (no existe allí).
      ref.read(playerControllerProvider.notifier).pausar();
      r.establecerCola(plan.ids, plan.indice, posicionSeg: plan.posicionSeg);
    } else if (local.hasTrack) {
      // Lo que suena es música local (no existe en el PC): solo se pausa el
      // teléfono; el PC conserva su propio estado y su cola.
      ref.read(playerControllerProvider.notifier).pausar();
    }
    return true;
  }

  /// Vuelve a reproducir en este teléfono. Handoff inverso (Spotify Connect): si
  /// el PC estaba sonando lo **pausa** (solo un dispositivo suena) y **trae** al
  /// teléfono la **cola COMPLETA** del PC —misma posición y estado— en vez de
  /// dejar el teléfono solo con la pista en curso.
  Future<void> usarLocal() async {
    final RemoteState remoto = ref.read(remoteControllerProvider);
    final RemotePistaDto? pcPista = remoto.estado.pista;
    final TraspasoLocal plan = planTraspasoLocal(
      conectado: remoto.conectado,
      pistaId: pcPista?.id,
      posicionSeg: remoto.estado.posicionSeg,
      reproduciendo: remoto.estado.reproduciendo,
    );
    // Cola espejada del PC (ids en orden) + índice en curso, capturados ANTES de
    // desconectar (desconectar() vacía el estado remoto).
    final List<int> colaIds = <int>[
      for (final RemotePistaDto p in remoto.cola) p.id,
    ];
    final int indiceCola = remoto.estado.indiceCola;

    // Pausa el PC al tomar el control desde el teléfono (un solo dispositivo).
    if (plan.pausarPc) {
      ref.read(remoteControllerProvider.notifier).playPause();
    }
    ref.read(remoteControllerProvider.notifier).desconectar();
    state = PlaybackTarget.local;

    final PlayerController pc = ref.read(playerControllerProvider.notifier);
    if (colaIds.isNotEmpty) {
      // Trae la COLA COMPLETA del PC al teléfono (no solo la pista en curso):
      // misma posición y estado de reproducción.
      await pc.reproducirColaRemota(
        colaIds,
        indiceCola,
        posicionSeg: plan.posicionSeg,
        reproducir: plan.reproducir,
      );
    } else if (plan.hayTraspaso) {
      // Degradación: si el PC no publicó la cola, al menos trae la pista en curso.
      await pc.reproducirIdRemota(
        plan.pistaId!,
        posicionSeg: plan.posicionSeg,
        reproducir: plan.reproducir,
      );
    }
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
        ModoRepeticionPc.uno => RepeatMode.one,
        ModoRepeticionPc.todo => RepeatMode.all,
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

/// Plan de **cola espejada** para el PC: filtra la música local (id < 0, no existe
/// allí) y reubica el índice tocado dentro de la lista filtrada. Si la lista está
/// vacía, el índice es inválido o la pista tocada es local, devuelve `ids` vacío
/// (no se hace nada en remoto). Una sola difusión `set_queue` reemplaza la cola
/// del PC, en vez de mandar pista a pista. Pura y testeable.
({List<int> ids, int indice}) planSetQueueRemota(List<Pista> pistas, int index) {
  if (pistas.isEmpty || index < 0 || index >= pistas.length) {
    return (ids: const <int>[], indice: 0);
  }
  if (esIdLocal(pistas[index].id)) {
    return (ids: const <int>[], indice: 0);
  }
  final int objetivo = pistas[index].id;
  final List<int> ids = <int>[
    for (final Pista p in pistas)
      if (!esIdLocal(p.id)) p.id,
  ];
  return (ids: ids, indice: ids.indexOf(objetivo));
}

/// Plan de handoff al **PC** al pasar el control desde el teléfono (Spotify
/// Connect): espeja la cola local COMPLETA filtrando la música local (id < 0, no
/// existe allí) y arranca en la pista en curso conservando su posición. Si no hay
/// cola, el índice es inválido o la pista en curso es local, no hay nada que
/// espejar (`hayCola == false`; el llamador solo pausa el móvil). Pura y testeable.
class HandoffRemoto {
  const HandoffRemoto({
    required this.ids,
    required this.indice,
    required this.posicionSeg,
  });

  final List<int> ids;
  final int indice;
  final double posicionSeg;

  bool get hayCola => ids.isNotEmpty;
}

HandoffRemoto planHandoffRemoto(
  List<Pista> cola,
  int index,
  double posicionSeg,
) {
  if (cola.isEmpty || index < 0 || index >= cola.length) {
    return const HandoffRemoto(ids: <int>[], indice: 0, posicionSeg: 0);
  }
  // La pista en curso es local: no existe en el PC, no se puede espejar
  // arrancando ahí.
  if (esIdLocal(cola[index].id)) {
    return const HandoffRemoto(ids: <int>[], indice: 0, posicionSeg: 0);
  }
  final List<int> ids = <int>[
    for (final Pista p in cola)
      if (!esIdLocal(p.id)) p.id,
  ];
  // Índice de la pista en curso dentro de la lista filtrada: cuenta las no
  // locales anteriores (exacto aun con ids repetidas en la cola).
  int indice = 0;
  for (int i = 0; i < index; i++) {
    if (!esIdLocal(cola[i].id)) {
      indice += 1;
    }
  }
  return HandoffRemoto(
    ids: ids,
    indice: indice,
    posicionSeg: posicionSeg < 0 ? 0 : posicionSeg,
  );
}

/// Plan de traspaso al **tomar el control en el teléfono** (Spotify Connect):
/// dado lo que publica el PC, decide si hay que pausarlo (solo un dispositivo
/// suena) y qué pista/posición/estado traer al reproductor local. Pura y
/// testeable (sin red ni reproductor).
class TraspasoLocal {
  const TraspasoLocal({
    required this.pausarPc,
    required this.pistaId,
    required this.posicionSeg,
    required this.reproducir,
  });

  /// Hay que pausar el PC (estaba conectado y sonando).
  final bool pausarPc;

  /// Pista del PC a traer al teléfono (null/≤0 si no hay nada que traspasar).
  final int? pistaId;
  final double posicionSeg;

  /// Estado a aplicar localmente (sonando o en pausa).
  final bool reproducir;

  /// True si hay una pista válida que traspasar.
  bool get hayTraspaso => pistaId != null && pistaId! > 0;
}

TraspasoLocal planTraspasoLocal({
  required bool conectado,
  required int? pistaId,
  required double posicionSeg,
  required bool reproduciendo,
}) {
  return TraspasoLocal(
    pausarPc: conectado && reproduciendo,
    pistaId: pistaId,
    posicionSeg: posicionSeg,
    reproducir: reproduciendo,
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
      // Connect: cola ESPEJADA. La música local (id < 0) jamás suena en el PC; se
      // filtra y la colección entera se manda en UNA difusión (`set_queue`),
      // reproduciendo el índice tocado. Si la pista tocada es local, no se hace
      // nada.
      final ({List<int> ids, int indice}) plan =
          planSetQueueRemota(pistas, index);
      if (plan.ids.isEmpty) {
        return;
      }
      _r.establecerCola(plan.ids, plan.indice);
      return;
    }
    await _l.reproducir(pistas, index);
  }

  /// Reproduce una colección en aleatorio. Estilo Spotify: arranca en una pista
  /// **al azar** (no siempre la primera) y deja el aleatorio encendido, de modo
  /// que cada pulsación empieza distinto. Mismo comportamiento en TODAS las
  /// colecciones (álbum/artista/playlist/"Tus me gusta"). Enruta al destino activo.
  Future<void> reproducirColeccionAleatorio(List<Pista> pistas) async {
    if (pistas.isEmpty) {
      return;
    }
    if (_remote) {
      // En el PC: manda la cola y fuerza el aleatorio (el PC elige el orden).
      await reproducirColeccion(pistas, 0);
      _r.setAleatorio(true);
      return;
    }
    // Local: arranca en una pista al azar de la colección y asegura el aleatorio
    // global encendido (si estaba apagado, alternarAleatorio además rebaraja).
    final int inicio =
        pistas.length <= 1 ? 0 : Random().nextInt(pistas.length);
    await reproducirColeccion(pistas, inicio);
    if (!_ref.read(playerControllerProvider).shuffle) {
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
        if (!esIdLocal(p.id)) {
          _r.encolarPista(p.id);
        }
      }
      return;
    }
    await _l.encolarColeccion(pistas);
  }

  /// Reproduce una sola pista (listas sueltas, `comoColeccion:false`). En remoto
  /// la manda al PC; en local arranca una cola de una pista.
  Future<void> reproducirPistaUnica(Pista pista) async {
    if (_remote) {
      // La música local (id < 0) no puede sonar en el PC: no se hace nada.
      if (!esIdLocal(pista.id)) {
        _r.reproducirPista(pista.id);
      }
      return;
    }
    await _l.reproducirPista(pista);
  }

  void togglePlay() => _remote ? _r.playPause() : _l.alternarReproduccion();
  void next() => _remote ? _r.siguiente() : _l.siguiente();
  void prev() => _remote ? _r.anterior() : _l.anterior();
  void seekProgress(double p) =>
      _remote ? _r.buscarProgreso(p) : _l.buscar(p);

  /// Salta [segundos] (positivo o negativo) relativo a la posición actual,
  /// acotado a la duración. Para atajos de teclado (flechas). Enruta al destino
  /// activo reusando la posición/duración de "lo que suena".
  void seekRelativo(int segundos) {
    final NowPlaying np = _ref.read(nowPlayingProvider);
    final int total = np.duration.inSeconds;
    if (!np.hasTrack || total <= 0) {
      return;
    }
    final int destino = (np.position.inSeconds + segundos).clamp(0, total);
    seekProgress(destino / total);
  }
  void toggleShuffle() => _remote
      ? _r.setAleatorio(!_ref.read(remoteControllerProvider).estado.aleatorio)
      : _l.alternarAleatorio();
  void cycleRepeat() => _remote ? _r.cicloRepeticion() : _l.cicloRepeticion();
}

final Provider<PlaybackActions> playbackActionsProvider =
    Provider<PlaybackActions>((Ref ref) => PlaybackActions(ref));
