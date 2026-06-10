import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/utils/duration_format.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../application/library_providers.dart';
import '../../application/playlist_covers.dart';
import '../widgets/pista_list.dart';
import '../widgets/playlist_dialogs.dart';

/// Rojo de acción destructiva (convencional, independiente del tema).
const Color _danger = Color(0xFFE5484D);

/// Detalle de una playlist LOCAL (editable): reproducir, renombrar, eliminar,
/// quitar pistas y reordenar.
class LocalPlaylistDetailScreen extends ConsumerWidget {
  const LocalPlaylistDetailScreen({super.key, required this.playlistId});

  final int playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final PlaylistLocal? playlist =
        ref.watch(playlistLocalProvider(playlistId)).value;
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistLocalProvider(playlistId)).value ??
            const <Pista>[];
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final double total =
        pistas.fold<double>(0, (double a, Pista p) => a + p.duracionSeg);
    final int coversPx = coverCachePx(context, 200);
    final List<ImageProvider> covers = <ImageProvider>[
      for (final String path in portadasDistintas(pistas))
        if (resolver.imageFor(path, cacheWidth: coversPx)
            case final ImageProvider img)
          img,
    ];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: MaxWidth(
          child: Column(
          children: <Widget>[
            _Header(
              titulo: playlist?.nombre ?? 'Playlist',
              onRenombrar: playlist == null
                  ? null
                  : () async {
                      final ({String nombre, String descripcion})? r =
                          await editarDetallesPlaylist(
                        context,
                        nombreInicial: playlist.nombre,
                        descripcionInicial: playlist.descripcion ?? '',
                      );
                      if (r != null && r.nombre.isNotEmpty) {
                        await ref
                            .read(localPlaylistsDaoProvider)
                            .actualizarDetalles(
                              playlistId,
                              r.nombre,
                              r.descripcion.isEmpty ? null : r.descripcion,
                            );
                      }
                    },
              onEliminar: () async {
                final bool ok = await _confirmarEliminar(context);
                if (ok) {
                  await ref
                      .read(localPlaylistsDaoProvider)
                      .borrar(playlistId);
                  if (context.mounted) {
                    context.pop();
                  }
                }
              },
              onEncolar: () =>
                  ref.read(playbackActionsProvider).encolarColeccion(pistas),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 28),
                children: <Widget>[
                  const SizedBox(height: 8),
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
                        if ((playlist?.descripcion ?? '').isNotEmpty) ...<Widget>[
                          const SizedBox(height: 8),
                          Text(
                            playlist!.descripcion!,
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              fontSize: 13.5,
                              height: 1.4,
                              color: c.text3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: pistas.isEmpty
                                  ? null
                                  : () => ref
                                      .read(playbackActionsProvider)
                                      .reproducirColeccion(pistas, 0),
                              style: FilledButton.styleFrom(
                                backgroundColor: c.accent,
                                foregroundColor: c.ink,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 28, vertical: 12),
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
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: 'Reproducir aleatorio',
                              onPressed: pistas.isEmpty
                                  ? null
                                  : () => ref
                                      .read(playbackActionsProvider)
                                      .reproducirColeccionAleatorio(pistas),
                              icon: Icon(AppIcons.shuffle, color: c.text2),
                            ),
                            const SizedBox(width: 4),
                            OutlinedButton.icon(
                              onPressed: () => agregarPistasAPlaylist(
                                  context, ref, playlistId),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: c.text,
                                side: BorderSide(color: c.line2),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: const StadiumBorder(),
                              ),
                              icon: Icon(AppIcons.plus, color: c.text, size: 20),
                              label: Text(
                                'Añadir',
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontWeight: FontWeight.w700,
                                  color: c.text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pistas.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
                      child: Text(
                        'Toca "Añadir" para buscar y agregar canciones, o usa el '
                        'menú "⋮" de cualquier pista.',
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 13.5,
                          height: 1.5,
                          color: c.text3,
                        ),
                      ),
                    )
                  else
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: pistas.length,
                      // onReorderItem entrega newIndex ya ajustado al elemento
                      // removido en oldIndex (API no deprecada).
                      onReorderItem: (int oldIndex, int newIndex) {
                        final List<int> ids =
                            <int>[for (final Pista p in pistas) p.id];
                        final int moved = ids.removeAt(oldIndex);
                        ids.insert(newIndex, moved);
                        ref
                            .read(localPlaylistsDaoProvider)
                            .reordenar(playlistId, ids);
                      },
                      itemBuilder: (BuildContext context, int i) {
                        final Pista p = pistas[i];
                        return _TrackRow(
                          key: ValueKey<int>(p.id),
                          pista: p,
                          resolver: resolver,
                          onPlay: () => ref
                              .read(playbackActionsProvider)
                              .reproducirColeccion(pistas, i),
                          onMore: () => mostrarMenuPista(
                            context,
                            ref,
                            p,
                            accionRemover: (
                              label: 'Quitar de la playlist',
                              icon: AppIcons.close,
                              onTap: () => ref
                                  .read(localPlaylistsDaoProvider)
                                  .quitarPista(playlistId, p.id),
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Future<bool> _confirmarEliminar(BuildContext context) async {
    final NbColors c = context.nb;
    final bool? r = await showDialog<bool>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        backgroundColor: c.bg2,
        title: Text('Eliminar playlist',
            style: TextStyle(color: c.text, fontFamily: NbFonts.display)),
        content: Text(
          'Se borrará esta playlist (no afecta a tus pistas ni al PC).',
          style: TextStyle(color: c.text2, fontFamily: NbFonts.ui),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: c.text2)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: _danger),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return r ?? false;
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.titulo,
    required this.onRenombrar,
    required this.onEliminar,
    required this.onEncolar,
  });

  final String titulo;
  final VoidCallback? onRenombrar;
  final VoidCallback onEliminar;
  final VoidCallback onEncolar;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: Icon(AppIcons.chevronDown, color: c.text, size: 26),
          ),
          Expanded(
            child: Text(
              titulo,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
          ),
          PopupMenuButton<String>(
            color: c.bg2,
            icon: Icon(AppIcons.moreV, color: c.text2),
            onSelected: (String v) {
              if (v == 'renombrar') {
                onRenombrar?.call();
              } else if (v == 'eliminar') {
                onEliminar();
              } else if (v == 'cola') {
                onEncolar();
              }
            },
            itemBuilder: (BuildContext _) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: 'cola',
                child: Text('Añadir a la cola', style: TextStyle(color: c.text)),
              ),
              PopupMenuItem<String>(
                value: 'renombrar',
                child: Text('Editar detalles', style: TextStyle(color: c.text)),
              ),
              const PopupMenuItem<String>(
                value: 'eliminar',
                child: Text('Eliminar', style: TextStyle(color: _danger)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  const _TrackRow({
    super.key,
    required this.pista,
    required this.resolver,
    required this.onPlay,
    required this.onMore,
  });

  final Pista pista;
  final CoverResolver resolver;
  final VoidCallback onPlay;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ListTile(
      key: key,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      onTap: onPlay,
      leading: Cover(
        image: resolver.imageFor(
          pista.coverPath,
          cacheWidth: coverCachePx(context, 44),
        ),
        size: 44,
        radius: 8,
        shadow: false,
      ),
      title: Text(
        pista.titulo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        pista.artistaNombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text2,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            tooltip: 'Más opciones',
            visualDensity: VisualDensity.compact,
            onPressed: onMore,
            icon: Icon(AppIcons.moreV, size: 18, color: c.text3),
          ),
          Icon(AppIcons.dragHandle, size: 20, color: c.text3),
        ],
      ),
    );
  }
}
