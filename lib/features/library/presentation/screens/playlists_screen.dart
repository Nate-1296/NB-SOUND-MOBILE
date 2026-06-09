import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/search/fuzzy.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/section_label.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../application/library_filters.dart';
import '../../application/library_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/library_filter_bar.dart';
import '../widgets/playlist_dialogs.dart';

/// Pestaña Playlists: playlists locales del teléfono (editables) y las del PC
/// (solo lectura). El botón "+" crea una playlist local.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    // Bases sin filtrar (deciden el estado vacío y si se muestra la barra).
    final List<PlaylistLocal> localesBase =
        ref.watch(playlistsLocalesProvider).value ?? const <PlaylistLocal>[];
    final List<Playlist> guardadasBase = ref.watch(playlistsGuardadasProvider);
    final List<Playlist> delPcBase =
        ref.watch(playlistsDelPcNoGuardadasProvider);
    final bool baseVacia =
        localesBase.isEmpty && guardadasBase.isEmpty && delPcBase.isEmpty;

    if (baseVacia) {
      return Column(
        children: <Widget>[
          _topBar(context, ref, c),
          Expanded(
            child: _Empty(onCrear: () async {
              final int? id = await crearPlaylistLocal(context, ref);
              if (id != null && context.mounted) {
                context.push('/playlist-local/$id');
              }
            }),
          ),
        ],
      );
    }

    // Filtro + orden (difuso, persistido) aplicado a las tres listas.
    final String q = normalizar(ref.watch(queryPlaylistsProvider));
    final OrdenPlaylists orden = ref.watch(ordenPlaylistsProvider);
    final Map<int, int> conteosLocal =
        ref.watch(conteosPlaylistsLocalesProvider).value ?? const <int, int>{};
    final Map<int, int> conteosPc =
        ref.watch(conteosPlaylistsPcProvider).value ?? const <int, int>{};

    final List<PlaylistLocal> locales = filtrarOrdenarPlaylistsLocales(
        localesBase, q, orden, conteosLocal);
    final List<Playlist> guardadas =
        filtrarOrdenarPlaylistsPc(guardadasBase, q, orden, conteosPc);
    final List<Playlist> delPc =
        filtrarOrdenarPlaylistsPc(delPcBase, q, orden, conteosPc);
    final bool hayTuyas = locales.isNotEmpty || guardadas.isNotEmpty;
    final bool nada = !hayTuyas && delPc.isEmpty;

    return Column(
      children: <Widget>[
        _topBar(context, ref, c),
        LibraryFilterBar(
          hint: 'Buscar playlists',
          ordenActivo: orden != OrdenPlaylists.nombreAsc,
          onChanged: (String v) =>
              ref.read(queryPlaylistsProvider.notifier).set(v),
          onAbrirOrden: () => mostrarOrdenSheet<OrdenPlaylists>(
            context: context,
            titulo: 'Ordenar playlists',
            opciones: OrdenPlaylists.values,
            actual: orden,
            etiqueta: (OrdenPlaylists o) => o.etiqueta,
            onSelect: (OrdenPlaylists o) =>
                ref.read(ordenPlaylistsProvider.notifier).seleccionar(o),
            onLimpiar: () =>
                ref.read(ordenPlaylistsProvider.notifier).limpiar(),
          ),
        ),
        Expanded(
          child: nada
              ? Center(
                  child: Text(
                    'Sin resultados',
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 14,
                      color: c.text3,
                    ),
                  ),
                )
              : MaxWidth(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                    children: <Widget>[
                      if (hayTuyas) ...<Widget>[
                        const SectionLabel(label: 'Tus playlists'),
                        _Grid(
                          children: <Widget>[
                            for (final PlaylistLocal pl in locales)
                              LocalPlaylistCard(playlist: pl),
                            for (final Playlist pl in guardadas)
                              PlaylistCard(playlist: pl),
                          ],
                        ),
                      ],
                      if (delPc.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        const SectionLabel(label: 'Del PC'),
                        _Grid(
                          children: <Widget>[
                            for (final Playlist pl in delPc)
                              PlaylistCard(playlist: pl),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context, WidgetRef ref, NbColors c) => TopBar(
        title: 'Playlists',
        onProfile: () => context.push('/profile'),
        trailing: IconButton(
          tooltip: 'Nueva playlist',
          onPressed: () async {
            final int? id = await crearPlaylistLocal(context, ref);
            if (id != null && context.mounted) {
              context.push('/playlist-local/$id');
            }
          },
          icon: Icon(AppIcons.plus, size: 24, color: c.accent),
        ),
      );
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
      mainAxisSpacing: 18,
      crossAxisSpacing: 16,
      childAspectRatio: 0.82,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: children,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCrear});
  final VoidCallback onCrear;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(AppIcons.note, size: 52, color: c.text3),
            const SizedBox(height: 16),
            Text(
              'Aún no tienes playlists',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Crea una para organizar tu música a tu manera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c.text2,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCrear,
              style: FilledButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: c.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: const StadiumBorder(),
              ),
              icon: Icon(AppIcons.plus, color: c.ink, size: 20),
              label: Text(
                'Nueva playlist',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w700,
                  color: c.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
