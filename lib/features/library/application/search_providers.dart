import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/search/fuzzy.dart';
import '../../../data/db/database.dart';
import 'library_providers.dart';

/// Ítem de pista indexado para búsqueda: normaliza título/artista/álbum una sola
/// vez (cuando cambia el catálogo), para puntuar barato en cada pulsación.
class PistaBusq {
  PistaBusq(this.pista)
      : tituloN = normalizar(pista.titulo),
        artistaN = normalizar(pista.artistaNombre),
        albumN = normalizar(pista.albumTitulo ?? '') {
    tituloT = tokenizar(tituloN);
    artistaT = tokenizar(artistaN);
    albumT = tokenizar(albumN);
  }

  final Pista pista;
  final String tituloN;
  final String artistaN;
  final String albumN;
  late final List<String> tituloT;
  late final List<String> artistaT;
  late final List<String> albumT;

  /// Mejor coincidencia, dando más peso al título y menos a artista/álbum.
  double puntuar(String q) {
    final double t = puntuarTexto(q, tituloN, tituloT);
    final double a = puntuarTexto(q, artistaN, artistaT) * 0.85;
    final double al = puntuarTexto(q, albumN, albumT) * 0.75;
    double m = t;
    if (a > m) m = a;
    if (al > m) m = al;
    return m;
  }
}

/// Ítem de álbum indexado (se puntúa por título).
class AlbumBusq {
  AlbumBusq(this.album) : tituloN = normalizar(album.titulo) {
    tituloT = tokenizar(tituloN);
  }

  final Album album;
  final String tituloN;
  late final List<String> tituloT;

  double puntuar(String q) => puntuarTexto(q, tituloN, tituloT);
}

/// Ítem de artista indexado (se puntúa por nombre).
class ArtistaBusq {
  ArtistaBusq(this.artista) : nombreN = normalizar(artista.nombre) {
    nombreT = tokenizar(nombreN);
  }

  final Artista artista;
  final String nombreN;
  late final List<String> nombreT;

  double puntuar(String q) => puntuarTexto(q, nombreN, nombreT);
}

/// Tipo de sección de resultados (para ordenarlas por coincidencia).
enum TipoResultado { artistas, albums, pistas }

/// Resultado de búsqueda multi-tipo. Cada lista va ordenada de más a menos
/// coincidencia, y [orden] dice en qué secuencia mostrar las **secciones** según
/// cuál tiene la mejor coincidencia (p. ej. "Bad Bu" ⇒ artistas primero; el título
/// de una canción exacto ⇒ canciones primero). Estilo Spotify: lo más parecido
/// arriba, sin obligar a bajar por una lista larga de pistas.
class ResultadosBusqueda {
  const ResultadosBusqueda({
    required this.artistas,
    required this.albums,
    required this.pistas,
    this.orden = const <TipoResultado>[
      TipoResultado.artistas,
      TipoResultado.albums,
      TipoResultado.pistas,
    ],
  });

  static const ResultadosBusqueda vacio = ResultadosBusqueda(
    artistas: <Artista>[],
    albums: <Album>[],
    pistas: <Pista>[],
  );

  final List<Artista> artistas;
  final List<Album> albums;
  final List<Pista> pistas;

  /// Secciones de más a menos coincidencia (las vacías pueden ir al final).
  final List<TipoResultado> orden;

  bool get estaVacio =>
      artistas.isEmpty && albums.isEmpty && pistas.isEmpty;
}

/// Ordena las secciones por su mejor puntuación (desc). Pura y testeable.
List<TipoResultado> ordenarSecciones({
  required double artistas,
  required double albums,
  required double pistas,
}) {
  final List<({TipoResultado t, double s})> xs = <({TipoResultado t, double s})>[
    (t: TipoResultado.artistas, s: artistas),
    (t: TipoResultado.albums, s: albums),
    (t: TipoResultado.pistas, s: pistas),
  ]..sort((({TipoResultado t, double s}) a, ({TipoResultado t, double s}) b) =>
      b.s.compareTo(a.s));
  return <TipoResultado>[for (final ({TipoResultado t, double s}) x in xs) x.t];
}

