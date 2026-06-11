import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/search/fuzzy.dart';
import '../../../data/db/database.dart';
import 'library_providers.dart';
import 'search_providers.dart';

// Búsqueda + orden por sección de la Biblioteca (y Playlists), con el orden
// elegido **persistido** por sección (sobrevive reinicios) y limpiable. La
// búsqueda es difusa pero precisa (da lo que buscas o algo muy similar, sin
// recomendaciones): umbral más alto que la búsqueda principal.

/// Umbral de coincidencia para los buscadores de biblioteca (más estricto que la
/// búsqueda principal: tolera 1 typo, no subsecuencias laxas).
const double _umbralBiblioteca = 0.45;

// ── Criterios de orden ────────────────────────────────────────────────────────
enum OrdenAlbumes {
  tituloAsc,
  tituloDesc,
  anioDesc,
  anioAsc,
  masPistas,
  menosPistas;

  String get etiqueta => switch (this) {
        OrdenAlbumes.tituloAsc => 'Título A → Z',
        OrdenAlbumes.tituloDesc => 'Título Z → A',
        OrdenAlbumes.anioDesc => 'Más recientes',
        OrdenAlbumes.anioAsc => 'Más antiguos',
        OrdenAlbumes.masPistas => 'Más pistas',
        OrdenAlbumes.menosPistas => 'Menos pistas',
      };
}

enum OrdenArtistas {
  nombreAsc,
  nombreDesc,
  masPistas,
  menosPistas;

  String get etiqueta => switch (this) {
        OrdenArtistas.nombreAsc => 'Nombre A → Z',
        OrdenArtistas.nombreDesc => 'Nombre Z → A',
        OrdenArtistas.masPistas => 'Más pistas',
        OrdenArtistas.menosPistas => 'Menos pistas',
      };
}

enum OrdenPistas {
  tituloAsc,
  tituloDesc,
  artistaAsc,
  duracionDesc,
  duracionAsc,
  anioDesc,
  anioAsc;

  String get etiqueta => switch (this) {
        OrdenPistas.tituloAsc => 'Título A → Z',
        OrdenPistas.tituloDesc => 'Título Z → A',
        OrdenPistas.artistaAsc => 'Artista A → Z',
        OrdenPistas.duracionDesc => 'Mayor duración',
        OrdenPistas.duracionAsc => 'Menor duración',
        OrdenPistas.anioDesc => 'Más recientes',
        OrdenPistas.anioAsc => 'Más antiguos',
      };
}

enum OrdenPlaylists {
  nombreAsc,
  nombreDesc,
  masPistas,
  menosPistas;

  String get etiqueta => switch (this) {
        OrdenPlaylists.nombreAsc => 'Nombre A → Z',
        OrdenPlaylists.nombreDesc => 'Nombre Z → A',
        OrdenPlaylists.masPistas => 'Más pistas',
        OrdenPlaylists.menosPistas => 'Menos pistas',
      };
}

// ── Estado de orden persistido (uno por sección, independiente) ───────────────
abstract class _OrdenNotifier<T extends Enum> extends Notifier<T> {
  String get clave;
  List<T> get opciones;
  T get inicial;

  @override
  T build() {
    _cargar();
    return inicial;
  }

  Future<void> _cargar() async {
    final String? v = await ref.read(syncStateDaoProvider).getValor(clave);
    for (final T o in opciones) {
      if (o.name == v) {
        state = o;
        return;
      }
    }
  }

  void seleccionar(T value) {
    state = value;
    ref.read(syncStateDaoProvider).setValor(clave, value.name);
  }

  void limpiar() => seleccionar(inicial);
}

class OrdenAlbumesNotifier extends _OrdenNotifier<OrdenAlbumes> {
  @override
  String get clave => 'orden_albumes';
  @override
  List<OrdenAlbumes> get opciones => OrdenAlbumes.values;
  @override
  OrdenAlbumes get inicial => OrdenAlbumes.tituloAsc;
}

class OrdenArtistasNotifier extends _OrdenNotifier<OrdenArtistas> {
  @override
  String get clave => 'orden_artistas';
  @override
  List<OrdenArtistas> get opciones => OrdenArtistas.values;
  @override
  OrdenArtistas get inicial => OrdenArtistas.nombreAsc;
}

