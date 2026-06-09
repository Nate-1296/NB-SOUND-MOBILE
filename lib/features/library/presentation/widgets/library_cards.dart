import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../offline/application/image_resolver.dart';
import '../../application/library_providers.dart';
import '../../application/playlist_covers.dart';

/// Tarjeta de álbum (portada + título + año). La portada llena el ancho
/// disponible (cuadrada), válido tanto en rejilla como en carrusel.
class AlbumCard extends ConsumerWidget {
  const AlbumCard({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return GestureDetector(
      onTap: () => context.push('/album/${album.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: Cover(
              image: ref.watch(coverResolverProvider).imageFor(
                    album.coverPath,
                    cacheWidth: coverCachePx(context, 220),
                  ),
              size: double.infinity,
              radius: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            album.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          if (album.anio != null)
            Text(
              '${album.anio}',
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: c.text3,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta circular de artista (foto + nombre debajo), estilo Spotify. Para
/// carruseles y rejillas (búsqueda, inicio). Toca para ir al detalle.
class ArtistCircle extends ConsumerWidget {
  const ArtistCircle({super.key, required this.artista, this.size = 104});

  final Artista artista;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ImageProvider? img = ref.watch(coverResolverProvider).imageFor(
          artista.imagenPath,
          cacheWidth: coverCachePx(context, size),
        );
    return GestureDetector(
      onTap: () => context.push('/artist/${artista.id}'),
      child: SizedBox(
        width: size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: c.bg3,
                shape: BoxShape.circle,
                image: img != null
                    ? DecorationImage(image: img, fit: BoxFit.cover)
                    : null,
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: img == null
                  ? Icon(AppIcons.user, color: c.text3, size: size * 0.4)
                  : null,
            ),
            const SizedBox(height: 8),
            Text(
              artista.nombre,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.15,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de artista (portada circular + nombre).
class ArtistTile extends ConsumerWidget {
  const ArtistTile({super.key, required this.artista});

  final Artista artista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ImageProvider? img = ref.watch(coverResolverProvider).imageFor(
          artista.imagenPath,
          cacheWidth: coverCachePx(context, 52),
        );
    return ListTile(
      onTap: () => context.push('/artist/${artista.id}'),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: c.bg3,
          shape: BoxShape.circle,
          image: img != null
              ? DecorationImage(image: img, fit: BoxFit.cover)
              : null,
        ),
        alignment: Alignment.center,
        child: img == null ? Icon(AppIcons.user, color: c.text3) : null,
      ),
      title: Text(
        artista.nombre,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}

/// Tarjeta de una playlist (PC o local): mosaico 2×2 + nombre + conteo. El tap
/// navega a [ruta]. La lógica de mosaico es común a ambas.
class _PlaylistCardBase extends StatelessWidget {
  const _PlaylistCardBase({
    required this.nombre,
    required this.subtitulo,
    required this.covers,
    required this.ruta,
  });

  final String nombre;
  final String subtitulo;
  final List<ImageProvider> covers;
  final String ruta;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return GestureDetector(
      onTap: () => context.push(ruta),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 1,
            child: covers.length >= 4
                ? CoverMosaic(images: covers, size: double.infinity, radius: 14)
                : Cover(
                    image: covers.isNotEmpty ? covers.first : null,
                    size: double.infinity,
                    radius: 14,
                    overlay: covers.isEmpty
                        ? Center(
                            child: Icon(AppIcons.note, color: c.text3, size: 34),
                          )
                        : null,
                  ),
          ),
          const SizedBox(height: 8),
          Text(
            nombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          Text(
            subtitulo,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de playlist del PC (read-only).
class PlaylistCard extends ConsumerWidget {
  const PlaylistCard({super.key, required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistProvider(playlist.id)).value ??
            const <Pista>[];
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 110);
    // Solo se resuelven las portadas distintas (≤4): evita decodificar todas las
    // pistas y que el mosaico repita la misma carátula.
    final List<ImageProvider> covers = <ImageProvider>[
      for (final String path in portadasDistintas(pistas))
        if (resolver.imageFor(path, cacheWidth: px) case final ImageProvider img)
          img,
    ];
    return _PlaylistCardBase(
      nombre: playlist.nombre,
      subtitulo: '${pistas.length} pistas',
      covers: covers,
      ruta: '/playlist/${playlist.id}',
    );
  }
}

/// Tarjeta de playlist local (editable; navega al detalle local).
class LocalPlaylistCard extends ConsumerWidget {
  const LocalPlaylistCard({super.key, required this.playlist});

  final PlaylistLocal playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistLocalProvider(playlist.id)).value ??
            const <Pista>[];
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 110);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final String path in portadasDistintas(pistas))
        if (resolver.imageFor(path, cacheWidth: px) case final ImageProvider img)
          img,
    ];
    return _PlaylistCardBase(
      nombre: playlist.nombre,
      subtitulo: '${pistas.length} pistas',
      covers: covers,
      ruta: '/playlist-local/${playlist.id}',
    );
  }
}

