import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/media_source.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../../player/application/player_controller.dart';
import '../../../sync/application/remote_media_provider.dart';
import '../../application/library_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';

/// Pestaña Inicio: continuar escuchando (recientes), favoritas y álbumes.
class InicioScreen extends ConsumerWidget {
  const InicioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Pista> recientes =
        ref.watch(recientesProvider).value ?? const <Pista>[];
    final List<Pista> favoritas =
        ref.watch(favoritasProvider).value ?? const <Pista>[];
    final List<Album> albums =
        ref.watch(albumsProvider).value ?? const <Album>[];
    final bool vacio =
        recientes.isEmpty && favoritas.isEmpty && albums.isEmpty;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: <Widget>[
        TopBar(
          title: 'NB Sound',
          onProfile: () => context.push('/profile'),
          large: true,
        ),
        if (vacio)
          _BibliotecaVacia(onSync: () => context.push('/sync'))
        else ...<Widget>[
          if (recientes.isNotEmpty) ...<Widget>[
            const _Pad(child: SectionHead(title: 'Vuelve a tu música')),
            _RecientesRail(pistas: recientes.take(8).toList()),
            const SizedBox(height: 8),
          ],
          if (favoritas.isNotEmpty) ...<Widget>[
            _Pad(
              child: SectionHead(
                title: 'Tus favoritas',
                actionLabel: '${favoritas.length}',
              ),
            ),
            _Pad(child: PistaList(pistas: favoritas.take(5).toList())),
            const SizedBox(height: 16),
          ],
          if (albums.isNotEmpty) ...<Widget>[
            const _Pad(child: SectionHead(title: 'Álbumes')),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                itemCount: albums.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (BuildContext context, int i) =>
                    SizedBox(width: 148, child: AlbumCard(album: albums[i])),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

/// Estado vacío de Inicio: sin biblioteca local, guía a sincronizar con el PC.
class _BibliotecaVacia extends StatelessWidget {
  const _BibliotecaVacia({required this.onSync});
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 0),
      child: Column(
        children: <Widget>[
          Icon(AppIcons.laptop, size: 56, color: c.accent),
          const SizedBox(height: 18),
          Text(
            'Tu biblioteca está vacía',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: c.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sincroniza con NB Sound en tu PC para traer tu música por la red '
            'local.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: c.text2,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onSync,
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.ink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              shape: const StadiumBorder(),
            ),
            icon: Icon(AppIcons.cast, color: c.ink, size: 20),
            label: Text(
              'Sincronizar con PC',
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontWeight: FontWeight.w700,
                color: c.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
        child: child,
      );
}

/// Carrusel horizontal de portadas recientes (toca para reproducir).
class _RecientesRail extends ConsumerWidget {
  const _RecientesRail({required this.pistas});
  final List<Pista> pistas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    return SizedBox(
      height: 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: pistas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (BuildContext context, int i) {
          final Pista p = pistas[i];
          return GestureDetector(
            onTap: () =>
                ref.read(playerControllerProvider.notifier).reproducir(pistas, i),
            child: SizedBox(
              width: 124,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Cover(image: coverImage(p.coverPath, remote), size: 124, radius: 14),
                  const SizedBox(height: 8),
                  Text(
                    p.titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  Text(
                    p.artistaNombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
