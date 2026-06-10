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
import '../../../profile/application/profile_providers.dart';
import '../../application/library_filters.dart';
import '../../application/library_providers.dart';
import '../../application/playlist_pins.dart';
import '../widgets/library_cards.dart';
import '../widgets/library_filter_bar.dart';
import '../widgets/playlist_dialogs.dart';

/// Un elemento de playlist a renderizar, con su token de anclaje y si está
/// anclado (para flotar arriba y pintar el distintivo).
typedef _Item = ({String token, bool anclada, Widget card});

/// Pestaña Playlists: playlists locales del teléfono (editables) y las del PC
/// (solo lectura). Las **ancladas** quedan arriba en su sección (máx. 4 por
/// sección). El botón "+" crea una playlist local.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    // Bases sin filtrar (deciden el estado vacío y los conteos de anclaje).
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

    // Estado de anclaje (reactivo). Las cuentas por sección se calculan sobre las
    // bases (una anclada filtrada por búsqueda sigue contando para el máximo).
    final Set<String> ancladas =
        (ref.watch(playlistsAncladasProvider).value ?? const <String>[]).toSet();
    final int ancladasTus = <String>[
      for (final PlaylistLocal p in localesBase) tokenLocal(p.id),
      for (final Playlist p in guardadasBase) tokenPc(p.id),
    ].where(ancladas.contains).length;
    final int ancladasDelPc = <String>[
      for (final Playlist p in delPcBase) tokenPc(p.id),
    ].where(ancladas.contains).length;

    // Construye los ítems de cada sección con anclaje y los ordena (ancladas
    // arriba), preservando el orden de filtro/orden dentro de cada grupo.
    List<_Item> tusItems = <_Item>[
      for (final PlaylistLocal pl in locales)
        (
          token: tokenLocal(pl.id),
          anclada: ancladas.contains(tokenLocal(pl.id)),
          card: LocalPlaylistCard(
            playlist: pl,
            pinned: ancladas.contains(tokenLocal(pl.id)),
            onLongPress: () => _accionesAnclar(
              context,
              ref,
              nombre: pl.nombre,
              token: tokenLocal(pl.id),
              anclada: ancladas.contains(tokenLocal(pl.id)),
              ancladasEnSeccion: ancladasTus,
            ),
          ),
        ),
      for (final Playlist pl in guardadas)
        (
          token: tokenPc(pl.id),
          anclada: ancladas.contains(tokenPc(pl.id)),
          card: PlaylistCard(
            playlist: pl,
            pinned: ancladas.contains(tokenPc(pl.id)),
            onLongPress: () => _accionesAnclar(
              context,
              ref,
              nombre: pl.nombre,
              token: tokenPc(pl.id),
              anclada: ancladas.contains(tokenPc(pl.id)),
              ancladasEnSeccion: ancladasTus,
            ),
          ),
        ),
    ];
    tusItems = conAncladasArriba(tusItems, ancladas, (_Item e) => e.token);

    List<_Item> delPcItems = <_Item>[
      for (final Playlist pl in delPc)
        (
          token: tokenPc(pl.id),
          anclada: ancladas.contains(tokenPc(pl.id)),
          card: PlaylistCard(
            playlist: pl,
            pinned: ancladas.contains(tokenPc(pl.id)),
            onLongPress: () => _accionesAnclar(
              context,
              ref,
              nombre: pl.nombre,
              token: tokenPc(pl.id),
              anclada: ancladas.contains(tokenPc(pl.id)),
              ancladasEnSeccion: ancladasDelPc,
            ),
          ),
        ),
    ];
    delPcItems = conAncladasArriba(delPcItems, ancladas, (_Item e) => e.token);

    final bool hayTuyas = tusItems.isNotEmpty;
    final bool nada = !hayTuyas && delPcItems.isEmpty;

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
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  children: <Widget>[
                    if (hayTuyas) ...<Widget>[
                      const SectionLabel(label: 'Tus playlists'),
                      _Grid(
                        children: <Widget>[
                          for (final _Item it in tusItems) it.card,
                        ],
                      ),
                    ],
                    if (delPcItems.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      const SectionLabel(label: 'Del PC'),
                      _Grid(
                        children: <Widget>[
                          for (final _Item it in delPcItems) it.card,
                        ],
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  /// Hoja de acciones de anclaje (long-press). Ancla/desancla respetando el máximo
  /// por sección.
  void _accionesAnclar(
    BuildContext context,
    WidgetRef ref, {
    required String nombre,
    required String token,
    required bool anclada,
    required int ancladasEnSeccion,
  }) {
    final NbColors c = context.nb;
    showModalBottomSheet<void>(
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
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    nombre,
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
              ),
              ListTile(
                leading: Icon(
                  anclada ? AppIcons.pinFilled : AppIcons.pin,
                  color: anclada ? c.accent : c.text,
                ),
                title: Text(
                  anclada ? 'Quitar de arriba' : 'Anclar arriba',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                subtitle: anclada
                    ? null
                    : Text(
                        'Hasta $kMaxAncladasPorSeccion por sección',
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 12,
                          color: c.text3,
                        ),
                      ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  final List<String> actuales =
                      ref.read(playlistsAncladasProvider).value ??
                          const <String>[];
                  final PlaylistPinsController ctrl =
                      ref.read(playlistPinsControllerProvider);
                  if (anclada) {
                    await ctrl.desanclar(actuales, token);
                  } else if (puedeAnclar(ancladasEnSeccion)) {
                    await ctrl.anclar(actuales, token);
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Máximo $kMaxAncladasPorSeccion ancladas en esta sección.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _topBar(BuildContext context, WidgetRef ref, NbColors c) => TopBar(
        title: 'Playlists',
        onProfile: () => context.push('/profile'),
        avatarInicial: ref.watch(inicialPerfilProvider),
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
