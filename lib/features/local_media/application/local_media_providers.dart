import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/database.dart';
import 'local_media_service.dart';

final Provider<LocalMediaService> localMediaServiceProvider =
    Provider<LocalMediaService>(
  (Ref ref) => LocalMediaService(
    dao: ref.watch(localMediaDaoProvider),
    syncState: ref.watch(syncStateDaoProvider),
  ),
);

/// Pistas locales indexadas (reactivo).
final StreamProvider<List<Pista>> pistasLocalesProvider =
    StreamProvider<List<Pista>>(
  (Ref ref) => ref.watch(localMediaDaoProvider).watchPistasLocales(),
);

/// Conteo de pistas locales (reactivo).
final StreamProvider<int> conteoLocalesProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(localMediaDaoProvider).watchConteoLocales(),
);

/// Pistas locales ocultadas individualmente (reactivo).
final StreamProvider<List<LocalOcultaRow>> ocultasLocalesProvider =
    StreamProvider<List<LocalOcultaRow>>(
  (Ref ref) => ref.watch(localMediaDaoProvider).watchOcultas(),
);

/// Fase del proceso de escaneo de música local.
enum FaseEscaneo { inactivo, escaneando, listo, sinPermiso, error }

class EstadoLocalMedia {
  const EstadoLocalMedia({
    this.fase = FaseEscaneo.inactivo,
    this.permiso = PermisoAudio.denegado,
    this.ocultaGlobal = false,
    this.auto = true,
    this.duplicadosQuitados = 0,
  });

  final FaseEscaneo fase;
  final PermisoAudio permiso;

  /// Toda la música local oculta (flag global del usuario).
  final bool ocultaGlobal;

  /// Revisión automática (al arrancar + tras cada sync).
  final bool auto;
  final int duplicadosQuitados;

  EstadoLocalMedia copyWith({
    FaseEscaneo? fase,
    PermisoAudio? permiso,
    bool? ocultaGlobal,
    bool? auto,
    int? duplicadosQuitados,
  }) =>
      EstadoLocalMedia(
        fase: fase ?? this.fase,
        permiso: permiso ?? this.permiso,
        ocultaGlobal: ocultaGlobal ?? this.ocultaGlobal,
        auto: auto ?? this.auto,
        duplicadosQuitados: duplicadosQuitados ?? this.duplicadosQuitados,
      );
}

/// Controla el escaneo y la gestión de la música local desde la UI.
class LocalMediaController extends Notifier<EstadoLocalMedia> {
  @override
  EstadoLocalMedia build() {
    _cargar();
    return const EstadoLocalMedia();
  }

  LocalMediaService get _service => ref.read(localMediaServiceProvider);

  Future<void> _cargar() async {
    final PermisoAudio permiso = await _service.estadoPermiso();
    final bool oculta = await _service.ocultaGlobal();
    final bool auto = await _service.autoRevision();
    state = state.copyWith(permiso: permiso, ocultaGlobal: oculta, auto: auto);
    await revisarSiAuto();
  }

  /// Revisa el dispositivo solo si la revisión automática está activa (y hay
  /// permiso, no está todo oculto y no hay un escaneo en curso). Lo llama el
  /// arranque y el regreso a primer plano.
  Future<void> revisarSiAuto() async {
    if (state.auto &&
        state.permiso == PermisoAudio.concedido &&
        !state.ocultaGlobal &&
        state.fase != FaseEscaneo.escaneando) {
      await escanear(pedir: false);
    }
  }

  /// Escaneo manual o automático. Idempotente y reentrante.
  Future<void> escanear({bool pedir = true}) async {
    if (state.fase == FaseEscaneo.escaneando) {
      return;
    }
    state = state.copyWith(fase: FaseEscaneo.escaneando);
    try {
      final EscaneoResultado r = await _service.escanear(pedir: pedir);
      if (!r.ok) {
        state = state.copyWith(fase: FaseEscaneo.sinPermiso, permiso: r.permiso);
        return;
      }
      state = state.copyWith(
        fase: FaseEscaneo.listo,
        permiso: r.permiso,
        duplicadosQuitados: r.duplicadosQuitados,
      );
    } catch (_) {
      state = state.copyWith(fase: FaseEscaneo.error);
    }
  }

  /// Activa/desactiva la revisión automática.
  Future<void> setAuto(bool v) async {
    await _service.setAutoRevision(v);
    state = state.copyWith(auto: v);
  }

  /// Oculta o muestra TODA la música local.
  Future<void> setOcultarTodas(bool ocultar) async {
    state = state.copyWith(ocultaGlobal: ocultar, fase: FaseEscaneo.escaneando);
    if (ocultar) {
      await _service.ocultarTodas();
      state = state.copyWith(fase: FaseEscaneo.listo);
    } else {
      final EscaneoResultado r = await _service.mostrarTodas();
      state = state.copyWith(
        fase: r.ok ? FaseEscaneo.listo : FaseEscaneo.sinPermiso,
        permiso: r.permiso,
      );
    }
  }

  /// Oculta una pista (no la borra del teléfono).
  Future<void> ocultarPista(int mediaId, String titulo, String? artista) =>
      _service.ocultarPista(mediaId, titulo, artista);

  /// Revela una pista oculta.
  Future<void> mostrarPista(int mediaId) => _service.mostrarPista(mediaId);

  /// Revela todas las pistas ocultas individualmente.
  Future<void> mostrarTodasOcultas() => _service.mostrarTodasOcultas();
}

final NotifierProvider<LocalMediaController, EstadoLocalMedia>
    localMediaControllerProvider =
    NotifierProvider<LocalMediaController, EstadoLocalMedia>(
        LocalMediaController.new);