class OrdenPistasNotifier extends _OrdenNotifier<OrdenPistas> {
  @override
  String get clave => 'orden_pistas';
  @override
  List<OrdenPistas> get opciones => OrdenPistas.values;
  @override
  OrdenPistas get inicial => OrdenPistas.tituloAsc;
}

class OrdenPlaylistsNotifier extends _OrdenNotifier<OrdenPlaylists> {
  @override
  String get clave => 'orden_playlists';
  @override
  List<OrdenPlaylists> get opciones => OrdenPlaylists.values;
  @override
  OrdenPlaylists get inicial => OrdenPlaylists.nombreAsc;
}

final NotifierProvider<OrdenAlbumesNotifier, OrdenAlbumes>
    ordenAlbumesProvider =
    NotifierProvider<OrdenAlbumesNotifier, OrdenAlbumes>(
        OrdenAlbumesNotifier.new);
final NotifierProvider<OrdenArtistasNotifier, OrdenArtistas>
    ordenArtistasProvider =
    NotifierProvider<OrdenArtistasNotifier, OrdenArtistas>(
        OrdenArtistasNotifier.new);
final NotifierProvider<OrdenPistasNotifier, OrdenPistas> ordenPistasProvider =
    NotifierProvider<OrdenPistasNotifier, OrdenPistas>(
        OrdenPistasNotifier.new);
final NotifierProvider<OrdenPlaylistsNotifier, OrdenPlaylists>
    ordenPlaylistsProvider =
    NotifierProvider<OrdenPlaylistsNotifier, OrdenPlaylists>(
        OrdenPlaylistsNotifier.new);

// ── Modo de visualización persistido (uno por sección) ────────────────────────
/// Aspecto con el que se muestra una sección de la biblioteca/playlists. El
/// usuario lo elige (icono junto a los filtros) y se **persiste** por sección.
enum LibraryViewMode {
  lista,
  gridPequena,
  gridMediana;

  String get etiqueta => switch (this) {
        LibraryViewMode.lista => 'Lista',
        LibraryViewMode.gridPequena => 'Cuadrícula pequeña',
        LibraryViewMode.gridMediana => 'Cuadrícula mediana',
      };
}

abstract class _VistaNotifier extends Notifier<LibraryViewMode> {
  String get clave;
  LibraryViewMode get inicial;

  @override
  LibraryViewMode build() {
    _cargar();
    return inicial;
  }

  Future<void> _cargar() async {
    final String? v = await ref.read(syncStateDaoProvider).getValor(clave);
    for (final LibraryViewMode m in LibraryViewMode.values) {
      if (m.name == v) {
        state = m;
        return;
      }
    }
  }

  void seleccionar(LibraryViewMode m) {
    state = m;
    ref.read(syncStateDaoProvider).setValor(clave, m.name);
  }
}

class VistaAlbumesNotifier extends _VistaNotifier {
  @override
  String get clave => 'vista_albumes';
  @override
  LibraryViewMode get inicial => LibraryViewMode.gridMediana;
}

class VistaArtistasNotifier extends _VistaNotifier {
  @override
  String get clave => 'vista_artistas';
  @override
  LibraryViewMode get inicial => LibraryViewMode.lista;
}

class VistaPistasNotifier extends _VistaNotifier {
  @override
  String get clave => 'vista_pistas';
  @override
  LibraryViewMode get inicial => LibraryViewMode.lista;
}

class VistaPlaylistsNotifier extends _VistaNotifier {
  @override
  String get clave => 'vista_playlists';
  @override
  LibraryViewMode get inicial => LibraryViewMode.gridMediana;
}

final NotifierProvider<VistaAlbumesNotifier, LibraryViewMode>
    vistaAlbumesProvider =
    NotifierProvider<VistaAlbumesNotifier, LibraryViewMode>(
        VistaAlbumesNotifier.new);
final NotifierProvider<VistaArtistasNotifier, LibraryViewMode>
    vistaArtistasProvider =
    NotifierProvider<VistaArtistasNotifier, LibraryViewMode>(
        VistaArtistasNotifier.new);
