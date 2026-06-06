import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/nb_api_client.dart';
import '../../../core/security/secure_store.dart';
import '../../../data/db/daos/catalog_dao.dart';
import '../../../data/db/daos/downloads_dao.dart';
import '../../../data/db/database.dart';
import '../data/download_repository.dart';

final Provider<DownloadRepository> downloadRepositoryProvider =
    Provider<DownloadRepository>((Ref ref) {
  final SecureStore store = ref.watch(secureStoreProvider);
  return DownloadRepository(
    db: ref.watch(databaseProvider),
    audioDir: ref.watch(appAudioDirProvider),
    dioFor: (PairedPc pc) => NbApiClient.create(
      baseUrl: pc.baseUrl,
      fingerprint: pc.fingerprint,
      token: store.deviceToken,
    ),
  );
});

/// Ids de pistas con descarga completada (reactivo).
final StreamProvider<Set<int>> descargadasProvider =
    StreamProvider<Set<int>>(
  (Ref ref) => ref.watch(downloadsDaoProvider).watchDescargadas(),
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

class DownloadQueueState {
  const DownloadQueueState({
    this.pendientes = const <int>[],
    this.actual,
    this.recibidos = 0,
    this.total,
  });

  final List<int> pendientes;
  final int? actual;
  final int recibidos;
  final int? total;

  bool get activo => actual != null;

  double? get progreso => (total != null && total! > 0)
      ? (recibidos / total!).clamp(0.0, 1.0)
      : null;
}

/// Cola de descargas: procesa una pista a la vez usando el PC emparejado.
class DownloadQueueController extends Notifier<DownloadQueueState> {
  late final DownloadRepository _repo;
  late final SecureStore _store;
  bool _running = false;

  @override
  DownloadQueueState build() {
    _repo = ref.watch(downloadRepositoryProvider);
    _store = ref.watch(secureStoreProvider);
    Future<void>(_resumePendientes);
    return const DownloadQueueState();
  }

  CatalogDao get _catalog => ref.read(catalogDaoProvider);
  DownloadsDao get _downloads => ref.read(downloadsDaoProvider);

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

  Future<void> eliminar(int pistaId) async {
    await _repo.remove(pistaId);
    if (state.pendientes.contains(pistaId)) {
      state = DownloadQueueState(
        pendientes:
            state.pendientes.where((int x) => x != pistaId).toList(),
        actual: state.actual,
        recibidos: state.recibidos,
        total: state.total,
      );
    }
  }

  Future<void> _resumePendientes() async {
    final List<DescargaAudio> pend = await _downloads.pendientes();
    if (pend.isNotEmpty) {
      await _enqueue(<int>[for (final DescargaAudio d in pend) d.pistaId]);
    }
  }

  Future<void> _enqueue(List<int> ids) async {
    final List<int> nuevos = <int>[];
    for (final int id in ids) {
      if (await _downloads.estaDescargada(id)) {
        continue;
      }
      if (state.pendientes.contains(id) || state.actual == id) {
        continue;
      }
      await _downloads.upsert(
        DescargasAudioCompanion.insert(
          pistaId: Value(id),
          estado: const Value(DownloadEstado.pending),
          actualizadoEn: DateTime.now().toUtc(),
        ),
      );
      nuevos.add(id);
    }
    if (nuevos.isEmpty) {
      return;
    }
    state = DownloadQueueState(
      pendientes: <int>[...state.pendientes, ...nuevos],
      actual: state.actual,
      recibidos: state.recibidos,
      total: state.total,
    );
    unawaited(_drain());
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
        if (pista != null) {
          state = DownloadQueueState(pendientes: state.pendientes, actual: id);
          try {
            await _repo.download(
              pc,
              pista,
              onProgress: (int r, int? t) {
                state = DownloadQueueState(
                  pendientes: state.pendientes,
                  actual: id,
                  recibidos: r,
                  total: t,
                );
              },
            );
          } catch (_) {
            // El repo ya marcó 'failed'; se continúa con la siguiente.
          }
        }
        state = DownloadQueueState(
          pendientes: state.pendientes.where((int x) => x != id).toList(),
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
