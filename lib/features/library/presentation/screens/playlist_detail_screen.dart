import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/duration_format.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/media_source.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../../shared/widgets/sub_header.dart';
import '../../../offline/application/download_providers.dart';
import '../../../player/application/player_controller.dart';
import '../../../sync/application/remote_media_provider.dart';
import '../../application/library_providers.dart';
import '../widgets/pista_list.dart';

/// Detalle de playlist: mosaico, metadatos y pistas en orden.
class PlaylistDetailScreen extends ConsumerWidget {
  const PlaylistDetailScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final Playlist? playlist =
        ref.watch(playlistProvider(playlistId)).value;
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistProvider(playlistId)).value ??
            const <Pista>[];
    final double total =
        pistas.fold<double>(0, (double a, Pista p) => a + p.duracionSeg);
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final Pista p in pistas)
        if (coverImage(p.coverPath, remote) case final ImageProvider img) img,
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: <Widget>[
            SubHeader(title: playlist?.nombre ?? 'Playlist'),
            Center(
              child: covers.length >= 4
                  ? CoverMosaic(images: covers, size: 200, radius: 18)
                  : Cover(
                      image: covers.isNotEmpty ? covers.first : null,
                      size: 200,
                      radius: 18,
                      overlay: covers.isEmpty
                          ? Center(
                              child: Icon(AppIcons.note,
                                  color: c.text3, size: 44),
                            )
                          : null,
                    ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    playlist?.nombre ?? '',
                    style: TextStyle(
                      fontFamily: NbFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${pistas.length} pistas  ·  ${formatLongDuration(total)}',
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.text2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: pistas.isEmpty
                            ? null
                            : () => ref
                                .read(playerControllerProvider.notifier)
                                .reproducir(pistas, 0),
                        style: FilledButton.styleFrom(
                          backgroundColor: c.accent,
                          foregroundColor: c.ink,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 28,
                            vertical: 12,
                          ),
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
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: pistas.isEmpty
                            ? null
                            : () => ref
                                .read(downloadQueueProvider.notifier)
                                .encolarPlaylist(playlistId),
                        icon: Icon(AppIcons.download, color: c.text2),
                        tooltip: 'Descargar playlist',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PistaList(pistas: pistas, numbered: true, showCover: false),
            ),
          ],
        ),
      ),
    );
  }
}