final NotifierProvider<VistaPistasNotifier, LibraryViewMode>
    vistaPistasProvider =
    NotifierProvider<VistaPistasNotifier, LibraryViewMode>(
        VistaPistasNotifier.new);
final NotifierProvider<VistaPlaylistsNotifier, LibraryViewMode>
    vistaPlaylistsProvider =
    NotifierProvider<VistaPlaylistsNotifier, LibraryViewMode>(
        VistaPlaylistsNotifier.new);

// ── Texto de búsqueda por sección (transitorio) ──────────────────────────────
class TextoBusquedaNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final NotifierProvider<TextoBusquedaNotifier, String> queryAlbumesProvider =
    NotifierProvider<TextoBusquedaNotifier, String>(TextoBusquedaNotifier.new);
final NotifierProvider<TextoBusquedaNotifier, String> queryArtistasProvider =
    NotifierProvider<TextoBusquedaNotifier, String>(TextoBusquedaNotifier.new);
final NotifierProvider<TextoBusquedaNotifier, String> queryPistasProvider =
    NotifierProvider<TextoBusquedaNotifier, String>(TextoBusquedaNotifier.new);
final NotifierProvider<TextoBusquedaNotifier, String> queryPlaylistsProvider =
    NotifierProvider<TextoBusquedaNotifier, String>(TextoBusquedaNotifier.new);

// ── Conteos de pistas del catálogo (para "más/menos pistas") ──────────────────
final Provider<Map<int, int>> conteoPistasPorAlbumProvider =
    Provider<Map<int, int>>((Ref ref) {
  final List<Pista> pistas = ref.watch(pistasProvider).value ?? const <Pista>[];
  final Map<int, int> m = <int, int>{};
  for (final Pista p in pistas) {
    final int? a = p.albumId;
    if (a != null) {
      m[a] = (m[a] ?? 0) + 1;
    }
  }
  return m;
});

final Provider<Map<int, int>> conteoPistasPorArtistaCatalogoProvider =
    Provider<Map<int, int>>((Ref ref) {
  final List<Pista> pistas = ref.watch(pistasProvider).value ?? const <Pista>[];
  final Map<int, int> m = <int, int>{};
  for (final Pista p in pistas) {
    final int? a = p.artistaId;
    if (a != null) {
      m[a] = (m[a] ?? 0) + 1;
    }
  }
  return m;
});

final StreamProvider<Map<int, int>> conteosPlaylistsPcProvider =
    StreamProvider<Map<int, int>>((Ref ref) {
  return ref.watch(catalogDaoProvider).watchConteosPlaylists();
});

// ── Helpers puros de comparación ──────────────────────────────────────────────
int _txt(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

/// Compara dos años poniendo los nulos al final en cualquier dirección.
int _anio(int? a, int? b, {required bool desc}) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return desc ? b.compareTo(a) : a.compareTo(b);
}

// ── Listas filtradas + ordenadas ──────────────────────────────────────────────
List<T> _rankPorBusqueda<T, I>(
  List<I> index,
  double Function(I) puntuar,
  T Function(I) extraer,
) {
  final List<({double s, I i})> scored = <({double s, I i})>[];
  for (final I item in index) {
    final double s = puntuar(item);
    if (s >= _umbralBiblioteca) {
      scored.add((s: s, i: item));
    }
  }
  scored.sort((({double s, I i}) a, ({double s, I i}) b) => b.s.compareTo(a.s));
  return <T>[for (final ({double s, I i}) e in scored) extraer(e.i)];
}

// ── Búsqueda CRUZADA por sección (Álbumes/Artistas) ───────────────────────────
// Cada sección muestra SOLO su tipo, pero se puede encontrar por referencias
// cruzadas: en Álbumes, buscar un artista trae sus álbumes y buscar una pista
// trae el álbum que la contiene; en Artistas, buscar un álbum/pista trae su
// artista. (En Pistas ya lo cubre `PistaBusq`, que puntúa por título, artista y
// álbum.) Se puntúa cada "campo" y se toma el máximo, con los campos directos
// (título/nombre) a peso pleno y los cruzados algo menores para que el match
// directo ordene primero.

/// Un campo indexado para puntuar (texto normalizado + tokens + peso).
typedef CampoBusqueda = ({double peso, String norm, List<String> tokens});

