import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/sub_header.dart';
import '../../../offline/application/image_resolver.dart';
import '../../../player/application/playback.dart';
import '../../application/library_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';

/// Detalle de artista: imagen, álbumes y pistas.
class ArtistDetailScreen extends ConsumerWidget {
  const ArtistDetailScreen({super.key, required this.artistId});

  final int artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final Artista? artista = ref.watch(artistaProvider(artistId)).value;
    final List<Album> albums =
        ref.watch(albumsDeArtistaProvider(artistId)).value ??
            const <Album>[];
    final List<Pista> pistasRaw =
        ref.watch(pistasDeArtistaProvider(artistId)).value ??
            const <Pista>[];
    // "Populares": las más reproducidas primero (como Spotify), no alfabético.
    final Map<int, int> conteo =
        ref.watch(conteoPorPistaProvider).value ?? const <int, int>{};
    final List<Pista> pistas = pistasPorPopularidad(pistasRaw, conteo);

    final ImageProvider? img = ref.watch(coverResolverProvider).imageFor(
          artista?.imagenPath,
          cacheWidth: coverCachePx(context, 160),
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: MaxWidth(
          child: CustomScrollView(
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Column(
                children: <Widget>[
                  SubHeader(title: artista?.nombre ?? 'Artista'),
                  Center(
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: c.bg3,
                        shape: BoxShape.circle,
                        image: img != null
                            ? DecorationImage(image: img, fit: BoxFit.cover)
                            : null,
                        boxShadow: const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 24,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: img == null
                          ? Icon(AppIcons.user, color: c.text3, size: 48)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      artista?.nombre ?? '',
                      style: TextStyle(
                        fontFamily: NbFonts.display,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ),
                  Center(
                    child: Text(
                      '${albums.length} álbumes · ${pistas.length} pistas',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: c.text2,
                      ),
                    ),
                  ),
                  if (pistas.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: () => ref
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
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: 'Reproducir aleatorio',
                          onPressed: () => ref
                              .read(playbackActionsProvider)
                              .reproducirColeccionAleatorio(pistas),
                          icon: Icon(AppIcons.shuffle, color: c.text2),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (albums.isNotEmpty) ...<Widget>[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
                      child: SectionHead(title: 'Álbumes'),
                    ),
                    SizedBox(
                      height: 196,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        itemCount: albums.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 14),
                        itemBuilder: (BuildContext context, int i) => SizedBox(
                            width: 148, child: AlbumCard(album: albums[i])),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 0),
                    child: SectionHead(title: 'Populares'),
                  ),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              sliver: PistaSliverList(pistas: pistas),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