// ── Índices (se recalculan solo cuando cambia el catálogo) ────────────────────
/// Índice de pistas normalizado, reutilizable por la búsqueda principal, los
/// filtros de biblioteca y el selector "añadir canciones".
final Provider<List<PistaBusq>> pistaIndexProvider =
    Provider<List<PistaBusq>>((Ref ref) {
  final List<Pista> pistas = ref.watch(pistasProvider).value ?? const <Pista>[];
  return <PistaBusq>[for (final Pista p in pistas) PistaBusq(p)];
});

final Provider<List<AlbumBusq>> albumIndexProvider =
    Provider<List<AlbumBusq>>((Ref ref) {
  final List<Album> albums = ref.watch(albumsProvider).value ?? const <Album>[];
  return <AlbumBusq>[for (final Album a in albums) AlbumBusq(a)];
});

final Provider<List<ArtistaBusq>> artistaIndexProvider =
    Provider<List<ArtistaBusq>>((Ref ref) {
  final List<Artista> artistas =
      ref.watch(artistasProvider).value ?? const <Artista>[];
  return <ArtistaBusq>[for (final Artista a in artistas) ArtistaBusq(a)];
});

/// Umbral por debajo del cual no se considera coincidencia (deja pasar typos y
/// subsecuencias, pero no ruido).
const double _umbral = 0.3;

/// Rankea y devuelve los ítems (≤ [limite]) **más** la mejor puntuación lograda
/// (0 si nada superó el umbral), para ordenar las secciones entre sí.
({List<T> items, double top}) _rank<T, I>(
  List<I> index,
  double Function(I) puntuar,
  T Function(I) extraer, {
  required int limite,
}) {
  final List<({double s, I i})> scored = <({double s, I i})>[];
  for (final I item in index) {
    final double s = puntuar(item);
    if (s >= _umbral) {
      scored.add((s: s, i: item));
    }
  }
  scored.sort((({double s, I i}) a, ({double s, I i}) b) => b.s.compareTo(a.s));
  final List<T> out = <T>[];
  for (final ({double s, I i}) e in scored) {
    out.add(extraer(e.i));
    if (out.length >= limite) {
      break;
    }
  }
  return (items: out, top: scored.isEmpty ? 0 : scored.first.s);
}

/// Resultados de la búsqueda principal (difusa, multi-tipo). Reactivo a la query
/// y al catálogo. Rápido: normaliza en los índices y puntúa con cortes baratos.
final Provider<ResultadosBusqueda> resultadosBusquedaProvider =
    Provider<ResultadosBusqueda>((Ref ref) {
  final String q = normalizar(ref.watch(busquedaQueryProvider));
  if (q.isEmpty) {
    return ResultadosBusqueda.vacio;
  }
  final ({List<Artista> items, double top}) artistas = _rank<Artista, ArtistaBusq>(
    ref.watch(artistaIndexProvider),
    (ArtistaBusq a) => a.puntuar(q),
    (ArtistaBusq a) => a.artista,
    limite: 12,
  );
  final ({List<Album> items, double top}) albums = _rank<Album, AlbumBusq>(
    ref.watch(albumIndexProvider),
    (AlbumBusq a) => a.puntuar(q),
    (AlbumBusq a) => a.album,
    limite: 12,
  );
  // Lista de canciones acotada (estilo Spotify): unas pocas, de + a - coincidencia.
  // Antes 40 obligaba a bajar mucho antes de ver artistas/álbumes.
  final ({List<Pista> items, double top}) pistas = _rank<Pista, PistaBusq>(
    ref.watch(pistaIndexProvider),
    (PistaBusq p) => p.puntuar(q),
    (PistaBusq p) => p.pista,
    limite: 8,
  );
  return ResultadosBusqueda(
    artistas: artistas.items,
    albums: albums.items,
    pistas: pistas.items,
    orden: ordenarSecciones(
      artistas: artistas.top,
      albums: albums.top,
      pistas: pistas.top,
    ),
  );
});