CampoBusqueda _campo(String texto, double peso) {
  final String n = normalizar(texto);
  return (peso: peso, norm: n, tokens: tokenizar(n));
}

/// Mejor puntuación (0..1) de [q] sobre [campos], aplicando el peso de cada uno.
/// Pura y testeable. Corta en cuanto encuentra una coincidencia casi perfecta.
double puntuarCampos(String q, List<CampoBusqueda> campos) {
  double m = 0;
  for (final CampoBusqueda c in campos) {
    final double s = puntuarTexto(q, c.norm, c.tokens) * c.peso;
    if (s > m) {
      m = s;
    }
    if (m >= 0.999) {
      break;
    }
  }
  return m;
}

/// Álbum indexado para búsqueda cruzada: título (×1.0), nombre del artista
/// (×0.9) y títulos de sus pistas (×0.85).
class _AlbumCruz {
  _AlbumCruz(
    this.album, {
    required String artistaNombre,
    required List<String> pistaTitulos,
  }) : _campos = <CampoBusqueda>[
          _campo(album.titulo, 1.0),
          if (artistaNombre.isNotEmpty) _campo(artistaNombre, 0.9),
          for (final String t in pistaTitulos) _campo(t, 0.85),
        ];

  final Album album;
  final List<CampoBusqueda> _campos;

  double puntuar(String q) => puntuarCampos(q, _campos);
}

/// Artista indexado para búsqueda cruzada: nombre (×1.0), títulos de sus álbumes
/// (×0.9) y títulos de sus pistas (×0.85).
class _ArtistaCruz {
  _ArtistaCruz(
    this.artista, {
    required List<String> albumTitulos,
    required List<String> pistaTitulos,
  }) : _campos = <CampoBusqueda>[
          _campo(artista.nombre, 1.0),
          for (final String t in albumTitulos) _campo(t, 0.9),
          for (final String t in pistaTitulos) _campo(t, 0.85),
        ];

  final Artista artista;
  final List<CampoBusqueda> _campos;

  double puntuar(String q) => puntuarCampos(q, _campos);
}

/// Índice cruzado de álbumes (se recalcula solo al cambiar el catálogo).
final Provider<List<_AlbumCruz>> _albumCruzIndexProvider =
    Provider<List<_AlbumCruz>>((Ref ref) {
  final List<Album> albums = ref.watch(albumsProvider).value ?? const <Album>[];
  final List<Artista> artistas =
      ref.watch(artistasProvider).value ?? const <Artista>[];
  final List<Pista> pistas = ref.watch(pistasProvider).value ?? const <Pista>[];
  final Map<int, String> nombrePorArtista = <int, String>{
    for (final Artista a in artistas) a.id: a.nombre,
  };
  final Map<int, List<String>> titulosPorAlbum = <int, List<String>>{};
  for (final Pista p in pistas) {
    final int? id = p.albumId;
    if (id != null) {
      (titulosPorAlbum[id] ??= <String>[]).add(p.titulo);
    }
  }
  return <_AlbumCruz>[
    for (final Album a in albums)
      _AlbumCruz(
        a,
        artistaNombre:
            a.artistaId == null ? '' : (nombrePorArtista[a.artistaId] ?? ''),
        pistaTitulos: titulosPorAlbum[a.id] ?? const <String>[],
      ),
  ];
});

/// Índice cruzado de artistas (se recalcula solo al cambiar el catálogo).
final Provider<List<_ArtistaCruz>> _artistaCruzIndexProvider =
    Provider<List<_ArtistaCruz>>((Ref ref) {
  final List<Artista> artistas =
      ref.watch(artistasProvider).value ?? const <Artista>[];
  final List<Album> albums = ref.watch(albumsProvider).value ?? const <Album>[];
  final List<Pista> pistas = ref.watch(pistasProvider).value ?? const <Pista>[];
  final Map<int, List<String>> albumTitulosPorArtista = <int, List<String>>{};
  for (final Album al in albums) {
    final int? id = al.artistaId;
    if (id != null) {
      (albumTitulosPorArtista[id] ??= <String>[]).add(al.titulo);
    }
  }
  final Map<int, List<String>> pistaTitulosPorArtista = <int, List<String>>{};
  for (final Pista p in pistas) {
    final int? id = p.artistaId;
    if (id != null) {
      (pistaTitulosPorArtista[id] ??= <String>[]).add(p.titulo);
    }
  }
  return <_ArtistaCruz>[
    for (final Artista ar in artistas)
      _ArtistaCruz(
        ar,
        albumTitulos: albumTitulosPorArtista[ar.id] ?? const <String>[],
        pistaTitulos: pistaTitulosPorArtista[ar.id] ?? const <String>[],
      ),
  ];
});

