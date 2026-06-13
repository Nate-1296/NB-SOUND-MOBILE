import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'favorites_dao.g.dart';

/// Favoritos locales: fuente de verdad del móvil, con merge last-write-wins por
/// `actualizadoEn` (espejo del merge del PC en pc-contract §4.9).
@DriftAccessor(tables: <Type>[FavoritosLocal, Pistas])
class FavoritesDao extends DatabaseAccessor<AppDatabase>
    with _$FavoritesDaoMixin {
  FavoritesDao(super.db);

  /// Fija el estado de favorito. Solo aplica si [cuando] es más reciente que el
  /// timestamp ya almacenado (last-write-wins); marca la fila como no subida.
  Future<void> setFavorita(int pistaId, bool value, {DateTime? cuando}) async {
    final DateTime ts = (cuando ?? DateTime.now().toUtc());
    final FavoritoEntry? existing =
        await (select(favoritosLocal)..where((t) => t.pistaId.equals(pistaId)))
            .getSingleOrNull();
    if (existing != null && existing.actualizadoEn.isAfter(ts)) {
      return;
    }
    await into(favoritosLocal).insertOnConflictUpdate(
      FavoritosLocalCompanion.insert(
        pistaId: Value(pistaId),
        esFavorita: Value(value),
        actualizadoEn: ts,
        subido: const Value(false),
      ),
    );
  }

  Future<void> toggle(int pistaId) async {
    final bool actual = await esFavorita(pistaId);
    await setFavorita(pistaId, !actual);
  }

  /// Aplica el favorito que reporta el PC en el manifest (last-write-wins):
  /// solo si su timestamp es estrictamente más reciente que el local. Lo marca
  /// como subido (ya refleja el estado del PC).
  Future<void> applyRemote(
    int pistaId,
    bool value,
    DateTime actualizadaEn,
  ) async {
    final FavoritoEntry? existing =
        await (select(favoritosLocal)..where((t) => t.pistaId.equals(pistaId)))
            .getSingleOrNull();
    if (existing != null && !actualizadaEn.isAfter(existing.actualizadoEn)) {
      return;
    }
    await into(favoritosLocal).insertOnConflictUpdate(
      FavoritosLocalCompanion.insert(
        pistaId: Value(pistaId),
        esFavorita: Value(value),
        actualizadoEn: actualizadaEn,
        subido: const Value(true),
      ),
    );
  }

  Future<bool> esFavorita(int pistaId) async {
    final FavoritoEntry? row =
        await (select(favoritosLocal)..where((t) => t.pistaId.equals(pistaId)))
            .getSingleOrNull();
    return row?.esFavorita ?? false;
  }

  Stream<bool> watchEsFavorita(int pistaId) =>
      (select(favoritosLocal)..where((t) => t.pistaId.equals(pistaId)))
          .watchSingleOrNull()
          .map((row) => row?.esFavorita ?? false);

  Stream<Set<int>> watchFavoritasIds() =>
      (select(favoritosLocal)..where((t) => t.esFavorita.equals(true)))
          .watch()
          .map((rows) => rows.map((r) => r.pistaId).toSet());

  /// Pistas marcadas como favoritas, ordenadas por marca de tiempo descendente.
  Stream<List<Pista>> watchFavoritas() {
    final query = select(favoritosLocal).join(<Join<HasResultSet, dynamic>>[
      innerJoin(pistas, pistas.id.equalsExp(favoritosLocal.pistaId)),
    ])
      ..where(favoritosLocal.esFavorita.equals(true))
      ..orderBy(<OrderingTerm>[
        OrderingTerm(
          expression: favoritosLocal.actualizadoEn,
          mode: OrderingMode.desc,
        ),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(pistas)).toList());
  }

  /// Favoritos pendientes de subir al PC. Excluye ids negativos (música local
  /// del teléfono): jamás se relaciona con el PC/Connect.
  Future<List<FavoritoEntry>> noSubidos() => (select(favoritosLocal)
        ..where((t) => t.subido.equals(false) & t.pistaId.isBiggerThanValue(0)))
      .get();

  Future<void> marcarSubidos(List<int> pistaIds) =>
      (update(favoritosLocal)..where((t) => t.pistaId.isIn(pistaIds)))
          .write(const FavoritosLocalCompanion(subido: Value(true)));
}
