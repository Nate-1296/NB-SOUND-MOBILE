import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../application/library_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/playlist_dialogs.dart';

/// Pestaña Playlists: playlists locales del teléfono (editables) y las del PC
/// (solo lectura). El botón "+" crea una playlist local.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final List<PlaylistLocal> locales =
        ref.watch(playlistsLocalesProvider).value ?? const <PlaylistLocal>[];
    // "Tus playlists" = locales + playlists del PC guardadas; "Del PC" = el resto.
    final List<Playlist> guardadas = ref.watch(playlistsGuardadasProvider);
    final List<Playlist> delPc = ref.watch(playlistsDelPcNoGuardadasProvider);
    final bool hayTuyas = locales.isNotEmpty || guardadas.isNotEmpty;

    return Column(
      children: <Widget>[
        TopBar(
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
        ),
        Expanded(
          child: (!hayTuyas && delPc.isEmpty)
              ? _Empty(onCrear: () async {
                  final int? id = await crearPlaylistLocal(context, ref);
                  if (id != null && context.mounted) {
                    context.push('/playlist-local/$id');
                  }
                })
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                  children: <Widget>[
                    if (hayTuyas) ...<Widget>[
                      const _Header(label: 'Tus playlists'),
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
                      const _Header(label: 'Del PC'),
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
      ],
    );
  }
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

class _Header extends StatelessWidget {
  const _Header({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 0, 12),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: c.text3,
        ),
      ),
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