final Provider<List<Album>> albumesFiltradosProvider =
    Provider<List<Album>>((Ref ref) {
  final String q = normalizar(ref.watch(queryAlbumesProvider));
  if (q.isNotEmpty) {
    // Búsqueda cruzada: por título de álbum, por artista y por pista.
    return _rankPorBusqueda<Album, _AlbumCruz>(
      ref.watch(_albumCruzIndexProvider),
      (_AlbumCruz a) => a.puntuar(q),
      (_AlbumCruz a) => a.album,
    );
  }
  final List<Album> base =
      (ref.watch(albumsProvider).value ?? const <Album>[]).toList();
  final OrdenAlbumes orden = ref.watch(ordenAlbumesProvider);
  final Map<int, int> conteo = ref.watch(conteoPistasPorAlbumProvider);
  base.sort((Album a, Album b) {
    final int c = switch (orden) {
      OrdenAlbumes.tituloAsc => _txt(a.titulo, b.titulo),
      OrdenAlbumes.tituloDesc => _txt(b.titulo, a.titulo),
      OrdenAlbumes.anioDesc => _anio(a.anio, b.anio, desc: true),
      OrdenAlbumes.anioAsc => _anio(a.anio, b.anio, desc: false),
      OrdenAlbumes.masPistas =>
        (conteo[b.id] ?? 0).compareTo(conteo[a.id] ?? 0),
      OrdenAlbumes.menosPistas =>
        (conteo[a.id] ?? 0).compareTo(conteo[b.id] ?? 0),
    };
    return c != 0 ? c : _txt(a.titulo, b.titulo);
  });
  return base;
});

final Provider<List<Artista>> artistasFiltradosProvider =
    Provider<List<Artista>>((Ref ref) {
  final String q = normalizar(ref.watch(queryArtistasProvider));
  if (q.isNotEmpty) {
    // Búsqueda cruzada: por nombre de artista, por sus álbumes y por sus pistas.
    return _rankPorBusqueda<Artista, _ArtistaCruz>(
      ref.watch(_artistaCruzIndexProvider),
      (_ArtistaCruz a) => a.puntuar(q),
      (_ArtistaCruz a) => a.artista,
    );
  }
  final List<Artista> base =
      (ref.watch(artistasProvider).value ?? const <Artista>[]).toList();
  final OrdenArtistas orden = ref.watch(ordenArtistasProvider);
  final Map<int, int> conteo =
      ref.watch(conteoPistasPorArtistaCatalogoProvider);
  base.sort((Artista a, Artista b) {
    final int c = switch (orden) {
      OrdenArtistas.nombreAsc => _txt(a.nombre, b.nombre),
      OrdenArtistas.nombreDesc => _txt(b.nombre, a.nombre),
      OrdenArtistas.masPistas =>
        (conteo[b.id] ?? 0).compareTo(conteo[a.id] ?? 0),
      OrdenArtistas.menosPistas =>
        (conteo[a.id] ?? 0).compareTo(conteo[b.id] ?? 0),
    };
    return c != 0 ? c : _txt(a.nombre, b.nombre);
  });
  return base;
});

