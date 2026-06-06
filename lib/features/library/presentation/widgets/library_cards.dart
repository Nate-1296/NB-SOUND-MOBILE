import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/media_source.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../sync/application/remote_media_provider.dart';
import '../../application/library_providers.dart';

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
              image: coverImage(album.coverPath, ref.watch(remoteMediaProvider)),
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

/// Fila de artista (portada circular + nombre).
class ArtistTile extends ConsumerWidget {
  const ArtistTile({super.key, required this.artista});

  final Artista artista;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ImageProvider? img =
        coverImage(artista.imagenPath, ref.watch(remoteMediaProvider));
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
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final Pista p in pistas)
        if (coverImage(p.coverPath, remote) case final ImageProvider img) img,
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
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final Pista p in pistas)
        if (coverImage(p.coverPath, remote) case final ImageProvider img) img,
    ];
    return _PlaylistCardBase(
      nombre: playlist.nombre,
      subtitulo: '${pistas.length} pistas',
      covers: covers,
      ruta: '/playlist-local/${playlist.id}',
    );
  }
}

