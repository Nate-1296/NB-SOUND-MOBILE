import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/media_source.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/track_row.dart';
import '../../../offline/application/download_providers.dart';
import '../../../player/application/playback.dart';
import '../../../player/application/player_controller.dart';
import '../../../remote_control/application/remote_controller.dart';
import '../../../sync/application/remote_media_provider.dart';
import '../../application/library_providers.dart';
import 'playlist_dialogs.dart';

/// Lista (no scrollable) de pistas: reproduce en su propia cola al tocar,
/// resalta la pista en curso y marca las favoritas. El llamador la envuelve en
/// un contexto scrollable.
class PistaList extends ConsumerWidget {
  const PistaList({
    super.key,
    required this.pistas,
    this.showCover = true,
    this.numbered = false,
    this.comoColeccion = true,
  });

  final List<Pista> pistas;
  final bool showCover;
  final bool numbered;

  /// Si true (álbum/playlist), tocar una pista encola toda la lista desde ahí;
  /// si false (búsqueda, pistas sueltas), reproduce solo esa pista.
  final bool comoColeccion;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Set<int> favoritas =
        ref.watch(favoritasIdsProvider).value ?? const <int>{};
    final Set<int> descargadas =
        ref.watch(descargadasProvider).value ?? const <int>{};
    final int? currentId =
        ref.watch(playerControllerProvider.select((PlayerState s) => s.current?.id));
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);

    return Column(
      children: <Widget>[
        for (int i = 0; i < pistas.length; i++)
          TrackRow(
            title: pistas[i].titulo,
            subtitle: pistas[i].albumTitulo == null
                ? pistas[i].artistaNombre
                : '${pistas[i].artistaNombre} · ${pistas[i].albumTitulo}',
            cover: showCover ? coverImage(pistas[i].coverPath, remote) : null,
            durationSeconds: pistas[i].duracionSeg,
            index: numbered ? i + 1 : null,
            showCover: showCover,
            playing: pistas[i].id == currentId,
            liked: favoritas.contains(pistas[i].id),
            downloaded: descargadas.contains(pistas[i].id),
            onTap: () {
              final ctrl = ref.read(playerControllerProvider.notifier);
              if (comoColeccion) {
                ctrl.reproducir(pistas, i);
              } else {
                ctrl.reproducir(<Pista>[pistas[i]], 0);
              }
            },
            onMore: () => mostrarMenuPista(context, ref, pistas[i]),
          ),
      ],
    );
  }
}

/// Menú contextual de una pista (reproducir, favorito).
Future<void> mostrarMenuPista(
  BuildContext context,
  WidgetRef ref,
  Pista pista,
) {
  final NbColors c = context.nb;
  final bool esFav = (ref.read(favoritasIdsProvider).value ?? const <int>{})
      .contains(pista.id);
  final bool descargada = (ref.read(descargadasProvider).value ?? const <int>{})
      .contains(pista.id);
  final bool enPc = ref.read(playbackTargetProvider) == PlaybackTarget.remote &&
      ref.read(remoteControllerProvider).conectado;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg2,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      pista.titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NbFonts.display,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: Icon(AppIcons.play, color: c.text),
              title: Text(
                'Reproducir',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(playerControllerProvider.notifier).reproducirPista(pista);
              },
            ),
            ListTile(
              leading: Icon(
                esFav ? AppIcons.heartFilled : AppIcons.heart,
                color: esFav ? c.accent : c.text,
              ),
              title: Text(
                esFav ? 'Quitar de favoritos' : 'Añadir a favoritos',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                ref.read(favoritesDaoProvider).setFavorita(pista.id, !esFav);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.plus, color: c.text),
              title: Text(
                'Añadir a playlist',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                anadirAPlaylist(context, ref, pista.id);
              },
            ),
            ListTile(
              leading: Icon(
                descargada ? AppIcons.downloadDone : AppIcons.download,
                color: descargada ? c.accent : c.text,
              ),
              title: Text(
                descargada ? 'Quitar descarga' : 'Descargar',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                final DownloadQueueController q =
                    ref.read(downloadQueueProvider.notifier);
                if (descargada) {
                  q.eliminar(pista.id);
                } else {
                  q.encolarPista(pista.id);
                }
              },
            ),
            if (enPc) ...<Widget>[
              ListTile(
                leading: Icon(AppIcons.cast, color: c.accent),
                title: Text(
                  'Reproducir en el PC',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(remoteControllerProvider.notifier)
                      .reproducirPista(pista.id);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.plus, color: c.accent),
                title: Text(
                  'Añadir a la cola del PC',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref
                      .read(remoteControllerProvider.notifier)
                      .encolarPista(pista.id);
                },
              ),
            ],
          ],
        ),
      );
    },
  );
}
