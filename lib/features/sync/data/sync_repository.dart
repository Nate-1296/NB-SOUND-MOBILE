import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/security/secure_store.dart';
import '../../../core/utils/time.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../data/db/database.dart';
import '../../../data/models/history_dto.dart';
import '../../../data/models/manifest_dto.dart';
import 'seleccion_dto.dart';
import 'sync_mappers.dart';

/// Resultado de una sincronización.
class SyncResult {
  const SyncResult({
    required this.syncVersion,
    required this.pistas,
    required this.albums,
    required this.artistas,
    required this.playlists,
    required this.tombstones,
    required this.historialSubido,
    required this.favoritosSubidos,
  });

  final int syncVersion;
  final int pistas;
  final int albums;
  final int artistas;
  final int playlists;
  final int tombstones;
  final int historialSubido;
  final int favoritosSubidos;

  int get totalEntidades => pistas + albums + artistas + playlists;
}

/// Cliente del protocolo de sync (docs/pc-contract.md §4.3–4.4, §4.9):
/// manifest delta paginado + subida de historial/favoritos + selección.
class SyncRepository {
  SyncRepository({required this.db, required this.dioFor});

  final AppDatabase db;
  final Dio Function(PairedPc pc) dioFor;

  /// Sync completo: baja el manifest delta y sube los cambios locales.
  Future<SyncResult> sync(PairedPc pc, {int pageLimit = 500}) async {
    final _PullStats pull = await _pullManifest(pc, pageLimit: pageLimit);
    final HistoryUploadResponse push = await _pushHistory(pc);
    return SyncResult(
      syncVersion: pull.syncVersion,
      pistas: pull.pistas,
      albums: pull.albums,
      artistas: pull.artistas,
      playlists: pull.playlists,
      tombstones: pull.tombstones,
      historialSubido: push.historialInsertado,
      favoritosSubidos: push.favoritosAplicados,
    );
  }

  // ── Manifest delta (paginado, transaccional, reanudable) ─────────────────
  Future<_PullStats> _pullManifest(PairedPc pc, {required int pageLimit}) async {
    final Dio dio = dioFor(pc);
    int since = await db.syncStateDao.getUltimaSyncVersion();
    final _PullStats stats = _PullStats();

    while (true) {
      final Response<dynamic> res = await dio.get<dynamic>(
        '/api/v1/manifest',
        queryParameters: <String, dynamic>{'since': since, 'limit': pageLimit},
      );
      final ManifestDto m = ManifestDto.fromJson(_asMap(res.data));
      await _applyPage(m);
      stats.add(m);

      if (m.hasMore) {
        // Avanza el cursor; NO se persiste ultima_sync_version hasta el final
        // (reanudable: si una página falla, se reintenta desde el mismo since).
        since = m.nextSince;
      } else {
        await db.syncStateDao.setUltimaSyncVersion(m.syncVersionActual);
        stats.syncVersion = m.syncVersionActual;
        return stats;
      }
    }
  }

  /// Aplica una página del manifest en una transacción (atómica por lote).
  Future<void> _applyPage(ManifestDto m) async {
    await db.transaction(() async {
      if (m.artistas.isNotEmpty) {
        await db.catalogDao
            .upsertArtistas(m.artistas.map(toArtistaCompanion).toList());
      }
      if (m.albums.isNotEmpty) {
        await db.catalogDao.upsertAlbums(m.albums.map(toAlbumCompanion).toList());
      }
      if (m.pistas.isNotEmpty) {
        await db.catalogDao.upsertPistas(m.pistas.map(toPistaCompanion).toList());
      }
      for (final PlaylistDto pl in m.playlists) {
        await db.catalogDao
            .upsertPlaylists(<PlaylistsCompanion>[toPlaylistCompanion(pl)]);
        await db.catalogDao.replacePlaylistPistas(pl.id, toPlaylistPistas(pl));
      }
      for (final TombstoneDto t in m.tombstones) {
        await _applyTombstone(t);
      }
      // Reconciliación de favoritos: el PC gana si su timestamp es posterior.
      for (final PistaDto p in m.pistas) {
        final DateTime? ts = parseIsoUtc(p.favoritaActualizadaEn);
        if (ts != null) {
          await db.favoritesDao.applyRemote(p.id, p.favorita, ts);
        }
      }
      // Perfil del PC (solo lectura): se guarda como JSON para mostrarlo.
      final PerfilDto? perfil = m.perfil;
      if (perfil != null) {
        await db.syncStateDao.setValor(
          SyncStateDao.kPerfil,
          jsonEncode(<String, dynamic>{
            'nombre': perfil.nombre,
            'total_pistas': perfil.estadisticas?.totalPistas ?? 0,
            'total_favoritas': perfil.estadisticas?.totalFavoritas ?? 0,
          }),
        );
      }
    });
  }

