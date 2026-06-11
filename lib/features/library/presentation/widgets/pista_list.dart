import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../../../shared/widgets/track_row.dart';
import '../../../offline/application/download_providers.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../../player/application/player_controller.dart';
import '../../../player/application/sleep_timer.dart';
import '../../../remote_control/application/remote_controller.dart';
import '../../../remote_control/presentation/destination_sheet.dart';
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
  void Function(Pista)? onOpen,
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
      onOpen?.call(p);
      final PlaybackActions acciones = ref.read(playbackActionsProvider);
      if (comoColeccion) {
        acciones.reproducirColeccion(pistas, i);
      } else {
        acciones.reproducirPistaUnica(p);
      }
    },
    onMore: () => mostrarMenuPista(context, ref, p),
    swipeKey: ValueKey<String>('q-$i-${p.id}'),
    onSwipeQueue: () =>
        ref.read(playbackActionsProvider).encolarColeccion(<Pista>[p]),
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
    this.onOpen,
  });

  final List<Pista> pistas;
  final bool comoColeccion;
  final bool numbered;
  final bool showCover;

  /// Efecto secundario al tocar una fila (p. ej. registrar en el historial).
  final void Function(Pista)? onOpen;

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
        onOpen: onOpen,
      ),
    );
  }
}

/// Acción extra opcional para el menú de pista (p. ej. "Quitar de la playlist").
typedef AccionMenuPista = ({String label, IconData icon, VoidCallback onTap});

/// Menú contextual de una pista: reproducir, cola, favorito, añadir a playlist,
/// ir al álbum/artista, descargar y (en remoto) acciones del PC. Con
/// [accionRemover] añade una opción destructiva al final (quitar de una lista).
Future<void> mostrarMenuPista(
  BuildContext context,
  WidgetRef ref,
  Pista pista, {
  AccionMenuPista? accionRemover,
  bool ajustesReproductor = false,
}) {
  final NbColors c = context.nb;
  final bool esFav = (ref.read(favoritasIdsProvider).value ?? const <int>{})
      .contains(pista.id);
  final bool descargada = (ref.read(descargadasProvider).value ?? const <int>{})
      .contains(pista.id);
  final bool enPc = ref.read(playbackTargetProvider) == PlaybackTarget.remote &&
      ref.read(remoteControllerProvider).conectado;
  return mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Column(
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
                ref.read(playbackActionsProvider).reproducirPistaUnica(pista);
              },
            ),
            // Cola local (en remoto, la cola es del PC: ver "Añadir a la cola del
            // PC" más abajo).
            if (!enPc) ...<Widget>[
              ListTile(
                leading: Icon(AppIcons.next, color: c.text),
                title: Text(
                  'Reproducir a continuación',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(playerControllerProvider.notifier)
                      .reproducirACont(pista);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.queue, color: c.text),
                title: Text(
                  'Añadir a la cola',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  ref.read(playerControllerProvider.notifier).addToQueue(pista);
                },
              ),
            ],
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
            if (pista.albumId != null)
              ListTile(
                leading: Icon(AppIcons.disc, color: c.text),
                title: Text(
                  'Ir al álbum',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/album/${pista.albumId}');
                },
              ),
            if (pista.artistaId != null)
              ListTile(
                leading: Icon(AppIcons.user, color: c.text),
                title: Text(
                  'Ir al artista',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push('/artist/${pista.artistaId}');
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
            if (ajustesReproductor) ...<Widget>[
              ListTile(
                leading: Icon(AppIcons.cast, color: c.text),
                title: Text(
                  'Reproducir en…',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  mostrarSelectorDestino(context, ref);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.sliders, color: c.text),
                title: Text(
                  'Velocidad',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _mostrarVelocidad(context, ref);
                },
              ),
              ListTile(
                leading: Icon(AppIcons.clock, color: c.text),
                title: Text(
                  'Temporizador de apagado',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _mostrarTemporizador(context, ref);
                },
              ),
            ],
            if (accionRemover != null)
              ListTile(
                leading: Icon(accionRemover.icon, color: _menuDanger),
                title: Text(
                  accionRemover.label,
                  style: const TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: _menuDanger,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  accionRemover.onTap();
                },
              ),
          ],
        );
    },
  );
}

