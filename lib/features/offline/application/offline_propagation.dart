import 'dart:io';

import '../../../data/db/daos/assets_dao.dart';
import '../../../data/db/database.dart';
import '../../sync/data/sync_repository.dart';
import '../data/download_repository.dart';
import '../data/offline_store.dart';

/// Propaga al estado offline los cambios que el PC reflejó en el último delta
/// (regla del usuario: "cambio que se hace en el PC, cambio que se refleja en el
/// móvil"). Dos efectos, ambos sobre media YA descargada:
///
/// - **Borrados reales** (tombstones): borra la media offline huérfana de la
///   entidad (audio/letra/karaoke de la pista; portada del álbum; foto del
///   artista) y sus filas de estado. El catálogo ya lo borró el sync.
/// - **Cambios** (entidades que llegaron con `sync_version` mayor): resetea el
///   estado de sus recursos descargados (`done`/`unavailable` → `none`) para que
///   la capa de descargas los vuelva a bajar con el contenido nuevo (p. ej. una
///   canción que no tenía portada/letra y ahora sí, o un karaoke recién generado).
///
/// El audio principal NO se resetea ante un cambio de metadata: el archivo rara
/// vez cambia en un re-etiquetado (solo la fila del catálogo) y rebajarlo en cada
/// cambio sería caro; un mismatch de hash ya se trata de forma no fatal.
class OfflinePropagation {
  OfflinePropagation({
    required this.db,
    required this.store,
    required this.downloads,
  });

  final AppDatabase db;
  final OfflineStore store;
  final DownloadRepository downloads;

  /// Aplica la propagación del [resultado] de un sync. Devuelve las ids de pistas
  /// ya trackeadas offline que conviene **re-encolar** para rebajar lo reseteado
  /// (las que cambiaron y tenían descarga). Best-effort: un fallo de IO en un
  /// recurso no aborta el resto.
  Future<Set<int>> aplicar(SyncResult resultado) async {
    await _borrarTombstones(resultado);
    return _resetearCambios(resultado);
  }

  // ── Borrados reales ────────────────────────────────────────────────────────
  Future<void> _borrarTombstones(SyncResult r) async {
    for (final int pistaId in r.pistasBorradas) {
      // Borra audio/karaoke/letra + la fila de descarga. NO toca portada/foto
      // (se comparten entre pistas; se limpian con el tombstone de álbum/artista).
      await _ignorarIo(() => downloads.remove(pistaId));
    }
    for (final int albumId in r.albumsBorrados) {
      await _ignorarIo(() => _borrarArchivo(store.coverFile(albumId)));
      await _ignorarIo(() => db.assetsDao.eliminar(AssetTipo.cover, albumId));
    }
    for (final int artistaId in r.artistasBorrados) {
      await _ignorarIo(() => _borrarArchivo(store.artistFile(artistaId)));
      await _ignorarIo(() => db.assetsDao.eliminar(AssetTipo.artist, artistaId));
    }
  }

  // ── Cambios (reset de recursos ya descargados) ─────────────────────────────
  Future<Set<int>> _resetearCambios(SyncResult r) async {
    final Set<int> aReencolar = <int>{};

    // Pistas: portada/letra/karaoke pudieron cambiar. Solo se tocan las que YA
    // tienen fila de descarga (las trackeadas offline); las demás se bajarán
    // frescas cuando se encolen.
    if (r.pistasDelta.isNotEmpty) {
      final List<DescargaAudio> filas =
          await db.downloadsDao.getEstadosPorIds(r.pistasDelta);
      for (final DescargaAudio d in filas) {
        if (reseteable(d.lyricsEstado)) {
          await db.downloadsDao.setLyricsEstado(d.pistaId, DownloadEstado.none);
        }
        if (reseteable(d.stemsEstado)) {
          await db.downloadsDao.setStemsEstado(d.pistaId, DownloadEstado.none);
        }
        // Re-encolar: rebaja lo reseteado y revalida la portada de su álbum.
        aReencolar.add(d.pistaId);
      }
    }

    // Álbumes: la portada pudo cambiar/aparecer → resetear su asset descargado.
    await _resetearAssets(AssetTipo.cover, r.albumsDelta);
    // Artistas: la foto pudo cambiar/aparecer.
    await _resetearAssets(AssetTipo.artist, r.artistasDelta);

    return aReencolar;
  }

  Future<void> _resetearAssets(String tipo, List<int> refIds) async {
    if (refIds.isEmpty) {
      return;
    }
    final List<AssetDescargado> filas =
        await db.assetsDao.getEstadosPorIds(tipo, refIds);
    for (final AssetDescargado a in filas) {
      if (reseteable(a.estado)) {
        await db.assetsDao.setEstado(tipo, a.refId, DownloadEstado.none);
      }
    }
  }

  Future<void> _borrarArchivo(File file) async {
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> _ignorarIo(Future<void> Function() op) async {
    try {
      await op();
    } catch (_) {
      // Best-effort: un fallo de IO/BD en un recurso no aborta la propagación.
    }
  }
}

/// Un recurso es **reseteable** si ya quedó resuelto en una pasada anterior
/// (`done` = se bajó, o `unavailable` = el PC no lo tenía / 404). Al volver a
/// `none` la capa de descargas lo reintenta con el contenido nuevo del PC. Un
/// `failed` NO se resetea: ya lo reintenta `reintentarFallidas`; volverlo a `none`
/// lo sacaría de ese reintento. `none`/`pending`/`downloading` tampoco (no hay
/// nada resuelto que invalidar).
bool reseteable(String estado) =>
    estado == DownloadEstado.done || estado == DownloadEstado.unavailable;
