import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/track_row.dart';
import '../../../offline/application/download_providers.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../../player/application/player_controller.dart';
import '../../../remote_control/application/remote_controller.dart';
import '../../application/library_providers.dart';
import 'playlist_dialogs.dart';

/// Dependencias compartidas para construir filas de pista, recogidas **una vez
/// por lista** (no por fila) para que un `ListView.builder` no observe providers
/// en cada item.
typedef PistaRowDeps = ({
  Set<int> favoritas,
  Set<int> descargadas,
  int? currentId,
  CoverResolver resolver,
});

PistaRowDeps pistaRowDeps(WidgetRef ref) => (
      favoritas: ref.watch(favoritasIdsProvider).value ?? const <int>{},
      descargadas: ref.watch(descargadasProvider).value ?? const <int>{},
      currentId: ref.watch(
        playerControllerProvider.select((PlayerState s) => s.current?.id),
      ),
      resolver: ref.watch(coverResolverProvider),
    );

/// Construye una fila de pista. Compartido por la lista no-scrollable [PistaList]
/// y por los `ListView.builder`/slivers de las pantallas grandes (pestaña Pistas,
/// búsqueda, álbum, artista, playlist) para no duplicar lógica de tap/estado.
Widget pistaRow(
  BuildContext context,
  WidgetRef ref,
  List<Pista> pistas,
  int i,
  PistaRowDeps deps, {
  bool comoColeccion = true,
  bool numbered = false,
  bool showCover = true,
}) {
  final Pista p = pistas[i];
  return TrackRow(
    title: p.titulo,
    subtitle: p.albumTitulo == null
        ? p.artistaNombre
        : '${p.artistaNombre} · ${p.albumTitulo}',
    cover: showCover
        ? deps.resolver
            .imageFor(p.coverPath, cacheWidth: coverCachePx(context, 48))
        : null,
    durationSeconds: p.duracionSeg,
    index: numbered ? i + 1 : null,
    showCover: showCover,
    playing: p.id == deps.currentId,
    liked: deps.favoritas.contains(p.id),
    downloaded: deps.descargadas.contains(p.id),
    onTap: () {
      final ctrl = ref.read(playerControllerProvider.notifier);
      if (comoColeccion) {
        ctrl.reproducir(pistas, i);
      } else {
        ctrl.reproducir(<Pista>[p], 0);
      }
    },
    onMore: () => mostrarMenuPista(context, ref, p),
  );
}

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
    final PistaRowDeps deps = pistaRowDeps(ref);
    return Column(
      children: <Widget>[
        for (int i = 0; i < pistas.length; i++)
          pistaRow(
            context,
            ref,
            pistas,
            i,
            deps,
            comoColeccion: comoColeccion,
            numbered: numbered,
            showCover: showCover,
          ),
      ],
    );
  }
}

/// Lista de pistas **lazy** y scrollable por sí misma (`ListView.builder`), para
/// colecciones grandes (pestaña Pistas, búsqueda). Recoge las dependencias una
/// sola vez y construye filas bajo demanda.
class PistaListView extends ConsumerWidget {
  const PistaListView({
    super.key,
    required this.pistas,
    this.comoColeccion = true,
    this.numbered = false,
    this.showCover = true,
    this.padding,
  });

  final List<Pista> pistas;
  final bool comoColeccion;
  final bool numbered;
  final bool showCover;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PistaRowDeps deps = pistaRowDeps(ref);
    return ListView.builder(
      padding: padding,
      itemCount: pistas.length,
      itemBuilder: (BuildContext context, int i) => pistaRow(
        context,
        ref,
        pistas,
        i,
        deps,
        comoColeccion: comoColeccion,
        numbered: numbered,
        showCover: showCover,
      ),
    );
  }
}

/// Variante **sliver** y lazy (`SliverList.builder`) para pantallas con cabecera
/// scrollable (detalle de álbum/artista/playlist), dentro de un `CustomScrollView`.
class PistaSliverList extends ConsumerWidget {
  const PistaSliverList({
    super.key,
    required this.pistas,
    this.comoColeccion = true,
    this.numbered = false,
    this.showCover = true,
  });

  final List<Pista> pistas;
  final bool comoColeccion;
  final bool numbered;
  final bool showCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PistaRowDeps deps = pistaRowDeps(ref);
    return SliverList.builder(
      itemCount: pistas.length,
      itemBuilder: (BuildContext context, int i) => pistaRow(
        context,
        ref,
        pistas,
        i,
        deps,
        comoColeccion: comoColeccion,
        numbered: numbered,
        showCover: showCover,
      ),
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
    useRootNavigator: true,
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
