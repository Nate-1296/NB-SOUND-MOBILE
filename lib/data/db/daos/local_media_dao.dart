import 'package:drift/drift.dart';

import '../../../features/local_media/application/local_ids.dart';
import '../database.dart';
import '../tables.dart';

part 'local_media_dao.g.dart';

/// Acceso a la **música local del teléfono** dentro del catálogo compartido
/// (filas con `origen='local'`, ids negativos). Upsert del escaneo, limpieza de
/// pistas/álbumes/artistas que ya no existen, y dedupe contra lo sincronizado
/// (la del PC prima). Nunca toca filas `origen='pc'` (eso es del sync).
@DriftAccessor(
  tables: <Type>[
    Artistas,
    Albums,
    Pistas,
    PlaylistLocalPistas,
    FavoritosLocal,
    LocalMediaOcultas,
  ],
)
class LocalMediaDao extends DatabaseAccessor<AppDatabase>
    with _$LocalMediaDaoMixin {
  LocalMediaDao(super.db);

  /// Inserta/actualiza el resultado de un escaneo (artistas → álbumes → pistas,
  /// en ese orden por las referencias).
  Future<void> upsertLocal({
    required List<ArtistasCompanion> artistasLocales,
    required List<AlbumsCompanion> albumsLocales,
    required List<PistasCompanion> pistasLocales,
  }) async {
    await batch((Batch b) {
      b.insertAllOnConflictUpdate(artistas, artistasLocales);
      b.insertAllOnConflictUpdate(albums, albumsLocales);
      b.insertAllOnConflictUpdate(pistas, pistasLocales);
    });
  }

  /// Pistas por origen (`pc`/`local`), para el dedupe.
  Future<List<Pista>> pistasPorOrigen(String origen) =>
      (select(pistas)..where((t) => t.origen.equals(origen))).get();

  /// Lista reactiva de las pistas locales (ordenadas por título).
  Stream<List<Pista>> watchPistasLocales() => (select(pistas)
        ..where((t) => t.origen.equals(origenLocal))
        ..orderBy(<OrderClauseGenerator<$PistasTable>>[
          (t) => OrderingTerm(expression: t.titulo),
        ]))
      .watch();

  Stream<int> watchConteoLocales() {
    final Expression<int> count = pistas.id.count();
    final query = selectOnly(pistas)
      ..addColumns(<Expression<Object>>[count])
      ..where(pistas.origen.equals(origenLocal));
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  // ── Carátula local (rellenada en segundo plano) ──────────────────────────
  /// Pistas locales aún sin probar carátula (`coverPath IS NULL`).
  Future<List<Pista>> localesSinProbarCaratula({int limite = 80}) =>
      (select(pistas)
            ..where((t) => t.origen.equals(origenLocal) & t.coverPath.isNull())
            ..limit(limite))
          .get();

  /// Fija el `coverPath` de varias pistas (esquema `localart://id` si hay
  /// carátula, o `''` si se probó y no hay → no se vuelve a probar).
  Future<void> fijarCoverLocal(Map<int, String> porPista) async {
    await batch((Batch b) {
      porPista.forEach((int id, String path) {
        b.update(
          pistas,
          PistasCompanion(coverPath: Value<String>(path)),
          where: ($PistasTable t) => t.id.equals(id),
        );
      });
    });
  }

  // ── Ocultar / mostrar (música local que sigue en el teléfono) ────────────
  /// Ids de MediaStore ocultados por el usuario (el escaneo los salta).
  Future<Set<int>> idsOcultos() async {
    final List<LocalOcultaRow> rows = await select(localMediaOcultas).get();
    return <int>{for (final LocalOcultaRow r in rows) r.mediaId};
  }

  Stream<List<LocalOcultaRow>> watchOcultas() => (select(localMediaOcultas)
        ..orderBy(<OrderClauseGenerator<$LocalMediaOcultasTable>>[
          (t) => OrderingTerm(expression: t.titulo),
        ]))
      .watch();

  /// Oculta una pista local: la quita del catálogo (sin borrarla del teléfono) y
  /// la recuerda para no re-indexarla en futuros escaneos.
  Future<void> ocultarPista(int mediaId, String titulo, String? artista) async {
    await into(localMediaOcultas).insertOnConflictUpdate(
      LocalMediaOcultasCompanion.insert(
        mediaId: Value<int>(mediaId),
        titulo: titulo,
        artista: Value<String?>(artista),
        ocultadoEn: DateTime.now(),
      ),
    );
    await borrarPistasLocales(<int>[idLocalPista(mediaId)]);
    await limpiarHuerfanosLocales();
  }

  /// Revela una pista oculta (se re-indexa en el próximo escaneo).
  Future<void> mostrarPista(int mediaId) =>
      (delete(localMediaOcultas)..where((t) => t.mediaId.equals(mediaId))).go();

  /// Revela todas las pistas ocultas individualmente.
  Future<void> mostrarTodasOcultas() => delete(localMediaOcultas).go();

  /// Borra TODA la música local del catálogo (para "ocultar todas"; los
  /// archivos siguen en el teléfono y se re-indexan al desactivar el flag).
  Future<void> borrarTodaLocal() async {
    final List<Pista> locales = await pistasPorOrigen(origenLocal);
    await borrarPistasLocales(<int>[for (final Pista p in locales) p.id]);
    await limpiarHuerfanosLocales();
  }

  /// Ids de MediaStore (positivos) de las pistas locales ya indexadas.
  Future<Set<int>> mediaIdsIndexados() async {
    final List<Pista> locales = await pistasPorOrigen(origenLocal);
    return <int>{for (final Pista p in locales) mediaStoreIdDePista(p.id)};
  }

  Future<int> contarLocales() async {
    final Expression<int> count = pistas.id.count();
    final row = await (selectOnly(pistas)
          ..addColumns(<Expression<Object>>[count])
          ..where(pistas.origen.equals(origenLocal)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  /// Borra pistas locales por id (y sus referencias en playlists/favoritos).
  Future<void> borrarPistasLocales(List<int> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (delete(playlistLocalPistas)..where((t) => t.pistaId.isIn(ids))).go();
    await (delete(favoritosLocal)..where((t) => t.pistaId.isIn(ids))).go();
    await (delete(pistas)..where((t) => t.id.isIn(ids))).go();
  }

  /// Elimina álbumes/artistas locales que ya no tienen ninguna pista local.
  Future<void> limpiarHuerfanosLocales() async {
    final List<Pista> locales = await pistasPorOrigen(origenLocal);
    final List<int> albumIds = <int>[
      for (final Pista p in locales)
        if (p.albumId != null) p.albumId!,
    ];
    final List<int> artistaIds = <int>[
      for (final Pista p in locales)
        if (p.artistaId != null) p.artistaId!,
    ];
    // Borra los álbumes locales no referenciados. `isNotIn([])` es SQL inválido,
    // así que con la lista vacía se borran todos los locales.
    final albumDel = delete(albums)
      ..where((t) => albumIds.isEmpty
          ? t.origen.equals(origenLocal)
          : t.origen.equals(origenLocal) & t.id.isNotIn(albumIds));
    await albumDel.go();
    final artistaDel = delete(artistas)
      ..where((t) => artistaIds.isEmpty
          ? t.origen.equals(origenLocal)
          : t.origen.equals(origenLocal) & t.id.isNotIn(artistaIds));
    await artistaDel.go();
  }

  /// Remapea las referencias de una pista local [localId] a la sincronizada
  /// [pcId] (al deduplicar): mantiene la pertenencia a playlists locales y el
  /// favorito, ahora apuntando a la versión completa del PC. Ignora conflictos
  /// (si la playlist/favorito ya tenían la del PC).
  Future<void> remapReferencias(int localId, int pcId) async {
    final List<PlaylistLocalPista> memb = await (select(playlistLocalPistas)
          ..where((t) => t.pistaId.equals(localId)))
        .get();
    for (final PlaylistLocalPista m in memb) {
      await into(playlistLocalPistas).insert(
        PlaylistLocalPistasCompanion.insert(
          playlistId: m.playlistId,
          pistaId: pcId,
          posicion: m.posicion,
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
    final FavoritoEntry? fav = await (select(favoritosLocal)
          ..where((t) => t.pistaId.equals(localId)))
        .getSingleOrNull();
    if (fav != null && fav.esFavorita) {
      await into(favoritosLocal).insert(
        FavoritosLocalCompanion.insert(
          pistaId: Value<int>(pcId),
          esFavorita: Value(fav.esFavorita),
          actualizadoEn: fav.actualizadoEn,
          // El favorito de la pista del PC sí sube; lo marca el flujo normal.
          subido: const Value(false),
        ),
        mode: InsertMode.insertOrIgnore,
      );
    }
  }
}
