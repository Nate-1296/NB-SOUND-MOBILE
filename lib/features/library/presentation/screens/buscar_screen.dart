import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../../shared/widgets/placeholder_body.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/library_providers.dart';
import '../../application/recientes_busqueda.dart';
import '../../application/search_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';

// ── Registro de items reales en el historial de búsqueda (estilo Spotify) ───────
void _regAlbum(WidgetRef ref, Album a) =>
    ref.read(recientesBusquedaProvider.notifier).registrar(ItemBusqueda(
          tipo: TipoItemBusqueda.album,
          id: a.id,
          titulo: a.titulo,
          subtitulo: 'Álbum',
          cover: a.coverPath,
        ));

void _regArtista(WidgetRef ref, Artista a) =>
    ref.read(recientesBusquedaProvider.notifier).registrar(ItemBusqueda(
          tipo: TipoItemBusqueda.artista,
          id: a.id,
          titulo: a.nombre,
          subtitulo: 'Artista',
          cover: a.imagenPath,
        ));

void _regPlaylist(WidgetRef ref, Playlist p) =>
    ref.read(recientesBusquedaProvider.notifier).registrar(ItemBusqueda(
          tipo: TipoItemBusqueda.playlist,
          id: p.id,
          titulo: p.nombre,
          subtitulo: 'Playlist',
        ));

void _regPista(WidgetRef ref, Pista p) =>
    ref.read(recientesBusquedaProvider.notifier).registrar(ItemBusqueda(
          tipo: TipoItemBusqueda.pista,
          id: p.id,
          titulo: p.titulo,
          subtitulo: 'Canción · ${p.artistaNombre}',
          cover: p.coverPath,
        ));

/// Filtro por tipo en los resultados de búsqueda (estilo Spotify).
enum _Filtro {
  todo,
  canciones,
  artistas,
  albums,
  playlists;

  String get etiqueta => switch (this) {
        _Filtro.todo => 'Todo',
        _Filtro.canciones => 'Canciones',
        _Filtro.artistas => 'Artistas',
        _Filtro.albums => 'Álbumes',
        _Filtro.playlists => 'Playlists',
      };
}

