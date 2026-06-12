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
import '../../application/playlist_cover_prefetch.dart';
import '../../application/playlist_covers.dart';

/// Tarjeta de álbum (portada + título + año). La portada llena el ancho
/// disponible (cuadrada), válido tanto en rejilla como en carrusel.
class AlbumCard extends ConsumerWidget {
  const AlbumCard({super.key, required this.album, this.onOpen});

  final Album album;

  /// Efecto secundario al abrir (p. ej. registrarlo en el historial de búsqueda).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return GestureDetector(
      onTap: () {
        onOpen?.call();
        context.push('/album/${album.id}');
      },
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

/// Fila de álbum (portada cuadrada + título + año) para el modo "lista" de la
/// biblioteca.
class AlbumTile extends ConsumerWidget {
  const AlbumTile({super.key, required this.album});

  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return ListTile(
      onTap: () => context.push('/album/${album.id}'),
      leading: Cover(
        image: ref.watch(coverResolverProvider).imageFor(
              album.coverPath,
              cacheWidth: coverCachePx(context, 52),
            ),
        size: 52,
        radius: 8,
        shadow: false,
      ),
      title: Text(
        album.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: album.anio == null
          ? null
          : Text(
              '${album.anio}',
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12.5,
                color: c.text3,
              ),
            ),
      trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}

/// Celda de cuadrícula **a prueba de desbordes**: la portada va en un `Expanded`
/// con relación 1:1, así se encoge para ceder espacio a los textos y la celda
/// nunca desborda, sea cual sea el nº de columnas (cuadrícula pequeña/mediana).
class _CoverGridCell extends StatelessWidget {
  const _CoverGridCell({
    required this.cover,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.circular = false,
  });

  final ImageProvider? cover;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Widget media = circular
        ? Container(
            decoration: BoxDecoration(
              color: c.bg3,
              shape: BoxShape.circle,
              image: cover != null
                  ? DecorationImage(image: cover!, fit: BoxFit.cover)
                  : null,
            ),
            alignment: Alignment.center,
            child: cover == null
                ? Icon(AppIcons.user, color: c.text3, size: 30)
                : null,
          )
        : Cover(image: cover, size: double.infinity, radius: 14);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment:
            circular ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(child: AspectRatio(aspectRatio: 1, child: media)),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            textAlign: circular ? TextAlign.center : TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              textAlign: circular ? TextAlign.center : TextAlign.start,
              overflow: TextOverflow.ellipsis,
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

/// Celda de álbum para cuadrícula (modo de visualización de la biblioteca).
class AlbumGridCell extends ConsumerWidget {
  const AlbumGridCell({super.key, required this.album});
  final Album album;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CoverGridCell(
        cover: ref.watch(coverResolverProvider).imageFor(
              album.coverPath,
              cacheWidth: coverCachePx(context, 220),
            ),
        title: album.titulo,
        subtitle: album.anio == null ? null : '${album.anio}',
        onTap: () => context.push('/album/${album.id}'),
      );
}

/// Celda de artista (circular) para cuadrícula.
class ArtistGridCell extends ConsumerWidget {
  const ArtistGridCell({super.key, required this.artista});
  final Artista artista;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CoverGridCell(
        circular: true,
        cover: ref.watch(coverResolverProvider).imageFor(
              artista.imagenPath,
              cacheWidth: coverCachePx(context, 160),
            ),
        title: artista.nombre,
        onTap: () => context.push('/artist/${artista.id}'),
      );
}

/// Celda de pista para cuadrícula (la pestaña Pistas). Al tocar reproduce
/// mediante [onTap].
class TrackGridCell extends ConsumerWidget {
  const TrackGridCell({super.key, required this.pista, required this.onTap});
  final Pista pista;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _CoverGridCell(
        cover: ref.watch(coverResolverProvider).imageFor(
              pista.coverPath,
              cacheWidth: coverCachePx(context, 220),
            ),
        title: pista.titulo,
        subtitle: pista.artistaNombre,
        onTap: onTap,
      );
}

/// Tarjeta circular de artista (foto + nombre debajo), estilo Spotify. Para
/// carruseles y rejillas (búsqueda, inicio). Toca para ir al detalle.
class ArtistCircle extends ConsumerWidget {
  const ArtistCircle({
    super.key,
    required this.artista,
    this.size = 104,
    this.onOpen,
  });

