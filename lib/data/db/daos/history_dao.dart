import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'history_dao.g.dart';

/// Historial de reproducción: fuente de verdad local (append + subida).
@DriftAccessor(tables: <Type>[HistorialLocal, Pistas])
class HistoryDao extends DatabaseAccessor<AppDatabase> with _$HistoryDaoMixin {
  HistoryDao(super.db);

  /// Registra una reproducción (timestamp en UTC, espejo del contrato).
  Future<void> registrarReproduccion(
    int pistaId, {
    bool completada = false,
    double? duracionSeg,
  }) {
    return into(historialLocal).insert(
      HistorialLocalCompanion.insert(
        pistaId: pistaId,
        reproducidoEn: DateTime.now().toUtc(),
        completada: Value(completada),
        duracionSeg: Value(duracionSeg),
      ),
    );
  }

  /// Últimas [limit] pistas distintas reproducidas, de más reciente a más vieja.
  Stream<List<Pista>> watchRecientes({int limit = 12}) {
    final query = select(historialLocal).join(<Join<HasResultSet, dynamic>>[
      innerJoin(pistas, pistas.id.equalsExp(historialLocal.pistaId)),
    ])
      ..orderBy(<OrderingTerm>[
        OrderingTerm(
          expression: historialLocal.reproducidoEn,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(limit * 4);
    return query.watch().map((rows) {
      final seen = <int>{};
      final out = <Pista>[];
      for (final r in rows) {
        final pista = r.readTable(pistas);
        if (seen.add(pista.id)) {
          out.add(pista);
        }
        if (out.length >= limit) {
          break;
        }
      }
      return out;
    });
  }

  /// Entradas aún no subidas al PC (para la tanda de sync).
  Future<List<HistorialEntry>> noSubidos() =>
      (select(historialLocal)..where((t) => t.subido.equals(false))).get();

  Future<void> marcarSubidos(List<int> ids) =>
      (update(historialLocal)..where((t) => t.id.isIn(ids)))
          .write(const HistorialLocalCompanion(subido: Value(true)));
}
