import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'local_playlists_dao.g.dart';

/// CRUD de playlists locales del teléfono (editables; no se sincronizan al PC).
@DriftAccessor(tables: <Type>[PlaylistsLocales, PlaylistLocalPistas, Pistas])
class LocalPlaylistsDao extends DatabaseAccessor<AppDatabase>
    with _$LocalPlaylistsDaoMixin {
  LocalPlaylistsDao(super.db);

  // ── Lectura reactiva ─────────────────────────────────────────────────────
  Stream<List<PlaylistLocal>> watchPlaylists() =>
      (select(playlistsLocales)..orderBy(<OrderClauseGenerator<$PlaylistsLocalesTable>>[
        (t) => OrderingTerm(expression: t.actualizadoEn, mode: OrderingMode.desc),
      ])).watch();

  Stream<PlaylistLocal?> watchPlaylist(int id) =>
      (select(playlistsLocales)..where((t) => t.id.equals(id)))
          .watchSingleOrNull();

  /// Pistas de la playlist en su orden de posición.
  Stream<List<Pista>> watchPistas(int playlistId) {
    final query = select(playlistLocalPistas).join(<Join<HasResultSet, dynamic>>[
      innerJoin(pistas, pistas.id.equalsExp(playlistLocalPistas.pistaId)),
    ])
      ..where(playlistLocalPistas.playlistId.equals(playlistId))
      ..orderBy(<OrderingTerm>[
        OrderingTerm(expression: playlistLocalPistas.posicion),
      ]);
    return query
        .watch()
        .map((rows) => rows.map((r) => r.readTable(pistas)).toList());
  }

  /// Conteo de pistas por playlist local (para la rejilla).
  Stream<Map<int, int>> watchConteos() {
    final count = playlistLocalPistas.pistaId.count();
    final query = selectOnly(playlistLocalPistas)
      ..addColumns(<Expression<Object>>[playlistLocalPistas.playlistId, count])
      ..groupBy(<Expression<Object>>[playlistLocalPistas.playlistId]);
    return query.watch().map((rows) => <int, int>{
          for (final row in rows)
            row.read(playlistLocalPistas.playlistId)!: row.read(count) ?? 0,
        });
  }

  // ── Mutaciones ───────────────────────────────────────────────────────────
  Future<int> crear(String nombre) {
    final DateTime now = DateTime.now().toUtc();
    return into(playlistsLocales).insert(
      PlaylistsLocalesCompanion.insert(
        nombre: nombre,
        creadoEn: now,
        actualizadoEn: now,
      ),
    );
  }

  Future<void> renombrar(int id, String nombre) =>
      (update(playlistsLocales)..where((t) => t.id.equals(id))).write(
        PlaylistsLocalesCompanion(
          nombre: Value(nombre),
          actualizadoEn: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> borrar(int id) async {
    await (delete(playlistLocalPistas)..where((t) => t.playlistId.equals(id)))
        .go();
    await (delete(playlistsLocales)..where((t) => t.id.equals(id))).go();
  }

  /// Añade una pista al final (idempotente: si ya está, no duplica).
  Future<void> anadirPista(int playlistId, int pistaId) async {
    final yaEsta = await (select(playlistLocalPistas)
          ..where((t) =>
              t.playlistId.equals(playlistId) & t.pistaId.equals(pistaId)))
        .getSingleOrNull();
    if (yaEsta != null) {
      return;
    }
    final count = playlistLocalPistas.posicion.max();
    final row = await (selectOnly(playlistLocalPistas)
          ..addColumns(<Expression<Object>>[count])
          ..where(playlistLocalPistas.playlistId.equals(playlistId)))
        .getSingleOrNull();
    final int siguiente = (row?.read(count) ?? -1) + 1;
    await into(playlistLocalPistas).insert(
      PlaylistLocalPistasCompanion.insert(
        playlistId: playlistId,
        pistaId: pistaId,
        posicion: siguiente,
      ),
    );
    await _tocar(playlistId);
  }

  Future<void> quitarPista(int playlistId, int pistaId) async {
    await (delete(playlistLocalPistas)
          ..where((t) =>
              t.playlistId.equals(playlistId) & t.pistaId.equals(pistaId)))
        .go();
    await _renumerar(playlistId);
    await _tocar(playlistId);
  }

  /// Reordena: [pistaIds] en el nuevo orden (posición = índice).
  Future<void> reordenar(int playlistId, List<int> pistaIds) async {
    await batch((Batch b) {
      for (int i = 0; i < pistaIds.length; i++) {
        b.update(
          playlistLocalPistas,
          PlaylistLocalPistasCompanion(posicion: Value(i)),
          where: (t) =>
              t.playlistId.equals(playlistId) & t.pistaId.equals(pistaIds[i]),
        );
      }
    });
    await _tocar(playlistId);
  }

  /// Renumera las posiciones a 0..n-1 conservando el orden (tras un borrado).
  Future<void> _renumerar(int playlistId) async {
    final filas = await (select(playlistLocalPistas)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy(<OrderClauseGenerator<$PlaylistLocalPistasTable>>[
            (t) => OrderingTerm(expression: t.posicion),
          ]))
        .get();
    await batch((Batch b) {
      for (int i = 0; i < filas.length; i++) {
        b.update(
          playlistLocalPistas,
          PlaylistLocalPistasCompanion(posicion: Value(i)),
          where: (t) =>
              t.playlistId.equals(playlistId) &
              t.pistaId.equals(filas[i].pistaId),
        );
      }
    });
  }

  Future<void> _tocar(int playlistId) =>
      (update(playlistsLocales)..where((t) => t.id.equals(playlistId))).write(
        PlaylistsLocalesCompanion(
          actualizadoEn: Value(DateTime.now().toUtc()),
        ),
      );
}
