import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/duration_format.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../../shared/widgets/sub_header.dart';
import '../../../offline/application/download_providers.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../offline/data/download_repository.dart';
import '../../../player/application/playback.dart';
import '../../../sync/application/remote_media_provider.dart';
import '../../application/library_providers.dart';
import '../widgets/collection_actions.dart';
import '../widgets/pista_list.dart';

/// Detalle de álbum: portada, metadatos y lista de pistas.
class AlbumDetailScreen extends ConsumerWidget {
  const AlbumDetailScreen({super.key, required this.albumId});

  final int albumId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final Album? album = ref.watch(albumProvider(albumId)).value;
    final List<Pista> pistas =
        ref.watch(pistasDeAlbumProvider(albumId)).value ?? const <Pista>[];
    final double total =
        pistas.fold<double>(0, (double a, Pista p) => a + p.duracionSeg);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: MaxWidth(
          child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  SubHeader(
                    title: album?.titulo ?? 'Álbum',
                    trailing: IconButton(
                      tooltip: 'Más opciones',
                      icon: Icon(AppIcons.moreV, color: c.text2),
                      onPressed: pistas.isEmpty
                          ? null
                          : () => mostrarMenuColeccion(
                                context,
                                ref,
                                pistas,
                                extras: <AccionMenuPista>[
                                  if (album?.artistaId != null)
                                    (
                                      label: 'Ir al artista',
                                      icon: AppIcons.user,
                                      onTap: () => context
                                          .push('/artist/${album!.artistaId}'),
                                    ),
                                ],
                              ),
                    ),
                  ),
                  Center(
                    child: Cover(
                      image: ref.watch(coverResolverProvider).imageFor(
                            album?.coverPath,
                            cacheWidth: coverCachePx(context, 220),
                          ),
                      size: 220,
                      radius: 18,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          album?.titulo ?? '',
                          style: TextStyle(
                            fontFamily: NbFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        // Artista del álbum, enlazado a su página (como Spotify).
                        if (pistas.isNotEmpty && album?.artistaId != null) ...<Widget>[
                          const SizedBox(height: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => context.push('/artist/${album!.artistaId}'),
                            child: Text(
                              pistas.first.artistaNombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: c.text,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          <String>[
                            if (album?.anio != null) '${album!.anio}',
                            '${pistas.length} pistas',
                            formatLongDuration(total),
                          ].join('  ·  '),
                          style: TextStyle(
                            fontFamily: NbFonts.ui,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: c.text2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[
                            _PlayButton(
                              onTap: pistas.isEmpty
                                  ? null
                                  : () => ref
                                      .read(playbackActionsProvider)
                                      .reproducirColeccion(pistas, 0),
                            ),
                            ShuffleCollectionButton(pistas: pistas),
                            _AlbumDownloadButton(
                                albumId: albumId, pistas: pistas),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: PistaSliverList(
                pistas: pistas,
                numbered: true,
                showCover: false,
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: c.accent,
        foregroundColor: c.ink,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: const StadiumBorder(),
      ),
      icon: Icon(AppIcons.play, color: c.ink, size: 22),
      label: Text(
        'Reproducir',
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontWeight: FontWeight.w700,
          color: c.ink,
        ),
      ),
    );
  }
}

/// Botón de descarga del álbum con feedback: spinner mientras baja, check si
/// está completo, acento si hay descargas parciales.
class _AlbumDownloadButton extends ConsumerWidget {
  const _AlbumDownloadButton({required this.albumId, required this.pistas});

  final int albumId;
  final List<Pista> pistas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    if (pistas.isEmpty) {
      return const SizedBox.shrink();
    }
    final Set<int> ids = pistas.map((Pista p) => p.id).toSet();
    final Set<int> descargadas =
        ref.watch(descargadasProvider).value ?? const <int>{};
    final List<DescargaAudio> todas =
        ref.watch(descargasProvider).value ?? const <DescargaAudio>[];
    final int hechas = ids.where(descargadas.contains).length;
    final bool activo = todas.any((DescargaAudio d) =>
        ids.contains(d.pistaId) &&
        (d.estado == DownloadEstado.downloading ||
            d.estado == DownloadEstado.pending));

    if (hechas == ids.length) {
      return IconButton(
        tooltip: 'Álbum descargado',
        onPressed: null,
        icon: Icon(AppIcons.downloadDone, color: c.accent),
      );
    }
    if (activo) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (ref.watch(remoteMediaProvider) == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: hechas > 0 ? 'Descargar resto del álbum' : 'Descargar álbum',
      onPressed: () =>
          ref.read(downloadQueueProvider.notifier).encolarAlbum(albumId),
      icon: Icon(AppIcons.download, color: hechas > 0 ? c.accent : c.text2),
    );
  }
}
