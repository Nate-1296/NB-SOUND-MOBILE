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

// ── Inicio dinámico (refleja gustos + selecciones del catálogo) ───────────────
final StreamProvider<List<Pista>> masEscuchadasProvider =
    StreamProvider<List<Pista>>((Ref ref) {
  return ref.watch(historyDaoProvider).watchMasEscuchadas();
});

final StreamProvider<Map<int, int>> conteoPorArtistaProvider =
    StreamProvider<Map<int, int>>((Ref ref) {
  return ref.watch(historyDaoProvider).watchConteoPorArtista();
});

/// Artistas más escuchados del usuario. Si aún no hay historial, cae a una
/// muestra del catálogo para que la sección no quede vacía en un teléfono nuevo.
final Provider<List<Artista>> topArtistasProvider =
    Provider<List<Artista>>((Ref ref) {
  final List<Artista> artistas =
      ref.watch(artistasProvider).value ?? const <Artista>[];
  if (artistas.isEmpty) {
    return const <Artista>[];
  }
  final Map<int, int> conteo =
      ref.watch(conteoPorArtistaProvider).value ?? const <int, int>{};
  if (conteo.isEmpty) {
    return artistas.take(12).toList();
  }
  final Map<int, Artista> porId = <int, Artista>{
    for (final Artista a in artistas) a.id: a,
  };
  final List<int> ids = conteo.keys.toList()
    ..sort((int a, int b) => conteo[b]!.compareTo(conteo[a]!));
  final List<Artista> top = <Artista>[
    for (final int id in ids)
      if (porId[id] case final Artista a) a,
  ];
  return top.take(12).toList();
});

/// Álbumes más recientes por año (novedades).
final Provider<List<Album>> novedadesAlbumsProvider =
    Provider<List<Album>>((Ref ref) {
  final List<Album> albums =
      ref.watch(albumsProvider).value ?? const <Album>[];
  final List<Album> conAnio = <Album>[
    for (final Album a in albums)
      if (a.anio != null) a,
  ]..sort((Album a, Album b) => b.anio!.compareTo(a.anio!));
  return conAnio.take(12).toList();
});

/// Álbumes más antiguos por año (clásicos).
final Provider<List<Album>> clasicosAlbumsProvider =
    Provider<List<Album>>((Ref ref) {
  final List<Album> albums =
      ref.watch(albumsProvider).value ?? const <Album>[];
  final List<Album> conAnio = <Album>[
    for (final Album a in albums)
      if (a.anio != null) a,
  ]..sort((Album a, Album b) => a.anio!.compareTo(b.anio!));
  return conAnio.take(12).toList();
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

// La búsqueda principal (difusa, multi-tipo) vive en `search_providers.dart`
// (`resultadosBusquedaProvider`). Aquí solo queda el estado de la query.
