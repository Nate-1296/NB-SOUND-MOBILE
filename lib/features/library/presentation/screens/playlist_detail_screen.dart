import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
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
import '../../../player/application/player_controller.dart';
import '../../application/library_providers.dart';
import '../../application/playlist_covers.dart';
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
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 200);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final String path in portadasDistintas(pistas))
        if (resolver.imageFor(path, cacheWidth: px) case final ImageProvider img)
          img,
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: MaxWidth(
          child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
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
                            _GuardarPlaylistButton(
                              playlistId: playlistId,
                              pistas: pistas,
                            ),
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

/// Guardar/seguir una playlist del PC: pasa a "Tus playlists", se mantiene al día
/// por el sync y descarga todo su contenido para vivir offline. Si ya está
/// guardada, muestra el progreso de descarga y permite dejar de seguirla.
class _GuardarPlaylistButton extends ConsumerWidget {
  const _GuardarPlaylistButton({required this.playlistId, required this.pistas});

  final int playlistId;
  final List<Pista> pistas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final bool guardada = ref.watch(playlistGuardadaProvider(playlistId));

    if (guardada) {
      final Set<int> completas = ref.watch(pistasCompletasProvider);
      final int total = pistas.length;
      final int hechas =
          pistas.where((Pista p) => completas.contains(p.id)).length;
      final bool descargando = total > 0 && hechas < total;
      return OutlinedButton.icon(
        onPressed: () => _confirmarDejarDeSeguir(context, ref),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.accent),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: const StadiumBorder(),
        ),
        icon: Icon(
          descargando ? AppIcons.downloading : AppIcons.downloadDone,
          size: 20,
          color: c.accent,
        ),
        label: Text(
          descargando ? 'Guardada · $hechas/$total' : 'Guardada',
          style: TextStyle(
            fontFamily: NbFonts.ui,
            fontWeight: FontWeight.w700,
            color: c.accent,
          ),
        ),
      );
    }

    return FilledButton.tonalIcon(
      onPressed: pistas.isEmpty
          ? null
          : () async {
              await ref
                  .read(followedPlaylistsDaoProvider)
                  .guardar(playlistId);
              await ref
                  .read(downloadQueueProvider.notifier)
                  .encolarPlaylist(playlistId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Guardada en Tus playlists · descargando'),
                  ),
                );
              }
            },
      style: FilledButton.styleFrom(
        backgroundColor: c.bg3,
        foregroundColor: c.text,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        shape: const StadiumBorder(),
      ),
      icon: Icon(AppIcons.download, size: 20, color: c.text),
      label: Text(
        'Guardar',
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontWeight: FontWeight.w700,
          color: c.text,
        ),
      ),
    );
  }

  Future<void> _confirmarDejarDeSeguir(
      BuildContext context, WidgetRef ref) async {
    final NbColors c = context.nb;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        backgroundColor: c.bg2,
        title: Text('Dejar de seguir',
            style: TextStyle(color: c.text, fontFamily: NbFonts.display)),
        content: Text(
          'Saldrá de "Tus playlists". Las descargas ya hechas se conservan '
          '(gestiónalas en Descargas).',
          style: TextStyle(color: c.text2, fontFamily: NbFonts.ui),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: c.text2)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: c.accent),
            child: Text('Dejar de seguir', style: TextStyle(color: c.ink)),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      await ref.read(followedPlaylistsDaoProvider).dejarDeSeguir(playlistId);
    }
  }
}