  final Artista artista;
  final double size;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ImageProvider? img = ref.watch(coverResolverProvider).imageFor(
          artista.imagenPath,
          cacheWidth: coverCachePx(context, size),
        );
    return GestureDetector(
      onTap: () {
        onOpen?.call();
        context.push('/artist/${artista.id}');
      },
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
  const ArtistTile({super.key, required this.artista, this.onOpen});

  final Artista artista;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ImageProvider? img = ref.watch(coverResolverProvider).imageFor(
          artista.imagenPath,
          cacheWidth: coverCachePx(context, 52),
        );
    return ListTile(
      onTap: () {
        onOpen?.call();
        context.push('/artist/${artista.id}');
      },
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
/// navega a [ruta]; el long-press abre las acciones de anclaje (si se provee
/// [onLongPress]). Si [pinned], muestra un distintivo de anclada.
class _PlaylistCardBase extends StatelessWidget {
  const _PlaylistCardBase({
    required this.nombre,
    required this.subtitulo,
    required this.covers,
    required this.ruta,
    this.onLongPress,
    this.onOpen,
    this.pinned = false,
  });

  final String nombre;
  final String subtitulo;
  final List<ImageProvider> covers;
  final String ruta;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpen;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return GestureDetector(
      onTap: () {
        onOpen?.call();
        context.push(ruta);
      },
      onLongPress: onLongPress,
      // La portada va en un `Expanded` (se encoge para ceder espacio al texto),
      // así la celda nunca desborda sea cual sea el nº de columnas (la cuadrícula
      // pequeña antes superponía el "N pistas" bajo la carátula).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: covers.length >= 4
                        ? CoverMosaic(
                            images: covers, size: double.infinity, radius: 14)
                        : Cover(
                            image: covers.isNotEmpty ? covers.first : null,
                            size: double.infinity,
                            radius: 14,
                            overlay: covers.isEmpty
                                ? Center(
                                    child: Icon(AppIcons.note,
                                        color: c.text3, size: 34),
                                  )
                                : null,
                          ),
                  ),
                  if (pinned)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: c.bg.withValues(alpha: 0.7),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(AppIcons.pinFilled, color: c.accent, size: 14),
                      ),
                    ),
                ],
              ),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
  const PlaylistCard({
    super.key,
    required this.playlist,
    this.onLongPress,
    this.onOpen,
    this.pinned = false,
  });

  final Playlist playlist;
  final VoidCallback? onLongPress;
  final VoidCallback? onOpen;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistProvider(playlist.id)).value ??
            const <Pista>[];
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 110);
    // Solo se resuelven las portadas distintas (≤4): evita decodificar todas las
    // pistas y que el mosaico repita la misma carátula. Además se materializan a
    // disco (prefetch) para que en la próxima apertura salgan instantáneas.
    ref.read(playlistCoverPrefetcherProvider).asegurarParaPistas(pistas);
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
      onLongPress: onLongPress,
      onOpen: onOpen,
      pinned: pinned,
    );
  }
}

/// Tarjeta de playlist local (editable; navega al detalle local).
class LocalPlaylistCard extends ConsumerWidget {
  const LocalPlaylistCard({
    super.key,
    required this.playlist,
    this.onLongPress,
    this.pinned = false,
  });

  final PlaylistLocal playlist;
  final VoidCallback? onLongPress;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistLocalProvider(playlist.id)).value ??
            const <Pista>[];
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 110);
    ref.read(playlistCoverPrefetcherProvider).asegurarParaPistas(pistas);
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
      onLongPress: onLongPress,
      pinned: pinned,
    );
  }
}

/// Fila de playlist (miniatura de mosaico + nombre + conteo) para el modo
/// "lista". Compartida por PC y locales.
class _PlaylistTileBase extends StatelessWidget {
  const _PlaylistTileBase({
    required this.nombre,
    required this.subtitulo,
    required this.covers,
    required this.ruta,
    this.onLongPress,
    this.pinned = false,
  });

