import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/security/secure_store.dart';
import '../../../data/db/daos/catalog_dao.dart';
import '../../../data/db/daos/local_playlists_dao.dart';
import '../../../data/db/database.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/data/download_repository.dart';

/// Materializa a disco las portadas que forman el mosaico de una playlist, para
/// que en aperturas siguientes se resuelvan como archivos locales (instantáneo) en
/// vez de pedirse al PC cada vez (lo que el usuario veía como "se cargan las
/// portadas" al entrar). Es best-effort e idempotente: cada portada se baja una
/// sola vez (la capa offline ya evita repetir las `done`/`unavailable`).
class PlaylistCoverPrefetcher {
  PlaylistCoverPrefetcher(this._repo, this._store);

  final DownloadRepository _repo;
  final SecureStore _store;

  /// Álbumes ya pedidos en esta sesión (evita relanzar trabajo en cada rebuild).
  final Set<int> _pedidos = <int>{};

  /// Asegura en local las portadas de los ≤4 álbumes distintos de [pistas]
  /// (los que componen el mosaico). No bloquea la UI: se llama y se olvida.
  Future<void> asegurarParaPistas(List<Pista> pistas) async {
    final List<int> albumIds = _albumesMosaico(pistas);
    if (albumIds.isEmpty) {
      return;
    }
    final PairedPc? pc = await _store.readPairing();
    if (pc == null) {
      // Sin PC: permite reintentar al reconectar.
      _pedidos.removeAll(albumIds);
      return;
    }
    await _asegurar(pc, albumIds);
  }

  /// Prefetch **inicial** de TODAS las playlists (del PC + locales): asegura sus
  /// portadas de mosaico en local para que la pestaña Playlists (y los accesos
  /// rápidos del Inicio) salgan instantáneos ya en la primera apertura, sin
  /// esperar a que cada tarjeta se dibuje. Lee el emparejamiento una sola vez;
  /// idempotente, secuencial y best-effort (pensado para correr en segundo plano).
  Future<void> prefetchPlaylists(
    CatalogDao catalog,
    LocalPlaylistsDao local,
  ) async {
    final PairedPc? pc = await _store.readPairing();
    if (pc == null) {
      return;
    }
    final List<Playlist> pcPlaylists = await catalog.watchPlaylists().first;
    for (final Playlist pl in pcPlaylists) {
      final List<Pista> pistas =
          await catalog.watchPistasDePlaylist(pl.id).first;
      await _asegurar(pc, _albumesMosaico(pistas));
    }
    final List<PlaylistLocal> locales = await local.watchPlaylists().first;
    for (final PlaylistLocal pl in locales) {
      final List<Pista> pistas = await local.watchPistas(pl.id).first;
      await _asegurar(pc, _albumesMosaico(pistas));
    }
  }

  /// Ids de los ≤4 álbumes distintos que componen el mosaico de [pistas], filtrando
  /// los ya pedidos en esta sesión (idempotencia entre llamadas).
  List<int> _albumesMosaico(List<Pista> pistas) {
    final List<int> albumIds = <int>[];
    final Set<int> vistos = <int>{};
    for (final Pista p in pistas) {
      final int? a = p.albumId;
      if (a != null && vistos.add(a) && _pedidos.add(a)) {
        albumIds.add(a);
      }
      if (vistos.length >= 4) {
        break;
      }
    }
    return albumIds;
  }

  Future<void> _asegurar(PairedPc pc, List<int> albumIds) async {
    for (final int id in albumIds) {
      try {
        await _repo.ensureCover(pc, id);
      } catch (_) {
        // Best-effort: si falla, se reintenta en otra sesión.
        _pedidos.remove(id);
      }
    }
  }
}

final Provider<PlaylistCoverPrefetcher> playlistCoverPrefetcherProvider =
    Provider<PlaylistCoverPrefetcher>(
  (Ref ref) => PlaylistCoverPrefetcher(
    ref.watch(downloadRepositoryProvider),
    ref.watch(secureStoreProvider),
  ),
);