/// Pestaña Buscar: búsqueda difusa (tolerante a errores y acentos) sobre el
/// catálogo. Muestra artistas (círculos), álbumes, canciones y playlists,
/// ordenados de más a menos coincidencia. En vacío: búsquedas recientes + explora.
class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  _Filtro _filtro = _Filtro.todo;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // Debounce ligero: coalesce pulsaciones rápidas sin que se note lag. El
    // historial ya NO guarda el texto: guarda el ítem que se abre (ver _reg*).
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), () {
      ref.read(busquedaQueryProvider.notifier).set(v);
    });
  }

  /// Abre un ítem del historial: la canción se reproduce sola (sin contexto), el
  /// resto navega a su detalle. Como en Spotify.
  Future<void> _abrirReciente(ItemBusqueda it) async {
    switch (it.tipo) {
      case TipoItemBusqueda.album:
        context.push('/album/${it.id}');
      case TipoItemBusqueda.artista:
        context.push('/artist/${it.id}');
      case TipoItemBusqueda.playlist:
        context.push('/playlist/${it.id}');
      case TipoItemBusqueda.pista:
        final Map<int, Pista> m =
            await ref.read(catalogDaoProvider).getPistasPorIds(<int>[it.id]);
        final Pista? p = m[it.id];
        if (p != null) {
          await ref.read(playbackActionsProvider).reproducirPistaUnica(p);
        }
    }
  }

  void _limpiar() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _filtro = _Filtro.todo);
    ref.read(busquedaQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final String query = ref.watch(busquedaQueryProvider);
    final ResultadosBusqueda resultados =
        ref.watch(resultadosBusquedaProvider);

    // Pestaña raíz: atrás cerraría la app. Si hay búsqueda activa, se intercepta
    // para limpiarla (y cerrar el teclado) en lugar de salir.
    return PopScope<Object?>(
      canPop: query.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _limpiar();
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: <Widget>[
          TopBar(
            title: 'Buscar',
            onProfile: () => context.push('/profile'),
            avatarInicial: ref.watch(inicialPerfilProvider),
            avatarFoto: ref.watch(avatarPerfilProvider),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 15,
                color: c.text,
              ),
              decoration: InputDecoration(
                hintText: 'Canciones, artistas, álbumes, playlists',
                hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
                prefixIcon: Icon(AppIcons.search, color: c.text3, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(AppIcons.close, color: c.text3, size: 18),
                        onPressed: _limpiar,
                      ),
                filled: true,
                fillColor: c.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          if (query.trim().isNotEmpty && !resultados.estaVacio)
            _ChipsFiltro(
              actual: _filtro,
              onSelect: (_Filtro f) => setState(() => _filtro = f),
            ),
          Expanded(child: MaxWidth(child: _body(query, resultados))),
        ],
      ),
    );
  }

  Widget _body(String query, ResultadosBusqueda r) {
    if (query.trim().isEmpty) {
      return _VacioRecientesExplora(onAbrir: _abrirReciente);
    }
    if (r.estaVacio) {
      return const PlaceholderBody(
        icon: AppIcons.search,
        title: 'Sin resultados',
        subtitle: 'Prueba con otras palabras.',
      );
    }
    final List<Widget> slivers = <Widget>[];
    switch (_filtro) {
      case _Filtro.canciones:
        slivers.add(SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
          sliver: PistaSliverList(
            pistas: r.pistas,
            onOpen: (Pista p) => _regPista(ref, p),
          ),
        ));
      case _Filtro.artistas:
        slivers.add(SliverPadding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
          sliver: SliverList.builder(
            itemCount: r.artistas.length,
            itemBuilder: (BuildContext context, int i) => ArtistTile(
              artista: r.artistas[i],
              onOpen: () => _regArtista(ref, r.artistas[i]),
            ),
          ),
        ));
      case _Filtro.albums:
        slivers.add(_gridAlbumes(context, r.albums));
      case _Filtro.playlists:
        slivers.add(_gridPlaylists(context, r.playlists));
      case _Filtro.todo:
        // Mejor resultado destacado + secciones en orden de coincidencia.
        slivers.add(SliverToBoxAdapter(child: _MejorResultado(r: r)));
        for (final TipoResultado t in r.orden) {
          switch (t) {
            case TipoResultado.artistas:
              if (r.artistas.isNotEmpty) {
                slivers.add(SliverToBoxAdapter(
                    child: _ArtistasRail(artistas: r.artistas)));
              }
            case TipoResultado.albums:
              if (r.albums.isNotEmpty) {
                slivers.add(
                    SliverToBoxAdapter(child: _AlbumesRail(albums: r.albums)));
              }
            case TipoResultado.playlists:
              if (r.playlists.isNotEmpty) {
                slivers.add(SliverToBoxAdapter(
                    child: _PlaylistsRail(playlists: r.playlists)));
              }
            case TipoResultado.pistas:
              if (r.pistas.isNotEmpty) {
                slivers.add(
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
                      child: SectionHead(title: 'Canciones'),
                    ),
                  ),
                );
                slivers.add(
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                    sliver: PistaSliverList(
                      pistas: r.pistas,
                      onOpen: (Pista p) => _regPista(ref, p),
                    ),
                  ),
                );
              }
          }
        }
    }
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: slivers,
    );
  }

  SliverPadding _gridAlbumes(BuildContext context, List<Album> albums) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.78,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int i) => AlbumCard(
            album: albums[i],
            onOpen: () => _regAlbum(ref, albums[i]),
          ),
          childCount: albums.length,
        ),
      ),
    );
  }

  SliverPadding _gridPlaylists(BuildContext context, List<Playlist> playlists) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
          mainAxisSpacing: 18,
          crossAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (BuildContext context, int i) => PlaylistCard(
            playlist: playlists[i],
            onOpen: () => _regPlaylist(ref, playlists[i]),
          ),
          childCount: playlists.length,
        ),
      ),
    );
  }
}

