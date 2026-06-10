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

  /// Pistas **más escuchadas** (por nº de reproducciones), de más a menos.
  Stream<List<Pista>> watchMasEscuchadas({int limit = 12}) {
    final Expression<int> conteo = historialLocal.id.count();
    final query = select(historialLocal).join(<Join<HasResultSet, dynamic>>[
      innerJoin(pistas, pistas.id.equalsExp(historialLocal.pistaId)),
    ])
      ..addColumns(<Expression<Object>>[conteo])
      ..groupBy(<Expression<Object>>[historialLocal.pistaId])
      ..orderBy(<OrderingTerm>[
        OrderingTerm(expression: conteo, mode: OrderingMode.desc),
      ])
      ..limit(limit);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(pistas)).toList());
  }

  /// Nº de reproducciones por artista (artistaId → conteo), para derivar los
  /// artistas más escuchados del usuario. Solo cuenta pistas con artista.
  Stream<Map<int, int>> watchConteoPorArtista() {
    final Expression<int> conteo = historialLocal.id.count();
    final query = selectOnly(historialLocal).join(<Join<HasResultSet, dynamic>>[
      innerJoin(pistas, pistas.id.equalsExp(historialLocal.pistaId)),
    ])
      ..addColumns(<Expression<Object>>[pistas.artistaId, conteo])
      ..where(pistas.artistaId.isNotNull())
      ..groupBy(<Expression<Object>>[pistas.artistaId]);
    return query.watch().map((rows) {
      final Map<int, int> out = <int, int>{};
      for (final row in rows) {
        final int? aid = row.read(pistas.artistaId);
        final int? c = row.read(conteo);
        if (aid != null && c != null) {
          out[aid] = c;
        }
      }
      return out;
    });
  }

  /// Nº de reproducciones por pista (pistaId → conteo), para ordenar "Populares"
  /// (p. ej. en la página de artista). Reactivo.
  Stream<Map<int, int>> watchConteoPorPista() {
    final Expression<int> conteo = historialLocal.id.count();
    final query = selectOnly(historialLocal)
      ..addColumns(<Expression<Object>>[historialLocal.pistaId, conteo])
      ..groupBy(<Expression<Object>>[historialLocal.pistaId]);
    return query.watch().map((List<TypedResult> rows) => <int, int>{
          for (final TypedResult row in rows)
            row.read(historialLocal.pistaId)!: row.read(conteo) ?? 0,
        });
  }

  /// Entradas aún no subidas al PC (para la tanda de sync).
  Future<List<HistorialEntry>> noSubidos() =>
      (select(historialLocal)..where((t) => t.subido.equals(false))).get();

  Future<void> marcarSubidos(List<int> ids) =>
      (update(historialLocal)..where((t) => t.id.isIn(ids)))
          .write(const HistorialLocalCompanion(subido: Value(true)));
}
