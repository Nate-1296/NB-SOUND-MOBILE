import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../../../data/db/daos/assets_dao.dart';
import '../../../data/db/daos/catalog_dao.dart';
import '../../../data/db/daos/downloads_dao.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../data/db/database.dart';
import '../../library/application/library_providers.dart';
import '../data/download_repository.dart';
import '../data/offline_store.dart';

/// Convención de rutas de la media offline, anclada en el directorio de la app.
final Provider<OfflineStore> offlineStoreProvider = Provider<OfflineStore>(
  (Ref ref) => OfflineStore(ref.watch(appAudioDirProvider).parent),
);

final Provider<DownloadRepository> downloadRepositoryProvider =
    Provider<DownloadRepository>((Ref ref) {
  final SecureStore store = ref.watch(secureStoreProvider);
  return DownloadRepository(
    db: ref.watch(databaseProvider),
    store: ref.watch(offlineStoreProvider),
    dioFor: (PairedPc pc) => NbApiClient.create(
      baseUrl: pc.baseUrl,
      fingerprint: pc.fingerprint,
      token: store.deviceToken,
    ),
  );
});

/// Ids de pistas con audio descargado (reactivo; resuelve reproducción offline).
final StreamProvider<Set<int>> descargadasProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(downloadsDaoProvider).watchDescargadas(),
);

/// Ids de pistas con instrumental de karaoke descargado (reactivo).
final StreamProvider<Set<int>> stemsDescargadosProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(downloadsDaoProvider).watchStemsDescargados(),
);

/// Ids de álbum con portada descargada (reactivo; resolución offline de imágenes).
final StreamProvider<Set<int>> coversDescargadasProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(assetsDaoProvider).watchDescargados(AssetTipo.cover),
);

/// Ids de artista con foto descargada (reactivo).
final StreamProvider<Set<int>> artistasDescargadosProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(assetsDaoProvider).watchDescargados(AssetTipo.artist),
);

/// Ids de álbum cuya portada está **resuelta** (descargada o 404), reactivo.
final StreamProvider<Set<int>> coversResueltasProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(assetsDaoProvider).watchResueltos(AssetTipo.cover),
);

/// Ids de artista cuya foto está **resuelta** (descargada o 404), reactivo.
final StreamProvider<Set<int>> artistasResueltosProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(assetsDaoProvider).watchResueltos(AssetTipo.artist),
);

/// Estado de descarga de una pista (reactivo).
final descargaEstadoProvider =
    StreamProvider.family<DescargaAudio?, int>(
  (Ref ref, int pistaId) =>
      ref.watch(downloadsDaoProvider).watchEstado(pistaId),
);

/// Todas las descargas (para la pantalla de almacenamiento).
final StreamProvider<List<DescargaAudio>> descargasProvider =
    StreamProvider<List<DescargaAudio>>(
  (Ref ref) => ref.watch(downloadsDaoProvider).watchTodas(),
);

/// Conteos persistentes por recurso (audio/letra/karaoke) — contador "N de M".
final StreamProvider<ResumenDescargas> resumenDescargasProvider =
    StreamProvider<ResumenDescargas>(
  (Ref ref) => ref.watch(downloadsDaoProvider).watchResumen(),
);

/// Conteo `{done, failed}` de portadas descargadas (reactivo).
final StreamProvider<ConteoAsset> conteoCoversProvider =
    StreamProvider<ConteoAsset>(
  (Ref ref) => ref.watch(assetsDaoProvider).watchConteo(AssetTipo.cover),
);

/// Conteo `{done, failed}` de fotos de artista descargadas (reactivo).
final StreamProvider<ConteoAsset> conteoArtistasProvider =
    StreamProvider<ConteoAsset>(
  (Ref ref) => ref.watch(assetsDaoProvider).watchConteo(AssetTipo.artist),
);

/// Total de pistas del catálogo (la "M" del contador "N de M").
final StreamProvider<int> totalPistasProvider = StreamProvider<int>(
  (Ref ref) => ref.watch(catalogDaoProvider).watchTotalPistas(),
);

/// Espacio en disco por categoría. Se recalcula cuando cambia el resumen de
/// descargas (algo se bajó o se borró), no en cada frame.
final FutureProvider<EspacioOffline> espacioOfflineProvider =
    FutureProvider<EspacioOffline>((Ref ref) async {
  ref.watch(resumenDescargasProvider);
  return ref.watch(offlineStoreProvider).calcularEspacio();
});

/// Preferencia "Descargar todo" (espejo offline completo del catálogo). Reactiva,
/// persistida en `SyncEstado`. Se aplica tras cada sync (ver [SyncController]).
final StreamProvider<bool> descargarTodoProvider = StreamProvider<bool>(
  (Ref ref) => ref
      .watch(syncStateDaoProvider)
      .watchValor(SyncStateDao.kDescargarTodo)
      .map((String? v) => v == '1'),
);

