import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/library_providers.dart';
import '../../application/playlist_covers.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';

/// Pestaña Inicio: página dinámica que refleja los gustos del usuario (recientes,
/// más escuchadas, favoritas, artistas) y ofrece selecciones del catálogo
/// (novedades, clásicos, explorar) y playlists. Las secciones del catálogo **rotan
/// por sesión** (cada apertura puede mostrar otras), y en pantallas anchas se
/// muestran más ítems y más grandes.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String nombre = ref.watch(nombrePerfilProvider);
    // "Buenas noches, Nombre" si hay nombre; si no, solo el saludo.
    final String saludoBase = saludoPorHora(DateTime.now().hour);
    final String saludo = nombre.isEmpty ? saludoBase : '$saludoBase, $nombre';
    final String inicial = ref.watch(inicialPerfilProvider);
    final ImageProvider? avatarFoto = ref.watch(avatarPerfilProvider);
    final List<Pista> recientes =
        ref.watch(recientesProvider).value ?? const <Pista>[];
    final List<Pista> masEscuchadas =
        ref.watch(masEscuchadasProvider).value ?? const <Pista>[];
    final List<Pista> favoritas =
        ref.watch(favoritasProvider).value ?? const <Pista>[];
    final List<Artista> artistas = ref.watch(topArtistasProvider);
    final List<Album> albums =
        ref.watch(albumsProvider).value ?? const <Album>[];
    final List<Album> novedades = ref.watch(novedadesAlbumsProvider);
    final List<Album> clasicos = ref.watch(clasicosAlbumsProvider);
    final List<Album> explora = ref.watch(exploraAlbumsProvider);
    final List<PlaylistLocal> playlistsLocales =
        ref.watch(playlistsLocalesProvider).value ?? const <PlaylistLocal>[];
    final List<Playlist> playlistsGuardadas =
        ref.watch(playlistsGuardadasProvider);

    final bool vacio = recientes.isEmpty &&
        favoritas.isEmpty &&
        albums.isEmpty &&
        masEscuchadas.isEmpty;

    if (vacio) {
      return ListView(
        children: <Widget>[
          TopBar(
            title: saludo,
            onProfile: () => context.push('/profile'),
            large: true,
            avatarInicial: inicial,
            avatarFoto: avatarFoto,
          ),
          _BibliotecaVacia(onSync: () => context.push('/sync')),
        ],
      );
    }

    // Cuántos ítems por carril/rejilla según el ancho (más en tablet/Chromebook).
    final int nRail = context.countFor(8);
    final int nFav = context.countFor(6);
    final int cols = context.gridCols;
    final int nExplora = cols * (context.isWide ? 3 : 2);

    // Accesos rápidos (estilo Spotify): "Tus me gusta" + tus playlists, arriba.
    final List<_QuickItem> quick = <_QuickItem>[
      if (favoritas.isNotEmpty)
        _QuickItem(
          nombre: 'Tus me gusta',
          corazon: true,
          onTap: () => context.push('/favoritas'),
        ),
      for (final PlaylistLocal pl in playlistsLocales)
        _QuickItem(
          nombre: pl.nombre,
          playlistId: pl.id,
          local: true,
          onTap: () => context.push('/playlist-local/${pl.id}'),
        ),
      for (final Playlist pl in playlistsGuardadas)
        _QuickItem(
          nombre: pl.nombre,
          playlistId: pl.id,
          onTap: () => context.push('/playlist/${pl.id}'),
        ),
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: <Widget>[
        TopBar(
          title: saludo,
          onProfile: () => context.push('/profile'),
          large: true,
          avatarInicial: inicial,
        ),
        if (quick.isNotEmpty) _QuickPicks(items: quick),
        if (recientes.isNotEmpty)
          _TrackRail(
            title: 'Vuelve a tu música',
            pistas: recientes.take(nRail).toList(),
          ),
        if (masEscuchadas.isNotEmpty)
          _TrackRail(
            title: 'Escuchas a menudo',
            pistas: masEscuchadas.take(nRail).toList(),
          ),
        if (favoritas.isNotEmpty) ...<Widget>[
          _Pad(
            child: SectionHead(
              title: 'Tus favoritas',
              actionLabel: 'Ver todas',
              onAction: () => context.push('/favoritas'),
            ),
          ),
          _Pad(child: PistaList(pistas: favoritas.take(nFav).toList())),
          const SizedBox(height: 8),
        ],
        if (artistas.isNotEmpty)
          _ArtistRail(
            title: 'Artistas para ti',
            artistas: artistas.take(nRail).toList(),
          ),
        if (novedades.isNotEmpty)
          _AlbumRail(
            title: 'Novedades',
            albums: novedades.take(nRail).toList(),
          ),
        if (explora.isNotEmpty) ...<Widget>[
          const _Pad(child: SectionHead(title: 'Explora tu biblioteca')),
          _AlbumGrid(albums: explora.take(nExplora).toList()),
          const SizedBox(height: 8),
        ],
        if (clasicos.isNotEmpty)
          _AlbumRail(
            title: 'Clásicos de tu biblioteca',
            albums: clasicos.take(nRail).toList(),
          ),
        if (playlistsLocales.isNotEmpty || playlistsGuardadas.isNotEmpty)
          _PlaylistRail(
            title: 'Tus playlists',
            locales: playlistsLocales,
            guardadas: playlistsGuardadas,
            limite: context.countFor(8),
          ),
      ],
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: child,
      );
}