final Provider<List<Pista>> pistasFiltradasProvider =
    Provider<List<Pista>>((Ref ref) {
  final String q = normalizar(ref.watch(queryPistasProvider));
  if (q.isNotEmpty) {
    return _rankPorBusqueda<Pista, PistaBusq>(
      ref.watch(pistaIndexProvider),
      (PistaBusq p) => p.puntuar(q),
      (PistaBusq p) => p.pista,
    );
  }
  final List<Pista> base =
      (ref.watch(pistasProvider).value ?? const <Pista>[]).toList();
  final OrdenPistas orden = ref.watch(ordenPistasProvider);
  base.sort((Pista a, Pista b) {
    final int c = switch (orden) {
      OrdenPistas.tituloAsc => _txt(a.titulo, b.titulo),
      OrdenPistas.tituloDesc => _txt(b.titulo, a.titulo),
      OrdenPistas.artistaAsc => _txt(a.artistaNombre, b.artistaNombre),
      OrdenPistas.duracionDesc => b.duracionSeg.compareTo(a.duracionSeg),
      OrdenPistas.duracionAsc => a.duracionSeg.compareTo(b.duracionSeg),
      OrdenPistas.anioDesc => _anio(a.anio, b.anio, desc: true),
      OrdenPistas.anioAsc => _anio(a.anio, b.anio, desc: false),
    };
    return c != 0 ? c : _txt(a.titulo, b.titulo);
  });
  return base;
});

// ── Playlists: filtro + orden (helpers puros, usados por la pantalla) ─────────
double _puntuarNombre(String q, String nombre) {
  final String n = normalizar(nombre);
  return puntuarTexto(q, n, tokenizar(n));
}

/// Filtra+ordena playlists locales por la query (difusa) y el orden elegido.
List<PlaylistLocal> filtrarOrdenarPlaylistsLocales(
  List<PlaylistLocal> base,
  String queryNorm,
  OrdenPlaylists orden,
  Map<int, int> conteos,
) {
  List<PlaylistLocal> lista = base;
  if (queryNorm.isNotEmpty) {
    final List<({double s, PlaylistLocal p})> scored =
        <({double s, PlaylistLocal p})>[];
    for (final PlaylistLocal p in base) {
      final double s = _puntuarNombre(queryNorm, p.nombre);
      if (s >= _umbralBiblioteca) {
        scored.add((s: s, p: p));
      }
    }
    scored.sort((({double s, PlaylistLocal p}) a,
            ({double s, PlaylistLocal p}) b) =>
        b.s.compareTo(a.s));
    return <PlaylistLocal>[for (final ({double s, PlaylistLocal p}) e in scored) e.p];
  }
  lista = base.toList()
    ..sort((PlaylistLocal a, PlaylistLocal b) {
      final int c = switch (orden) {
        OrdenPlaylists.nombreAsc => _txt(a.nombre, b.nombre),
        OrdenPlaylists.nombreDesc => _txt(b.nombre, a.nombre),
        OrdenPlaylists.masPistas =>
          (conteos[b.id] ?? 0).compareTo(conteos[a.id] ?? 0),
        OrdenPlaylists.menosPistas =>
          (conteos[a.id] ?? 0).compareTo(conteos[b.id] ?? 0),
      };
      return c != 0 ? c : _txt(a.nombre, b.nombre);
    });
  return lista;
}

/// Filtra+ordena playlists del PC por la query (difusa) y el orden elegido.
List<Playlist> filtrarOrdenarPlaylistsPc(
  List<Playlist> base,
  String queryNorm,
  OrdenPlaylists orden,
  Map<int, int> conteos,
) {
  if (queryNorm.isNotEmpty) {
    final List<({double s, Playlist p})> scored = <({double s, Playlist p})>[];
    for (final Playlist p in base) {
      final double s = _puntuarNombre(queryNorm, p.nombre);
      if (s >= _umbralBiblioteca) {
        scored.add((s: s, p: p));
      }
    }
    scored.sort(
        (({double s, Playlist p}) a, ({double s, Playlist p}) b) =>
            b.s.compareTo(a.s));
    return <Playlist>[for (final ({double s, Playlist p}) e in scored) e.p];
  }
  return base.toList()
    ..sort((Playlist a, Playlist b) {
      final int c = switch (orden) {
        OrdenPlaylists.nombreAsc => _txt(a.nombre, b.nombre),
        OrdenPlaylists.nombreDesc => _txt(b.nombre, a.nombre),
        OrdenPlaylists.masPistas =>
          (conteos[b.id] ?? 0).compareTo(conteos[a.id] ?? 0),
        OrdenPlaylists.menosPistas =>
          (conteos[a.id] ?? 0).compareTo(conteos[b.id] ?? 0),
      };
      return c != 0 ? c : _txt(a.nombre, b.nombre);
    });
}
