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
import '../../../offline/data/download_repository.dart';
import '../../../player/application/player_controller.dart';
import '../../../sync/application/remote_media_provider.dart';
import '../../application/library_providers.dart';
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
    final bool shuffle = ref
        .watch(playerControllerProvider.select((PlayerState s) => s.shuffle));

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: <Widget>[
            SubHeader(title: album?.titulo ?? 'Álbum'),
            Center(
              child: Cover(
                image: coverImage(album?.coverPath, ref.watch(remoteMediaProvider)),
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
                  Row(
                    children: <Widget>[
                      _PlayButton(
                        onTap: pistas.isEmpty
                            ? null
                            : () => ref
                                .read(playerControllerProvider.notifier)
                                .reproducir(pistas, 0),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Reproducir aleatorio',
                        onPressed: pistas.isEmpty
                            ? null
                            : () {
                                final ctrl = ref
                                    .read(playerControllerProvider.notifier);
                                ctrl.reproducir(pistas, 0);
                                if (!shuffle) {
                                  ctrl.alternarAleatorio();
                                }
                              },
                        icon: Icon(
                          AppIcons.shuffle,
                          color: shuffle ? c.accent : c.text2,
                        ),
                      ),
                      _AlbumDownloadButton(albumId: albumId, pistas: pistas),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PistaList(
                pistas: pistas,
                numbered: true,
                showCover: false,
              ),
            ),
          ],
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