/// Carrusel horizontal de pistas (portada + título): toca para reproducir la
/// lista como cola desde esa pista.
class _TrackRail extends ConsumerWidget {
  const _TrackRail({required this.title, required this.pistas});
  final String title;
  final List<Pista> pistas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final double s = context.cardScale;
    final double w = 124 * s;
    final int px = coverCachePx(context, w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Pad(child: SectionHead(title: title)),
        SizedBox(
          height: 176 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: pistas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) {
              final Pista p = pistas[i];
              return GestureDetector(
                onTap: () => ref
                    .read(playbackActionsProvider)
                    .reproducirColeccion(pistas, i),
                child: SizedBox(
                  width: w,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Cover(
                        image: resolver.imageFor(p.coverPath, cacheWidth: px),
                        size: w,
                        radius: 14,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        p.titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 13 * context.uiScale,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      Text(
                        p.artistaNombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 12 * context.uiScale,
                          fontWeight: FontWeight.w500,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Carrusel horizontal de álbumes.
class _AlbumRail extends StatelessWidget {
  const _AlbumRail({required this.title, required this.albums});
  final String title;
  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    final double s = context.cardScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Pad(child: SectionHead(title: title)),
        SizedBox(
          height: 198 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) =>
                SizedBox(width: 150 * s, child: AlbumCard(album: albums[i])),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Carrusel horizontal de artistas (círculos).
class _ArtistRail extends StatelessWidget {
  const _ArtistRail({required this.title, required this.artistas});
  final String title;
  final List<Artista> artistas;

  @override
  Widget build(BuildContext context) {
    final double s = context.cardScale;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Pad(child: SectionHead(title: title)),
        SizedBox(
          height: 168 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: artistas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) =>
                ArtistCircle(artista: artistas[i], size: 104 * s),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Cuadrícula de tarjetas de álbum para "explorar".
class _AlbumGrid extends StatelessWidget {
  const _AlbumGrid({required this.albums});
  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
      child: GridView.count(
        crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          for (final Album a in albums) AlbumCard(album: a),
        ],
      ),
    );
  }
}

/// Carrusel horizontal de playlists (locales + guardadas). Acotado a [limite]
/// (como las demás secciones), no carga todas.
class _PlaylistRail extends StatelessWidget {
  const _PlaylistRail({
    required this.title,
    required this.locales,
    required this.guardadas,
    required this.limite,
  });
  final String title;
  final List<PlaylistLocal> locales;
  final List<Playlist> guardadas;
  final int limite;

  @override
  Widget build(BuildContext context) {
    final double s = context.cardScale;
    final List<Widget> tarjetas = <Widget>[
      for (final PlaylistLocal pl in locales)
        SizedBox(width: 150 * s, child: LocalPlaylistCard(playlist: pl)),
      for (final Playlist pl in guardadas)
        SizedBox(width: 150 * s, child: PlaylistCard(playlist: pl)),
    ];
    final List<Widget> visibles =
        tarjetas.length > limite ? tarjetas.sublist(0, limite) : tarjetas;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _Pad(child: SectionHead(title: title)),
        SizedBox(
          height: 210 * s,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: visibles.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) => visibles[i],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// Un acceso rápido del Inicio (colección): "Tus me gusta" o una playlist.
class _QuickItem {
  const _QuickItem({
    required this.nombre,
    required this.onTap,
    this.corazon = false,
    this.playlistId,
    this.local = false,
  });
  final String nombre;
  final VoidCallback onTap;
  final bool corazon;

  /// Id de la playlist (para resolver su portada); null en "Tus me gusta".
  final int? playlistId;

  /// True si es una playlist local del teléfono (decide de qué provider salen
  /// sus pistas para la portada).
  final bool local;
}

/// Rejilla compacta de accesos rápidos (2–4 columnas), estilo Spotify: tarjetas
/// anchas con su portada real + nombre. La altura de cada tarjeta es **fija**
/// (no escala con el ancho) para que en tablet/Chromebook no se vean
/// desproporcionadas: la densidad extra se gana con más columnas, no con
/// tarjetas gigantes.
class _QuickPicks extends StatelessWidget {
  const _QuickPicks({required this.items});
  final List<_QuickItem> items;

  /// Alto fijo de cada tarjeta (== lado de su miniatura, que va a sangre).
  static const double _alto = 56;

  @override
  Widget build(BuildContext context) {
    final int max = context.countFor(6);
    final List<_QuickItem> visibles =
        items.length > max ? items.sublist(0, max) : items;
    final int cols = switch (context.bp) {
      Bp.compact => 2,
      Bp.medium => 3,
      Bp.expanded => 4,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 4),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisExtent: _alto,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibles.length,
        itemBuilder: (BuildContext context, int i) =>
            _QuickTile(item: visibles[i], lado: _alto),
      ),
    );
  }
}

/// Una tarjeta de acceso rápido. Resuelve su miniatura: "Tus me gusta" usa el
/// degradado con el corazón; una playlist usa un **mosaico 2×2** con sus 4
/// primeras portadas distintas (igual que en la lista de Playlists), o una sola
/// portada si tiene menos, o el placeholder si ninguna tiene.
class _QuickTile extends ConsumerWidget {
  const _QuickTile({required this.item, required this.lado});
  final _QuickItem item;
  final double lado;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final Widget leading;
    if (item.corazon) {
      leading = Container(
        width: lado,
        height: lado,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[c.accent, c.ambient],
          ),
        ),
        child: Icon(AppIcons.heartFilled, color: c.ink, size: 22),
      );
    } else {
      final List<Pista> pistas = item.playlistId == null
          ? const <Pista>[]
          : (item.local
                  ? ref.watch(pistasDePlaylistLocalProvider(item.playlistId!))
                  : ref.watch(pistasDePlaylistProvider(item.playlistId!)))
              .value ??
              const <Pista>[];
      // Hasta 4 portadas distintas (salta repetidas y pistas sin portada) para
      // armar el mosaico; placeholder si ninguna tiene.
      final CoverResolver resolver = ref.watch(coverResolverProvider);
      final int px = coverCachePx(context, lado);
      final List<ImageProvider> covers = <ImageProvider>[
        for (final String path in portadasDistintas(pistas))
          if (resolver.imageFor(path, cacheWidth: px)
              case final ImageProvider img)
            img,
      ];
      leading = covers.length >= 4
          ? CoverMosaic(images: covers, size: lado, radius: 0, shadow: false)
          : Cover(
              image: covers.isNotEmpty ? covers.first : null,
              size: lado,
              radius: 0,
              shadow: false,
              overlay: covers.isEmpty
                  ? Center(child: Icon(AppIcons.note, color: c.text2, size: 20))
                  : null,
            );
    }

    return Material(
      color: c.bg2,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: item.onTap,
        child: Row(
          children: <Widget>[
            leading,
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 13 * context.uiScale,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                  color: c.text,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}

/// Estado vacío de Inicio: sin biblioteca local, guía a sincronizar con el PC.
class _BibliotecaVacia extends StatelessWidget {
  const _BibliotecaVacia({required this.onSync});
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 0),
      child: Column(
        children: <Widget>[
          Icon(AppIcons.laptop, size: 56, color: c.accent),
          const SizedBox(height: 18),
          Text(
            'Tu biblioteca está vacía',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sincroniza con NB Sound en tu PC para traer tu música por la red '
            'local.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onSync,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.ink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: const StadiumBorder(),
            ),
            icon: Icon(AppIcons.cast, color: c.ink, size: 20),
            label: Text(
              'Sincronizar con PC',
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
