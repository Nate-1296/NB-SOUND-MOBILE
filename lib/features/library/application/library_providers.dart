import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/database.dart';

// Providers de solo lectura sobre la réplica de catálogo (reactivos vía Drift).

final StreamProvider<List<Album>> albumsProvider =
    StreamProvider<List<Album>>((Ref ref) {
  return ref.watch(catalogDaoProvider).watchAlbums();
});

final StreamProvider<List<Artista>> artistasProvider =
    StreamProvider<List<Artista>>((Ref ref) {
  return ref.watch(catalogDaoProvider).watchArtistas();
});

final StreamProvider<List<Pista>> pistasProvider =
    StreamProvider<List<Pista>>((Ref ref) {
  return ref.watch(catalogDaoProvider).watchPistas();
});

final StreamProvider<List<Playlist>> playlistsProvider =
    StreamProvider<List<Playlist>>((Ref ref) {
  return ref.watch(catalogDaoProvider).watchPlaylists();
});

/// Ids de las playlists del PC que el usuario guardó/sigue (reactivo).
final StreamProvider<Set<int>> playlistsGuardadasIdsProvider =
    StreamProvider<Set<int>>((Ref ref) {
  return ref.watch(followedPlaylistsDaoProvider).watchGuardadasIds();
});

/// Playlists del PC **guardadas** (viven en "Tus playlists"). Conserva el orden
/// de [playlistsProvider] (alfabético).
final Provider<List<Playlist>> playlistsGuardadasProvider =
    Provider<List<Playlist>>((Ref ref) {
  final List<Playlist> todas =
      ref.watch(playlistsProvider).value ?? const <Playlist>[];
  final Set<int> guardadas =
      ref.watch(playlistsGuardadasIdsProvider).value ?? const <int>{};
  return <Playlist>[
    for (final Playlist p in todas)
      if (guardadas.contains(p.id)) p,
  ];
});

/// Playlists del PC **no guardadas** (sección "Del PC").
final Provider<List<Playlist>> playlistsDelPcNoGuardadasProvider =
    Provider<List<Playlist>>((Ref ref) {
  final List<Playlist> todas =
      ref.watch(playlistsProvider).value ?? const <Playlist>[];
  final Set<int> guardadas =
      ref.watch(playlistsGuardadasIdsProvider).value ?? const <int>{};
  return <Playlist>[
    for (final Playlist p in todas)
      if (!guardadas.contains(p.id)) p,
  ];
});

/// True si la playlist del PC [id] está guardada (reactivo).
final playlistGuardadaProvider = Provider.family<bool, int>((Ref ref, int id) {
  return (ref.watch(playlistsGuardadasIdsProvider).value ?? const <int>{})
      .contains(id);
});

final StreamProvider<List<Pista>> recientesProvider =
    StreamProvider<List<Pista>>((Ref ref) {
  return ref.watch(historyDaoProvider).watchRecientes();
});

final StreamProvider<List<Pista>> favoritasProvider =
    StreamProvider<List<Pista>>((Ref ref) {
  return ref.watch(favoritesDaoProvider).watchFavoritas();
});

final StreamProvider<Set<int>> favoritasIdsProvider =
    StreamProvider<Set<int>>((Ref ref) {
  return ref.watch(favoritesDaoProvider).watchFavoritasIds();
});

// ── Detalle ────────────────────────────────────────────────────────────────
final albumProvider =
    FutureProvider.family<Album?, int>((Ref ref, int id) {
  return ref.watch(catalogDaoProvider).getAlbum(id);
});

final artistaProvider =
    FutureProvider.family<Artista?, int>((Ref ref, int id) {
  return ref.watch(catalogDaoProvider).getArtista(id);
});

final playlistProvider =
    FutureProvider.family<Playlist?, int>((Ref ref, int id) {
  return ref.watch(catalogDaoProvider).getPlaylist(id);
});

final pistasDeAlbumProvider =
    StreamProvider.family<List<Pista>, int>((Ref ref, int albumId) {
  return ref.watch(catalogDaoProvider).watchPistasDeAlbum(albumId);
});

final pistasDeArtistaProvider =
    StreamProvider.family<List<Pista>, int>((Ref ref, int artistaId) {
  return ref.watch(catalogDaoProvider).watchPistasDeArtista(artistaId);
});

final albumsDeArtistaProvider =
    StreamProvider.family<List<Album>, int>((Ref ref, int artistaId) {
  return ref.watch(catalogDaoProvider).watchAlbumsDeArtista(artistaId);
});

final pistasDePlaylistProvider =
    StreamProvider.family<List<Pista>, int>((Ref ref, int playlistId) {
  return ref.watch(catalogDaoProvider).watchPistasDePlaylist(playlistId);
});

// ── Playlists locales (del teléfono, editables) ──────────────────────────────
final StreamProvider<List<PlaylistLocal>> playlistsLocalesProvider =
    StreamProvider<List<PlaylistLocal>>((Ref ref) {
  return ref.watch(localPlaylistsDaoProvider).watchPlaylists();
});

final StreamProvider<Map<int, int>> conteosPlaylistsLocalesProvider =
    StreamProvider<Map<int, int>>((Ref ref) {
  return ref.watch(localPlaylistsDaoProvider).watchConteos();
});

final playlistLocalProvider =
    StreamProvider.family<PlaylistLocal?, int>((Ref ref, int id) {
  return ref.watch(localPlaylistsDaoProvider).watchPlaylist(id);
});

final pistasDePlaylistLocalProvider =
    StreamProvider.family<List<Pista>, int>((Ref ref, int playlistId) {
  return ref.watch(localPlaylistsDaoProvider).watchPistas(playlistId);
});

// ── Búsqueda ─────────────────────────────────────────────────────────────
class BusquedaQuery extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final NotifierProvider<BusquedaQuery, String> busquedaQueryProvider =
    NotifierProvider<BusquedaQuery, String>(BusquedaQuery.new);

final StreamProvider<List<Pista>> resultadosBusquedaProvider =
    StreamProvider<List<Pista>>((Ref ref) {
  final String q = ref.watch(busquedaQueryProvider).trim();
  if (q.isEmpty) {
    return Stream<List<Pista>>.value(const <Pista>[]);
  }
  return ref.watch(catalogDaoProvider).buscarPistas(q);
});