/// Un recurso está **resuelto** si se descargó (`done`) o el PC no lo tiene
/// (`unavailable`/404). En ambos casos no hay nada más que bajar.
bool recursoResuelto(String estado) =>
    estado == DownloadEstado.done || estado == DownloadEstado.unavailable;

/// Predicado puro de "pista completa": todos sus recursos (audio + letra +
/// karaoke + portada + foto de artista) están resueltos. Núcleo compartido por la
/// cola de descargas y por el provider reactivo de completitud, para que ambas
/// usen exactamente la misma definición. `coverResuelta`/`artistaResuelta` deben
/// venir en `true` cuando la pista no tiene álbum/artista (no hay imagen que bajar).
bool pistaCompletaCore({
  required DescargaAudio? descarga,
  required bool coverResuelta,
  required bool artistaResuelta,
}) {
  final DescargaAudio? d = descarga;
  if (d == null) {
    return false;
  }
  return recursoResuelto(d.estado) &&
      recursoResuelto(d.lyricsEstado) &&
      recursoResuelto(d.stemsEstado) &&
      coverResuelta &&
      artistaResuelta;
}

/// Ids de pistas **completas** (todos sus recursos resueltos), reactivo. Es la
/// versión en vivo de la completitud que evalúa la cola: alimenta la selección de
/// descargas (marcar solo lo incompleto) y los indicadores de la UI. Una pista
/// con audio `unavailable` (el PC no tiene el archivo) cuenta como "completa": no
/// hay nada que descargar de ella.
final Provider<Set<int>> pistasCompletasProvider = Provider<Set<int>>((Ref ref) {
  final List<Pista> pistas =
      ref.watch(pistasProvider).value ?? const <Pista>[];
  final List<DescargaAudio> descargas =
      ref.watch(descargasProvider).value ?? const <DescargaAudio>[];
  final Set<int> coversResueltas =
      ref.watch(coversResueltasProvider).value ?? const <int>{};
  final Set<int> artistasResueltos =
      ref.watch(artistasResueltosProvider).value ?? const <int>{};
  final Map<int, DescargaAudio> porId = <int, DescargaAudio>{
    for (final DescargaAudio d in descargas) d.pistaId: d,
  };
  return <int>{
    for (final Pista p in pistas)
      if (pistaCompletaCore(
        descarga: porId[p.id],
        coverResuelta:
            p.albumId == null || coversResueltas.contains(p.albumId),
        artistaResuelta:
            p.artistaId == null || artistasResueltos.contains(p.artistaId),
      ))
        p.id,
  };
});

class DownloadQueueState {
  const DownloadQueueState({
    this.pendientes = const <int>[],
    this.actual,
    this.recibidos = 0,
    this.total,
    this.completados = 0,
    this.inicioLote,
    this.inicioActual,
    this.tiempoCompletadosMs = 0,
  });

  /// Pistas en cola (incluye la que está en curso hasta que termina).
  final List<int> pendientes;

  /// Pista que se está descargando ahora (null si la cola está inactiva).
  final int? actual;

  /// Bytes recibidos / totales de la pista **en curso** (no del lote).
  final int recibidos;
  final int? total;

  /// Pistas ya procesadas en la corrida actual (éxito o fallo: salieron de la
  /// cola). Se reinicia al empezar un lote nuevo desde inactivo.
  final int completados;

  /// Inicio de la corrida actual y de la pista en curso (para la ETA).
  final DateTime? inicioLote;
  final DateTime? inicioActual;

  /// Tiempo acumulado de las pistas ya completadas en la corrida (para promediar).
  final int tiempoCompletadosMs;

  bool get activo => actual != null;

  /// Progreso por bytes de la pista en curso (no del lote).
  double? get progreso => (total != null && total! > 0)
      ? (recibidos / total!).clamp(0.0, 1.0)
      : null;

  /// Pistas que faltan por terminar (la en curso cuenta: sigue en `pendientes`).
  int get restantes => pendientes.length;

  /// Total de pistas de la corrida actual (terminadas + las que faltan).
  int get totalLote => completados + pendientes.length;

  /// Fracción de pistas completadas del lote (barra global de progreso).
  double? get progresoLote =>
      totalLote > 0 ? (completados / totalLote).clamp(0.0, 1.0) : null;

