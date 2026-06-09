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
import '../../../player/application/player_controller.dart';
import '../../application/library_providers.dart';
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
            title: 'NB Sound',
            onProfile: () => context.push('/profile'),
            large: true,
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

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: <Widget>[
        TopBar(
          title: 'NB Sound',
          onProfile: () => context.push('/profile'),
          large: true,
        ),
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
          const _Pad(child: SectionHead(title: 'Tus favoritas')),
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
                    .read(playerControllerProvider.notifier)
                    .reproducir(pistas, i),
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
