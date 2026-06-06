import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'downloads_dao.g.dart';

/// Estado de descargas de audio por pista. El andamiaje queda listo; la
/// descarga por red (Range + hash) se implementa en la tanda de offline.
@DriftAccessor(tables: <Type>[DescargasAudio])
class DownloadsDao extends DatabaseAccessor<AppDatabase>
    with _$DownloadsDaoMixin {
  DownloadsDao(super.db);

  Stream<List<DescargaAudio>> watchTodas() => select(descargasAudio).watch();

  Stream<DescargaAudio?> watchEstado(int pistaId) =>
      (select(descargasAudio)..where((t) => t.pistaId.equals(pistaId)))
          .watchSingleOrNull();

  Future<DescargaAudio?> getEstado(int pistaId) =>
      (select(descargasAudio)..where((t) => t.pistaId.equals(pistaId)))
          .getSingleOrNull();

  Future<void> upsert(DescargasAudioCompanion companion) =>
      into(descargasAudio).insertOnConflictUpdate(companion);

  Future<void> eliminar(int pistaId) =>
      (delete(descargasAudio)..where((t) => t.pistaId.equals(pistaId))).go();

  /// Ids de pistas con descarga completada (para resolver reproducción offline).
  Stream<Set<int>> watchDescargadas() =>
      (select(descargasAudio)..where((t) => t.estado.equals('done')))
          .watch()
          .map((List<DescargaAudio> rows) =>
              rows.map((DescargaAudio r) => r.pistaId).toSet());

  Future<bool> estaDescargada(int pistaId) async {
    final DescargaAudio? row = await getEstado(pistaId);
    return row?.estado == 'done';
  }

  /// Descargas pendientes o a medias (para reanudar al arrancar).
  Future<List<DescargaAudio>> pendientes() => (select(descargasAudio)
        ..where((t) =>
            t.estado.equals('pending') | t.estado.equals('downloading')))
      .get();
}
