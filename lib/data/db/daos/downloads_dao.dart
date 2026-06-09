import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'downloads_dao.g.dart';

/// Conteos persistentes de descargas por recurso (audio/letra/karaoke), para los
/// contadores reales de la pantalla de Descargas. `pendientes` = `pending` +
/// `downloading`. No incluye `none` (recurso no intentado) ni `unavailable`.
class ResumenDescargas {
  const ResumenDescargas({
    this.audioDone = 0,
    this.audioFailed = 0,
    this.audioPendientes = 0,
    this.lyricsDone = 0,
    this.lyricsFailed = 0,
    this.stemsDone = 0,
    this.stemsFailed = 0,
  });

  final int audioDone;
  final int audioFailed;
  final int audioPendientes;
  final int lyricsDone;
  final int lyricsFailed;
  final int stemsDone;
  final int stemsFailed;

  /// Total de recursos en estado `failed` (audio + letra + karaoke).
  int get totalFallidas => audioFailed + lyricsFailed + stemsFailed;
}

/// Estado de la descarga offline por pista: audio (recurso principal), letra y
/// karaoke (instrumental). Las imágenes (portada/artista) se trackean en
/// [AssetsDao] porque se comparten entre pistas.
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

  /// Fija el estado de la letra de [pistaId] sin tocar el resto de recursos.
  Future<void> setLyricsEstado(int pistaId, String estado) => upsert(
        DescargasAudioCompanion.insert(
          pistaId: Value(pistaId),
          lyricsEstado: Value(estado),
          actualizadoEn: DateTime.now().toUtc(),
        ),
      );

  /// Fija el estado (y progreso) del instrumental de karaoke de [pistaId].
  Future<void> setStemsEstado(
    int pistaId,
    String estado, {
    int? bytes,
    int? total,
  }) =>
      upsert(
        DescargasAudioCompanion.insert(
          pistaId: Value(pistaId),
          stemsEstado: Value(estado),
          stemsBytes: bytes != null ? Value(bytes) : const Value.absent(),
          stemsTotalBytes:
              total != null ? Value(total) : const Value.absent(),
          actualizadoEn: DateTime.now().toUtc(),
        ),
      );

  Future<void> eliminar(int pistaId) =>
      (delete(descargasAudio)..where((t) => t.pistaId.equals(pistaId))).go();

  /// Ids de pistas con audio descargado (para resolver reproducción offline).
  Stream<Set<int>> watchDescargadas() =>
      (select(descargasAudio)..where((t) => t.estado.equals('done')))
          .watch()
          .map((List<DescargaAudio> rows) =>
              rows.map((DescargaAudio r) => r.pistaId).toSet());

  /// Ids de pistas con instrumental de karaoke descargado (resolución offline).
  Stream<Set<int>> watchStemsDescargados() =>
      (select(descargasAudio)..where((t) => t.stemsEstado.equals('done')))
          .watch()
          .map((List<DescargaAudio> rows) =>
              rows.map((DescargaAudio r) => r.pistaId).toSet());

  /// Conteos persistentes por estado/recurso, en una sola consulta reactiva.
  Stream<ResumenDescargas> watchResumen() {
    Expression<int> cuenta(Expression<bool> filtro) =>
        descargasAudio.pistaId.count(filter: filtro);
    final Expression<int> audioDone =
        cuenta(descargasAudio.estado.equals('done'));
    final Expression<int> audioFailed =
        cuenta(descargasAudio.estado.equals('failed'));
    final Expression<int> audioPend = cuenta(
        descargasAudio.estado.isIn(<String>['pending', 'downloading']));
    final Expression<int> lyricsDone =
        cuenta(descargasAudio.lyricsEstado.equals('done'));
    final Expression<int> lyricsFailed =
        cuenta(descargasAudio.lyricsEstado.equals('failed'));
    final Expression<int> stemsDone =
        cuenta(descargasAudio.stemsEstado.equals('done'));
    final Expression<int> stemsFailed =
        cuenta(descargasAudio.stemsEstado.equals('failed'));

    final query = selectOnly(descargasAudio)
      ..addColumns(<Expression<Object>>[
        audioDone,
        audioFailed,
        audioPend,
        lyricsDone,
        lyricsFailed,
        stemsDone,
        stemsFailed,
      ]);
    return query.watchSingle().map((TypedResult row) => ResumenDescargas(
          audioDone: row.read(audioDone) ?? 0,
          audioFailed: row.read(audioFailed) ?? 0,
          audioPendientes: row.read(audioPend) ?? 0,
          lyricsDone: row.read(lyricsDone) ?? 0,
          lyricsFailed: row.read(lyricsFailed) ?? 0,
          stemsDone: row.read(stemsDone) ?? 0,
          stemsFailed: row.read(stemsFailed) ?? 0,
        ));
  }

  Future<bool> estaDescargada(int pistaId) async {
    final DescargaAudio? row = await getEstado(pistaId);
    return row?.estado == 'done';
  }

  Future<bool> tieneStems(int pistaId) async {
    final DescargaAudio? row = await getEstado(pistaId);
    return row?.stemsEstado == 'done';
  }

  /// Descargas pendientes, a medias o fallidas (para reanudar/reintentar al
  /// arrancar). `none` (recurso no intentado) queda fuera: se completa cuando el
  /// usuario vuelve a pedir la descarga (selección incremental). 404 (`unavailable`)
  /// no se reintenta.
  Future<List<DescargaAudio>> pendientes() => (select(descargasAudio)
        ..where((t) =>
            t.estado.isIn(<String>['pending', 'downloading', 'failed']) |
            t.lyricsEstado.isIn(<String>['pending', 'failed']) |
            t.stemsEstado.isIn(<String>['pending', 'downloading', 'failed'])))
      .get();
}
