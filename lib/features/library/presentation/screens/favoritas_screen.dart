import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/duration_format.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sub_header.dart';
import '../../../player/application/playback.dart';
import '../../application/library_providers.dart';
import '../widgets/pista_list.dart';

/// Colección "Tus me gusta": todas las pistas favoritas, reproducibles como una
/// playlist de primera clase (Reproducir / Aleatorio). Estilo Spotify.
class FavoritasScreen extends ConsumerWidget {
  const FavoritasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final List<Pista> pistas =
        ref.watch(favoritasProvider).value ?? const <Pista>[];
    final double total =
        pistas.fold<double>(0, (double a, Pista p) => a + p.duracionSeg);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: MaxWidth(
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Column(
                  children: <Widget>[
                    const SubHeader(title: 'Tus me gusta'),
                    Center(
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: <Color>[c.accent, c.ambient],
                          ),
                          boxShadow: const <BoxShadow>[
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 24,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(AppIcons.heartFilled,
                            color: c.ink, size: 84),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Tus me gusta',
                            style: TextStyle(
                              fontFamily: NbFonts.display,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            pistas.isEmpty
                                ? 'Marca canciones con ♥ para tenerlas aquí'
                                : '${pistas.length} pistas  ·  ${formatLongDuration(total)}',
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: c.text2,
                            ),
                          ),
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
                              const SizedBox(width: 12),
                              IconButton(
                                tooltip: 'Reproducir aleatorio',
                                onPressed: pistas.isEmpty
                                    ? null
                                    : () => ref
                                        .read(playbackActionsProvider)
                                        .reproducirColeccionAleatorio(pistas),
                                icon: Icon(AppIcons.shuffle, color: c.text2),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
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
