import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/sub_header.dart';
import '../../../offline/application/image_resolver.dart';
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
    final List<Pista> pistas =
        ref.watch(pistasDeArtistaProvider(artistId)).value ??
            const <Pista>[];

    final ImageProvider? img = ref.watch(coverResolverProvider).imageFor(
          artista?.imagenPath,
          cacheWidth: coverCachePx(context, 160),
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
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
                    child: SectionHead(title: 'Pistas'),
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
    );
  }
}