  /// Estimación de tiempo restante del lote. Necesita al menos una pista
  /// completada para promediar; `null` mientras no haya muestra. Resta el
  /// tiempo ya invertido en la pista en curso para que cuente hacia abajo.
  Duration? get eta {
    if (completados < 1 || restantes < 1 || tiempoCompletadosMs <= 0) {
      return null;
    }
    final double msPorPista = tiempoCompletadosMs / completados;
    final double restanteTotalMs = msPorPista * restantes;
    final int transcurridoActualMs = inicioActual != null
        ? DateTime.now().difference(inicioActual!).inMilliseconds
        : 0;
    final double etaMs =
        (restanteTotalMs - transcurridoActualMs).clamp(0.0, restanteTotalMs);
    return Duration(milliseconds: etaMs.round());
  }

  DownloadQueueState copyWith({
    List<int>? pendientes,
    int? actual,
    bool limpiarActual = false,
    int? recibidos,
    int? total,
    bool reiniciarBytes = false,
    int? completados,
    DateTime? inicioLote,
    DateTime? inicioActual,
    int? tiempoCompletadosMs,
  }) {
    return DownloadQueueState(
      pendientes: pendientes ?? this.pendientes,
      actual: limpiarActual ? null : (actual ?? this.actual),
      recibidos: reiniciarBytes ? 0 : (recibidos ?? this.recibidos),
      total: reiniciarBytes ? null : (total ?? this.total),
      completados: completados ?? this.completados,
      inicioLote: inicioLote ?? this.inicioLote,
      inicioActual: limpiarActual ? null : (inicioActual ?? this.inicioActual),
      tiempoCompletadosMs: tiempoCompletadosMs ?? this.tiempoCompletadosMs,
    );
  }
}

/// Cola de descargas: procesa una pista a la vez (audio + portada + foto de
/// artista + letra + karaoke) contra el PC emparejado. Incremental: encola solo
/// pistas **incompletas** y cada recurso se salta a sí mismo si ya está
/// `done`/`unavailable`, de modo que "descargar" de nuevo solo baja lo que falta.
class DownloadQueueController extends Notifier<DownloadQueueState> {
  late final DownloadRepository _repo;
  late final SecureStore _store;
  bool _running = false;

  @override
  DownloadQueueState build() {
    _repo = ref.watch(downloadRepositoryProvider);
    _store = ref.watch(secureStoreProvider);
    // Reanuda descargas a medias/fallidas al arrancar (sin bloquear el 1er estado).
    Future<void>(reintentarFallidas);
    return const DownloadQueueState();
  }

  CatalogDao get _catalog => ref.read(catalogDaoProvider);
  DownloadsDao get _downloads => ref.read(downloadsDaoProvider);
  AssetsDao get _assets => ref.read(assetsDaoProvider);

  Future<void> encolarPista(int pistaId) => _enqueue(<int>[pistaId]);

  Future<void> encolarAlbum(int albumId) async {
    final List<Pista> pistas =
        await _catalog.watchPistasDeAlbum(albumId).first;
    await _enqueue(<int>[for (final Pista p in pistas) p.id]);
  }

  Future<void> encolarPlaylist(int playlistId) async {
    final List<Pista> pistas =
        await _catalog.watchPistasDePlaylist(playlistId).first;
    await _enqueue(<int>[for (final Pista p in pistas) p.id]);
  }

  /// Re-encola toda pista con algún recurso pendiente/a-medias/fallido (reusa
  /// `DownloadsDao.pendientes()`). Lo usa el mantenimiento tras sincronizar, el
  /// botón "Reintentar fallidas" y la reanudación al arrancar.
  Future<void> reintentarFallidas() async {
    final List<DescargaAudio> pend = await _downloads.pendientes();
    if (pend.isNotEmpty) {
      await _enqueue(<int>[for (final DescargaAudio d in pend) d.pistaId]);
    }
  }

  /// Encola TODO el catálogo (espejo offline completo). La cola filtra las pistas
  /// ya completas, así que solo baja lo que falta. Procesa por bloques para no
  /// bloquear con bibliotecas grandes.
  Future<void> encolarTodo() async {
    final List<Pista> pistas = await _catalog.watchPistas().first;
    const int bloque = 300;
    for (int i = 0; i < pistas.length; i += bloque) {
      final int fin = (i + bloque < pistas.length) ? i + bloque : pistas.length;
      await _enqueue(<int>[for (final Pista p in pistas.sublist(i, fin)) p.id]);
    }
  }

  /// Encola las pistas incompletas de las playlists guardadas, para mantenerlas
  /// vivas offline: si el PC les añadió pistas, se descargan en la próxima pasada.
  Future<void> mantenerPlaylistsGuardadas() async {
    final Set<int> guardadas =
        await ref.read(followedPlaylistsDaoProvider).watchGuardadasIds().first;
    if (guardadas.isEmpty) {
      return;
    }
    final Set<int> pistaIds = <int>{};
    for (final int playlistId in guardadas) {
      final List<Pista> pistas =
          await _catalog.watchPistasDePlaylist(playlistId).first;
      pistaIds.addAll(<int>[for (final Pista p in pistas) p.id]);
    }
    if (pistaIds.isNotEmpty) {
      await _enqueue(pistaIds.toList());
    }
  }

