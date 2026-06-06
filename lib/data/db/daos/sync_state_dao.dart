import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'sync_state_dao.g.dart';

/// Estado de sincronización (pares clave/valor). Clave canónica:
/// `ultima_sync_version` (high-water mark del último manifest aplicado).
@DriftAccessor(tables: <Type>[SyncEstado])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  static const String kUltimaSyncVersion = 'ultima_sync_version';

  /// Perfil del PC (JSON: nombre + estadísticas), guardado en cada sync.
  static const String kPerfil = 'perfil';

  Future<String?> getValor(String clave) async {
    final SyncEstadoEntry? row =
        await (select(syncEstado)..where((t) => t.clave.equals(clave)))
            .getSingleOrNull();
    return row?.valor;
  }

  Future<void> setValor(String clave, String valor) =>
      into(syncEstado).insertOnConflictUpdate(
        SyncEstadoCompanion.insert(clave: clave, valor: valor),
      );

  Future<int> getUltimaSyncVersion() async =>
      int.tryParse(await getValor(kUltimaSyncVersion) ?? '') ?? 0;

  Future<void> setUltimaSyncVersion(int version) =>
      setValor(kUltimaSyncVersion, '$version');
}