  Future<void> _applyTombstone(TombstoneDto t) async {
    switch (t.entidad) {
      case 'pista':
        await db.catalogDao.deletePista(t.entidadId);
      case 'album':
        await db.catalogDao.deleteAlbum(t.entidadId);
      case 'artista':
        await db.catalogDao.deleteArtista(t.entidadId);
      case 'playlist':
        await db.catalogDao.deletePlaylist(t.entidadId);
    }
  }

  // ── Subida de historial + favoritos (POST /history) ──────────────────────
  Future<HistoryUploadResponse> _pushHistory(PairedPc pc) async {
    final List<HistorialEntry> hist = await db.historyDao.noSubidos();
    final List<FavoritoEntry> favs = await db.favoritesDao.noSubidos();
    if (hist.isEmpty && favs.isEmpty) {
      return const HistoryUploadResponse(ok: true);
    }

    final HistoryUploadRequest req = HistoryUploadRequest(
      historial: <HistorialItemDto>[
        for (final HistorialEntry h in hist)
          HistorialItemDto(
            pistaId: h.pistaId,
            reproducidoEn: isoUtc(h.reproducidoEn),
            duracionSeg: h.duracionSeg,
            completada: h.completada,
          ),
      ],
      favoritos: <FavoritoItemDto>[
        for (final FavoritoEntry f in favs)
          FavoritoItemDto(
            pistaId: f.pistaId,
            favorita: f.esFavorita,
            actualizadaEn: isoUtc(f.actualizadoEn),
          ),
      ],
    );

    final Response<dynamic> res = await dioFor(pc)
        .post<dynamic>('/api/v1/history', data: req.toJson());
    final HistoryUploadResponse resp =
        HistoryUploadResponse.fromJson(_asMap(res.data));
    if (resp.ok) {
      await db.historyDao
          .marcarSubidos(<int>[for (final HistorialEntry h in hist) h.id]);
      await db.favoritesDao
          .marcarSubidos(<int>[for (final FavoritoEntry f in favs) f.pistaId]);
    }
    return resp;
  }

  // ── Selección de sync (qué metadata entra; docs §4.4) ────────────────────
  Future<SeleccionDto> getSeleccion(PairedPc pc) async {
    final Response<dynamic> res =
        await dioFor(pc).get<dynamic>('/api/v1/seleccion');
    return SeleccionDto.fromJson(_unwrapSeleccion(_asMap(res.data)));
  }

  Future<SeleccionDto> setSeleccion(PairedPc pc, SeleccionDto seleccion) async {
    final Response<dynamic> res = await dioFor(pc).post<dynamic>(
      '/api/v1/seleccion',
      data: <String, dynamic>{'seleccion': seleccion.toJson()},
    );
    return SeleccionDto.fromJson(_unwrapSeleccion(_asMap(res.data)));
  }

  static Map<String, dynamic> _unwrapSeleccion(Map<String, dynamic> data) {
    final Object? inner = data['seleccion'];
    return inner is Map<String, dynamic> ? inner : data;
  }

  static Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};
}

class _PullStats {
  int syncVersion = 0;
  int pistas = 0;
  int albums = 0;
  int artistas = 0;
  int playlists = 0;
  int tombstones = 0;

  void add(ManifestDto m) {
    pistas += m.pistas.length;
    albums += m.albums.length;
    artistas += m.artistas.length;
    playlists += m.playlists.length;
    tombstones += m.tombstones.length;
  }
}