  final String nombre;
  final String subtitulo;
  final List<ImageProvider> covers;
  final String ruta;
  final VoidCallback? onLongPress;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Widget thumb = covers.length >= 4
        ? CoverMosaic(images: covers, size: 52, radius: 10)
        : Cover(
            image: covers.isNotEmpty ? covers.first : null,
            size: 52,
            radius: 10,
            shadow: false,
            overlay: covers.isEmpty
                ? Center(child: Icon(AppIcons.note, color: c.text3, size: 22))
                : null,
          );
    return ListTile(
      onTap: () => context.push(ruta),
      onLongPress: onLongPress,
      leading: thumb,
      title: Text(
        nombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        subtitulo,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text3,
        ),
      ),
      trailing: pinned
          ? Icon(AppIcons.pinFilled, color: c.accent, size: 16)
          : Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}

/// Fila de playlist del PC (modo lista).
class PlaylistTile extends ConsumerWidget {
  const PlaylistTile({
    super.key,
    required this.playlist,
    this.onLongPress,
    this.pinned = false,
  });

  final Playlist playlist;
  final VoidCallback? onLongPress;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistProvider(playlist.id)).value ??
            const <Pista>[];
    ref.read(playlistCoverPrefetcherProvider).asegurarParaPistas(pistas);
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 52);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final String path in portadasDistintas(pistas))
        if (resolver.imageFor(path, cacheWidth: px) case final ImageProvider img)
          img,
    ];
    return _PlaylistTileBase(
      nombre: playlist.nombre,
      subtitulo: '${pistas.length} pistas',
      covers: covers,
      ruta: '/playlist/${playlist.id}',
      onLongPress: onLongPress,
      pinned: pinned,
    );
  }
}

/// Fila de playlist local (modo lista).
class LocalPlaylistTile extends ConsumerWidget {
  const LocalPlaylistTile({
    super.key,
    required this.playlist,
    this.onLongPress,
    this.pinned = false,
  });

  final PlaylistLocal playlist;
  final VoidCallback? onLongPress;
  final bool pinned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistLocalProvider(playlist.id)).value ??
            const <Pista>[];
    ref.read(playlistCoverPrefetcherProvider).asegurarParaPistas(pistas);
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 52);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final String path in portadasDistintas(pistas))
        if (resolver.imageFor(path, cacheWidth: px) case final ImageProvider img)
          img,
    ];
    return _PlaylistTileBase(
      nombre: playlist.nombre,
      subtitulo: '${pistas.length} pistas',
      covers: covers,
      ruta: '/playlist-local/${playlist.id}',
      onLongPress: onLongPress,
      pinned: pinned,
    );
  }
}

/// Tarjeta de la playlist automática "Tus me gusta" (favoritas), con el degradado
/// y el corazón de marca. Navega a `/favoritas`. Misma estructura que las demás
/// tarjetas (portada en `Expanded` + nombre + conteo), para encajar en la rejilla
/// de Playlists sin desbordar.
class MeGustaCard extends StatelessWidget {
  const MeGustaCard({super.key, required this.conteo});

  final int conteo;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return GestureDetector(
      onTap: () => context.push('/favoritas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[c.accent, c.ambient],
                  ),
                ),
                child: Center(
                  child: Icon(AppIcons.heartFilled, color: c.ink, size: 34),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus me gusta',
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
            '$conteo pistas',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

/// Fila (modo lista) de "Tus me gusta": miniatura con degradado + corazón.
class MeGustaTile extends StatelessWidget {
  const MeGustaTile({super.key, required this.conteo});

  final int conteo;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ListTile(
      onTap: () => context.push('/favoritas'),
      leading: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[c.accent, c.ambient],
          ),
        ),
        child: Icon(AppIcons.heartFilled, color: c.ink, size: 24),
      ),
      title: Text(
        'Tus me gusta',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        '$conteo pistas',
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text3,
        ),
      ),
      trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}