/// Rojo de acción destructiva en el menú de pista (convencional, fuera del tema).
const Color _menuDanger = Color(0xFFE5484D);

/// Menú de una colección (álbum/playlist): "Añadir a la cola" + acciones extra.
Future<void> mostrarMenuColeccion(
  BuildContext context,
  WidgetRef ref,
  List<Pista> pistas, {
  List<AccionMenuPista> extras = const <AccionMenuPista>[],
}) {
  return mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      final NbColors c = sheetContext.nb;
      return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(AppIcons.queue, color: c.text),
              title: Text(
                'Añadir a la cola',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              onTap: pistas.isEmpty
                  ? null
                  : () {
                      Navigator.of(sheetContext).pop();
                      ref
                          .read(playbackActionsProvider)
                          .encolarColeccion(pistas);
                    },
            ),
            for (final AccionMenuPista a in extras)
              ListTile(
                leading: Icon(a.icon, color: c.text),
                title: Text(
                  a.label,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  a.onTap();
                },
              ),
            const SizedBox(height: 8),
          ],
        );
    },
  );
}

Widget _tituloHoja(NbColors c, String titulo) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          titulo,
          style: TextStyle(
            fontFamily: NbFonts.display,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      ),
    );

String _fmtVel(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Hoja de velocidad de reproducción.
void _mostrarVelocidad(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext ctx, WidgetRef r, _) {
          final double actual = r.watch(
              playerControllerProvider.select((PlayerState s) => s.velocidad));
          return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _tituloHoja(c, 'Velocidad'),
                for (final double v in const <double>[
                  0.5,
                  0.75,
                  1.0,
                  1.25,
                  1.5,
                  1.75,
                  2.0,
                ])
                  ListTile(
                    dense: true,
                    onTap: () {
                      r
                          .read(playerControllerProvider.notifier)
                          .setVelocidad(v);
                      Navigator.of(sheetContext).pop();
                    },
                    leading: Icon(
                      (v - actual).abs() < 0.01
                          ? AppIcons.check
                          : AppIcons.list,
                      color: (v - actual).abs() < 0.01 ? c.accent : c.text3,
                    ),
                    title: Text(
                      v == 1.0 ? 'Normal (1×)' : '${_fmtVel(v)}×',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontWeight: FontWeight.w600,
                        color: (v - actual).abs() < 0.01 ? c.accent : c.text,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
        },
      );
    },
  );
}

/// Hoja del temporizador de apagado.
void _mostrarTemporizador(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Consumer(
        builder: (BuildContext ctx, WidgetRef r, _) {
          final Duration? activo = r.watch(sleepTimerProvider);
          return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _tituloHoja(c, 'Temporizador de apagado'),
                for (final int m in const <int>[5, 10, 15, 30, 45, 60])
                  ListTile(
                    dense: true,
                    onTap: () {
                      r
                          .read(sleepTimerProvider.notifier)
                          .activar(Duration(minutes: m));
                      Navigator.of(sheetContext).pop();
                    },
                    leading: Icon(
                      activo?.inMinutes == m ? AppIcons.check : AppIcons.clock,
                      color: activo?.inMinutes == m ? c.accent : c.text3,
                    ),
                    title: Text(
                      '$m minutos',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontWeight: FontWeight.w600,
                        color: activo?.inMinutes == m ? c.accent : c.text,
                      ),
                    ),
                  ),
                if (activo != null)
                  ListTile(
                    dense: true,
                    onTap: () {
                      r.read(sleepTimerProvider.notifier).cancelar();
                      Navigator.of(sheetContext).pop();
                    },
                    leading: const Icon(AppIcons.close, color: _menuDanger),
                    title: const Text(
                      'Desactivar',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontWeight: FontWeight.w600,
                        color: _menuDanger,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            );
        },
      );
    },
  );
}