/// Fila de chips para filtrar los resultados por tipo.
class _ChipsFiltro extends StatelessWidget {
  const _ChipsFiltro({required this.actual, required this.onSelect});
  final _Filtro actual;
  final ValueChanged<_Filtro> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        itemCount: _Filtro.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int i) {
          final _Filtro f = _Filtro.values[i];
          return ChipPill(
            label: f.etiqueta,
            active: f == actual,
            onTap: () => onSelect(f),
          );
        },
      ),
    );
  }
}

/// Tarjeta "Mejor resultado": el ítem de mayor coincidencia (primer elemento de
/// la sección con mejor puntuación). Tocar navega o reproduce, según el tipo.
class _MejorResultado extends ConsumerWidget {
  const _MejorResultado({required this.r});
  final ResultadosBusqueda r;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    // Primera sección no vacía en el orden por coincidencia.
    TipoResultado? tipo;
    for (final TipoResultado t in r.orden) {
      final bool hay = switch (t) {
        TipoResultado.artistas => r.artistas.isNotEmpty,
        TipoResultado.albums => r.albums.isNotEmpty,
        TipoResultado.pistas => r.pistas.isNotEmpty,
        TipoResultado.playlists => r.playlists.isNotEmpty,
      };
      if (hay) {
        tipo = t;
        break;
      }
    }
    if (tipo == null) {
      return const SizedBox.shrink();
    }

    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 80);
    late final String titulo;
    late final String subtitulo;
    late final ImageProvider? img;
    late final bool circular;
    late final VoidCallback onTap;
    switch (tipo) {
      case TipoResultado.artistas:
        final Artista a = r.artistas.first;
        titulo = a.nombre;
        subtitulo = 'Artista';
        img = resolver.imageFor(a.imagenPath, cacheWidth: px);
        circular = true;
        onTap = () {
          _regArtista(ref, a);
          context.push('/artist/${a.id}');
        };
      case TipoResultado.albums:
        final Album a = r.albums.first;
        titulo = a.titulo;
        subtitulo = 'Álbum';
        img = resolver.imageFor(a.coverPath, cacheWidth: px);
        circular = false;
        onTap = () {
          _regAlbum(ref, a);
          context.push('/album/${a.id}');
        };
      case TipoResultado.playlists:
        final Playlist p = r.playlists.first;
        titulo = p.nombre;
        subtitulo = 'Playlist';
        img = null;
        circular = false;
        onTap = () {
          _regPlaylist(ref, p);
          context.push('/playlist/${p.id}');
        };
      case TipoResultado.pistas:
        final Pista p = r.pistas.first;
        titulo = p.titulo;
        subtitulo = 'Canción · ${p.artistaNombre}';
        img = resolver.imageFor(p.coverPath, cacheWidth: px);
        circular = false;
        onTap = () {
          _regPista(ref, p);
          ref.read(playbackActionsProvider).reproducirColeccion(r.pistas, 0);
        };
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHead(title: 'Mejor resultado'),
          Material(
            color: c.bg2,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: <Widget>[
                    if (circular)
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: c.bg3,
                          shape: BoxShape.circle,
                          image: img != null
                              ? DecorationImage(image: img, fit: BoxFit.cover)
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: img == null
                            ? Icon(AppIcons.user, color: c.text3, size: 30)
                            : null,
                      )
                    else
                      Cover(image: img, size: 72, radius: 10, shadow: false),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            titulo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NbFonts.display,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitulo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado vacío de Buscar: historial de resultados **reales** (pista/álbum/
/// artista/playlist) + "Explora tu biblioteca" (artistas y álbumes), en vez de un
/// simple placeholder. Tocar un reciente lo reproduce (pista) o navega a él.
class _VacioRecientesExplora extends ConsumerWidget {
  const _VacioRecientesExplora({required this.onAbrir});
  final ValueChanged<ItemBusqueda> onAbrir;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final List<ItemBusqueda> recientes = ref.watch(recientesBusquedaProvider);
    final List<Artista> artistas = ref.watch(topArtistasProvider);
    final List<Album> albums = ref.watch(exploraAlbumsProvider);
    final CoverResolver resolver = ref.watch(coverResolverProvider);

    if (recientes.isEmpty && artistas.isEmpty && albums.isEmpty) {
      return const PlaceholderBody(
        icon: AppIcons.search,
        title: 'Busca en tu biblioteca',
        subtitle:
            'Canciones, artistas, álbumes o playlists. Entiende errores y acentos.',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        if (recientes.isNotEmpty) ...<Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 12, 4),
            child: Row(
              children: <Widget>[
                const Expanded(child: SectionHead(title: 'Recientes')),
                TextButton(
                  onPressed: () =>
                      ref.read(recientesBusquedaProvider.notifier).borrarTodo(),
                  child: Text(
                    'Borrar',
                    style: TextStyle(color: c.text2, fontFamily: NbFonts.ui),
                  ),
                ),
              ],
            ),
          ),
          for (final ItemBusqueda it in recientes)
            _RecienteTile(
              item: it,
              resolver: resolver,
              onTap: () => onAbrir(it),
              onBorrar: () =>
                  ref.read(recientesBusquedaProvider.notifier).borrar(it),
            ),
          const SizedBox(height: 8),
        ],
        if (artistas.isNotEmpty) _ArtistasRail(artistas: artistas),
        if (albums.isNotEmpty) ...<Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
            child: SectionHead(title: 'Explora tu biblioteca'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
            child: GridView.count(
              crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.78,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: <Widget>[
                for (final Album a in albums.take(gridColumns(
                            MediaQuery.sizeOf(context).width) *
                        2))
                  AlbumCard(album: a, onOpen: () => _regAlbum(ref, a)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Fila de un resultado reciente del historial (thumb + título + tipo + ×).
class _RecienteTile extends StatelessWidget {
  const _RecienteTile({
    required this.item,
    required this.resolver,
    required this.onTap,
    required this.onBorrar,
  });

  final ItemBusqueda item;
  final CoverResolver resolver;
  final VoidCallback onTap;
  final VoidCallback onBorrar;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final ImageProvider? img = (item.cover == null)
        ? null
        : resolver.imageFor(item.cover, cacheWidth: coverCachePx(context, 44));
    final Widget leading = item.circular
        ? Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.bg3,
              shape: BoxShape.circle,
              image: img != null
                  ? DecorationImage(image: img, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: img == null ? Icon(AppIcons.user, color: c.text3) : null,
          )
        : (item.tipo == TipoItemBusqueda.playlist
            ? Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.bg3,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Icon(AppIcons.note, color: c.text3, size: 22),
              )
            : Cover(image: img, size: 44, radius: 8, shadow: false));
    return ListTile(
      dense: true,
      onTap: onTap,
      leading: leading,
      title: Text(
        item.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        item.subtitulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text3,
        ),
      ),
      trailing: IconButton(
        icon: Icon(AppIcons.close, color: c.text3, size: 18),
        onPressed: onBorrar,
      ),
    );
  }
}

/// Carrusel horizontal de artistas (círculos) en los resultados/explora.
class _ArtistasRail extends ConsumerWidget {
  const _ArtistasRail({required this.artistas});
  final List<Artista> artistas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double s = context.cardScale;
    final double circulo = 104 * s;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: SectionHead(title: 'Artistas'),
        ),
        SizedBox(
          height: 168 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: artistas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) => ArtistCircle(
              artista: artistas[i],
              size: circulo,
              onOpen: () => _regArtista(ref, artistas[i]),
            ),
          ),
        ),
      ],
    );
  }
}

/// Carrusel horizontal de álbumes en los resultados.
class _AlbumesRail extends ConsumerWidget {
  const _AlbumesRail({required this.albums});
  final List<Album> albums;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double s = context.cardScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: SectionHead(title: 'Álbumes'),
        ),
        SizedBox(
          height: 198 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) => SizedBox(
              width: 150 * s,
              child: AlbumCard(
                album: albums[i],
                onOpen: () => _regAlbum(ref, albums[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Carrusel horizontal de playlists en los resultados.
class _PlaylistsRail extends ConsumerWidget {
  const _PlaylistsRail({required this.playlists});
  final List<Playlist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double s = context.cardScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: SectionHead(title: 'Playlists'),
        ),
        SizedBox(
          height: 210 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: playlists.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) => SizedBox(
              width: 150 * s,
              child: PlaylistCard(
                playlist: playlists[i],
                onOpen: () => _regPlaylist(ref, playlists[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
