import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/placeholder_body.dart';
import '../../../../shared/widgets/section_head.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../application/library_providers.dart';
import '../../application/search_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';

/// Pestaña Buscar: búsqueda difusa (tolerante a errores y acentos) sobre el
/// catálogo. Muestra artistas (círculos), álbumes y canciones, ordenados de más a
/// menos coincidencia.
class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    // Debounce ligero: coalesce pulsaciones rápidas sin que se note lag.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), () {
      ref.read(busquedaQueryProvider.notifier).set(v);
    });
  }

  void _limpiar() {
    _debounce?.cancel();
    _controller.clear();
    ref.read(busquedaQueryProvider.notifier).set('');
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final String query = ref.watch(busquedaQueryProvider);
    final ResultadosBusqueda resultados =
        ref.watch(resultadosBusquedaProvider);

    // Pestaña raíz: atrás cerraría la app. Si hay búsqueda activa, se intercepta
    // para limpiarla (y cerrar el teclado) en lugar de salir.
    return PopScope<Object?>(
      canPop: query.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _limpiar();
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: <Widget>[
          TopBar(title: 'Buscar', onProfile: () => context.push('/profile')),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: TextField(
              controller: _controller,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 15,
                color: c.text,
              ),
              decoration: InputDecoration(
                hintText: 'Canciones, artistas, álbumes',
                hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
                prefixIcon: Icon(AppIcons.search, color: c.text3, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(AppIcons.close, color: c.text3, size: 18),
                        onPressed: _limpiar,
                      ),
                filled: true,
                fillColor: c.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
          Expanded(child: MaxWidth(child: _body(query, resultados))),
        ],
      ),
    );
  }

  Widget _body(String query, ResultadosBusqueda r) {
    if (query.trim().isEmpty) {
      return const PlaceholderBody(
        icon: AppIcons.search,
        title: 'Busca en tu biblioteca',
        subtitle: 'Canciones, artistas o álbumes. Entiende errores y acentos.',
      );
    }
    if (r.estaVacio) {
      return const PlaceholderBody(
        icon: AppIcons.search,
        title: 'Sin resultados',
        subtitle: 'Prueba con otras palabras.',
      );
    }
    return CustomScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      slivers: <Widget>[
        if (r.artistas.isNotEmpty)
          SliverToBoxAdapter(child: _ArtistasRail(artistas: r.artistas)),
        if (r.albums.isNotEmpty)
          SliverToBoxAdapter(child: _AlbumesRail(albums: r.albums)),
        if (r.pistas.isNotEmpty) ...<Widget>[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
              child: SectionHead(title: 'Canciones'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
            sliver: PistaSliverList(pistas: r.pistas, comoColeccion: false),
          ),
        ],
      ],
    );
  }
}

/// Carrusel horizontal de artistas (círculos) en los resultados.
class _ArtistasRail extends StatelessWidget {
  const _ArtistasRail({required this.artistas});
  final List<Artista> artistas;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: SectionHead(title: 'Artistas'),
        ),
        SizedBox(
          height: 168,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: artistas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) =>
                ArtistCircle(artista: artistas[i], size: 104),
          ),
        ),
      ],
    );
  }
}

/// Carrusel horizontal de álbumes en los resultados.
class _AlbumesRail extends StatelessWidget {
  const _AlbumesRail({required this.albums});
  final List<Album> albums;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.fromLTRB(18, 14, 18, 4),
          child: SectionHead(title: 'Álbumes'),
        ),
        SizedBox(
          height: 198,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: albums.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (BuildContext context, int i) =>
                SizedBox(width: 150, child: AlbumCard(album: albums[i])),
          ),
        ),
      ],
    );
  }
}