  Future<void> eliminar(int pistaId) async {
    await _repo.remove(pistaId);
    if (state.pendientes.contains(pistaId)) {
      state = state.copyWith(
        pendientes: state.pendientes.where((int x) => x != pistaId).toList(),
      );
    }
  }

  Future<void> _enqueue(List<int> ids) async {
    final List<int> nuevos = <int>[];
    for (final int id in ids) {
      if (state.pendientes.contains(id) || state.actual == id) {
        continue;
      }
      final Pista? pista = await _catalog.getPista(id);
      if (pista == null) {
        continue;
      }
      if (await _pistaCompleta(pista)) {
        continue;
      }
      // Marca de intención (solo si no hay fila): permite reanudar tras un cierre
      // antes de procesar. No pisa el estado de una descarga ya en curso/parcial.
      if (await _downloads.getEstado(id) == null) {
        await _downloads.upsert(
          DescargasAudioCompanion.insert(
            pistaId: Value(id),
            estado: const Value(DownloadEstado.pending),
            actualizadoEn: DateTime.now().toUtc(),
          ),
        );
      }
      nuevos.add(id);
    }
    if (nuevos.isEmpty) {
      return;
    }
    // Si la cola estaba inactiva, esto inicia un lote nuevo: reinicia los
    // contadores de progreso/ETA. Si ya había una corrida en curso, solo se
    // suman pistas al lote actual.
    final bool iniciandoLote = !_running;
    state = state.copyWith(
      pendientes: <int>[...state.pendientes, ...nuevos],
      completados: iniciandoLote ? 0 : null,
      tiempoCompletadosMs: iniciandoLote ? 0 : null,
      inicioLote: iniciandoLote ? DateTime.now() : null,
    );
    unawaited(_drain());
  }

  /// true si la pista tiene TODOS sus recursos resueltos (`done` o `unavailable`).
  /// Reusa el núcleo compartido [pistaCompletaCore].
  Future<bool> _pistaCompleta(Pista p) async {
    final DescargaAudio? d = await _downloads.getEstado(p.id);
    final bool coverResuelta =
        p.albumId == null || await _assetResuelto(AssetTipo.cover, p.albumId!);
    final bool artistaResuelta = p.artistaId == null ||
        await _assetResuelto(AssetTipo.artist, p.artistaId!);
    return pistaCompletaCore(
      descarga: d,
      coverResuelta: coverResuelta,
      artistaResuelta: artistaResuelta,
    );
  }

  Future<bool> _assetResuelto(String tipo, int refId) async {
    final AssetDescargado? a = await _assets.getEstado(tipo, refId);
    return a != null && recursoResuelto(a.estado);
  }

  Future<void> _drain() async {
    if (_running) {
      return;
    }
    _running = true;
    try {
      while (state.pendientes.isNotEmpty) {
        final PairedPc? pc = await _store.readPairing();
        if (pc == null) {
          break; // sin PC emparejado: queda pendiente para más tarde
        }
        final int id = state.pendientes.first;
        final Pista? pista = await _catalog.getPista(id);
        final DateTime inicio = DateTime.now();
        if (pista != null) {
          state = state.copyWith(
            actual: id,
            inicioActual: inicio,
            reiniciarBytes: true,
          );
          try {
            await _repo.descargarPista(
              pc,
              pista,
              onProgress: (int r, int? t) {
                state = state.copyWith(recibidos: r, total: t);
              },
            );
          } catch (_) {
            // El repo ya marcó el estado por recurso; se continúa con la siguiente.
          }
        }
        // La pista salió de la cola (éxito, fallo o inexistente): cuenta para el
        // lote, alimenta la ETA (solo si hubo descarga real) y libera "actual".
        state = state.copyWith(
          pendientes: state.pendientes.where((int x) => x != id).toList(),
          completados: state.completados + 1,
          tiempoCompletadosMs: state.tiempoCompletadosMs +
              (pista != null
                  ? DateTime.now().difference(inicio).inMilliseconds
                  : 0),
          limpiarActual: true,
          reiniciarBytes: true,
        );
      }
    } finally {
      _running = false;
    }
  }
}

final NotifierProvider<DownloadQueueController, DownloadQueueState>
    downloadQueueProvider =
    NotifierProvider<DownloadQueueController, DownloadQueueState>(
  DownloadQueueController.new,
);
