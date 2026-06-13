import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'assets_dao.g.dart';

/// Tipos de asset de imagen descargable (espejo de `/api/v1/asset/{tipo}/{id}`).
abstract final class AssetTipo {
  static const String cover = 'cover';
  static const String artist = 'artist';
}

/// Conteo de imágenes por estado para un [AssetTipo] (contadores de Descargas).
class ConteoAsset {
  const ConteoAsset({this.done = 0, this.failed = 0});

  final int done;
  final int failed;
}

/// Estado de las imágenes descargadas (portada de álbum / foto de artista),
/// deduplicadas por entidad para no rebajar la misma imagen por cada pista.
@DriftAccessor(tables: <Type>[AssetsDescargados])
class AssetsDao extends DatabaseAccessor<AppDatabase> with _$AssetsDaoMixin {
  AssetsDao(super.db);

  Future<AssetDescargado?> getEstado(String tipo, int refId) =>
      (select(assetsDescargados)
            ..where((t) => t.tipo.equals(tipo) & t.refId.equals(refId)))
          .getSingleOrNull();

  /// Filas de un [tipo] para un conjunto de refIds, en lotes (límite de variables
  /// de SQLite). Solo las que existen. Lo usa la propagación PC→móvil para
  /// resetear portadas/fotos cuando el PC cambia el álbum/artista.
  Future<List<AssetDescargado>> getEstadosPorIds(
      String tipo, List<int> refIds) async {
    if (refIds.isEmpty) {
      return const <AssetDescargado>[];
    }
    final List<AssetDescargado> filas = <AssetDescargado>[];
    const int lote = 800;
    for (int i = 0; i < refIds.length; i += lote) {
      final int fin = (i + lote < refIds.length) ? i + lote : refIds.length;
      filas.addAll(await (select(assetsDescargados)
            ..where((t) =>
                t.tipo.equals(tipo) & t.refId.isIn(refIds.sublist(i, fin))))
          .get());
    }
    return filas;
  }

  Future<void> setEstado(String tipo, int refId, String estado) =>
      into(assetsDescargados).insertOnConflictUpdate(
        AssetsDescargadosCompanion.insert(
          tipo: tipo,
          refId: refId,
          estado: estado,
          actualizadoEn: DateTime.now().toUtc(),
        ),
      );

  Future<void> eliminar(String tipo, int refId) =>
      (delete(assetsDescargados)
            ..where((t) => t.tipo.equals(tipo) & t.refId.equals(refId)))
          .go();

  /// Ids de entidades cuyo asset [tipo] está descargado (`done`), reactivo.
  Stream<Set<int>> watchDescargados(String tipo) =>
      (select(assetsDescargados)
            ..where((t) => t.tipo.equals(tipo) & t.estado.equals('done')))
          .watch()
          .map((List<AssetDescargado> rows) =>
              rows.map((AssetDescargado r) => r.refId).toSet());

  /// Ids cuyo asset [tipo] está **resuelto** (`done` o `unavailable`/404),
  /// reactivo. Sirve para el cálculo de "pista completa": una portada inexistente
  /// (404) cuenta como resuelta, no como pendiente.
  Stream<Set<int>> watchResueltos(String tipo) =>
      (select(assetsDescargados)
            ..where((t) =>
                t.tipo.equals(tipo) &
                t.estado.isIn(<String>['done', 'unavailable'])))
          .watch()
          .map((List<AssetDescargado> rows) =>
              rows.map((AssetDescargado r) => r.refId).toSet());

  /// Conteo `{done, failed}` de imágenes del [tipo] (contadores de Descargas).
  Stream<ConteoAsset> watchConteo(String tipo) {
    final Expression<int> done = assetsDescargados.refId
        .count(filter: assetsDescargados.estado.equals('done'));
    final Expression<int> failed = assetsDescargados.refId
        .count(filter: assetsDescargados.estado.equals('failed'));
    final query = selectOnly(assetsDescargados)
      ..where(assetsDescargados.tipo.equals(tipo))
      ..addColumns(<Expression<Object>>[done, failed]);
    return query.watchSingle().map((TypedResult row) => ConteoAsset(
          done: row.read(done) ?? 0,
          failed: row.read(failed) ?? 0,
        ));
  }
}
