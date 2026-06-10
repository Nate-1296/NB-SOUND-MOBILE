import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/util/responsive.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/chip_pill.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../../offline/application/download_providers.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/library_filters.dart';
import '../widgets/library_cards.dart';
import '../widgets/library_filter_bar.dart';
import '../widgets/pista_list.dart';

enum _Sub { albumes, artistas, pistas }

/// Pestaña Biblioteca: sub-secciones Álbumes / Artistas / Pistas, cada una con su
/// propio buscador difuso y su orden persistido (independientes).
class BibliotecaScreen extends ConsumerStatefulWidget {
  const BibliotecaScreen({super.key});

  @override
  ConsumerState<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends ConsumerState<BibliotecaScreen> {
  _Sub _sub = _Sub.albumes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        TopBar(
          title: 'Tu biblioteca',
          onProfile: () => context.push('/profile'),
          avatarInicial: ref.watch(inicialPerfilProvider),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
          child: Row(
            children: <Widget>[
              ChipPill(
                label: 'Álbumes',
                active: _sub == _Sub.albumes,
                onTap: () => setState(() => _sub = _Sub.albumes),
              ),
              const SizedBox(width: 8),
              ChipPill(
                label: 'Artistas',
                active: _sub == _Sub.artistas,
                onTap: () => setState(() => _sub = _Sub.artistas),
              ),
              const SizedBox(width: 8),
              ChipPill(
                label: 'Pistas',
                active: _sub == _Sub.pistas,
                onTap: () => setState(() => _sub = _Sub.pistas),
              ),
            ],
          ),
        ),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    switch (_sub) {
      case _Sub.albumes:
        return const _AlbumesSeccion();
      case _Sub.artistas:
        return const _ArtistasSeccion();
      case _Sub.pistas:
        return const _PistasSeccion();
    }
  }
}

/// Mensaje cuando un buscador no devuelve nada.
class _SinResultados extends StatelessWidget {
  const _SinResultados();

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Center(
      child: Text(
        'Sin resultados',
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14,
          color: c.text3,
        ),
      ),
    );
  }
}

class _AlbumesSeccion extends ConsumerWidget {
  const _AlbumesSeccion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Album> albums = ref.watch(albumesFiltradosProvider);
    final OrdenAlbumes orden = ref.watch(ordenAlbumesProvider);
    return Column(
      children: <Widget>[
        LibraryFilterBar(
          hint: 'Buscar álbumes',
          ordenActivo: orden != OrdenAlbumes.tituloAsc,
          onChanged: (String v) =>
              ref.read(queryAlbumesProvider.notifier).set(v),
          onAbrirOrden: () => mostrarOrdenSheet<OrdenAlbumes>(
            context: context,
            titulo: 'Ordenar álbumes',
            opciones: OrdenAlbumes.values,
            actual: orden,
            etiqueta: (OrdenAlbumes o) => o.etiqueta,
            onSelect: (OrdenAlbumes o) =>
                ref.read(ordenAlbumesProvider.notifier).seleccionar(o),
            onLimpiar: () => ref.read(ordenAlbumesProvider.notifier).limpiar(),
          ),
        ),
        Expanded(
          child: albums.isEmpty
              ? const _SinResultados()
              : MaxWidth(
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount:
                          gridColumns(MediaQuery.sizeOf(context).width),
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: albums.length,
                    itemBuilder: (BuildContext context, int i) =>
                        AlbumCard(album: albums[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ArtistasSeccion extends ConsumerWidget {
  const _ArtistasSeccion();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Artista> artistas = ref.watch(artistasFiltradosProvider);
    final OrdenArtistas orden = ref.watch(ordenArtistasProvider);
    return Column(
      children: <Widget>[
        LibraryFilterBar(
          hint: 'Buscar artistas',
          ordenActivo: orden != OrdenArtistas.nombreAsc,
          onChanged: (String v) =>
              ref.read(queryArtistasProvider.notifier).set(v),
          onAbrirOrden: () => mostrarOrdenSheet<OrdenArtistas>(
            context: context,
            titulo: 'Ordenar artistas',
            opciones: OrdenArtistas.values,
            actual: orden,
            etiqueta: (OrdenArtistas o) => o.etiqueta,
            onSelect: (OrdenArtistas o) =>
                ref.read(ordenArtistasProvider.notifier).seleccionar(o),
            onLimpiar: () => ref.read(ordenArtistasProvider.notifier).limpiar(),
          ),
        ),
        Expanded(
          child: artistas.isEmpty
              ? const _SinResultados()
              : MaxWidth(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
                    itemCount: artistas.length,
                    itemBuilder: (BuildContext context, int i) =>
                        ArtistTile(artista: artistas[i]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _PistasSeccion extends ConsumerStatefulWidget {
  const _PistasSeccion();

  @override
  ConsumerState<_PistasSeccion> createState() => _PistasSeccionState();
}

class _PistasSeccionState extends ConsumerState<_PistasSeccion> {
  bool _seleccionando = false;
  final Set<int> _sel = <int>{};

  void _salir() => setState(() {
        _seleccionando = false;
        _sel.clear();
      });

  void _descargar() {
    final DownloadQueueController q = ref.read(downloadQueueProvider.notifier);
    final int n = _sel.length;
    for (final int id in _sel) {
      q.encolarPista(id);
    }
    _salir();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$n pista${n == 1 ? '' : 's'} en descarga.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final List<Pista> pistas = ref.watch(pistasFiltradasProvider);
    final OrdenPistas orden = ref.watch(ordenPistasProvider);
    // Solo se descarga lo que falta: las pistas ya completas no son seleccionables.
    final Set<int> completas = ref.watch(pistasCompletasProvider);
    final List<Pista> incompletas =
        <Pista>[for (final Pista p in pistas) if (!completas.contains(p.id)) p];
    final bool todasMarcadas = incompletas.isNotEmpty &&
        incompletas.every((Pista p) => _sel.contains(p.id));

    return Column(
      children: <Widget>[
        LibraryFilterBar(
          hint: 'Buscar pistas',
          ordenActivo: orden != OrdenPistas.tituloAsc,
          onChanged: (String v) =>
              ref.read(queryPistasProvider.notifier).set(v),
          onAbrirOrden: () => mostrarOrdenSheet<OrdenPistas>(
            context: context,
            titulo: 'Ordenar pistas',
            opciones: OrdenPistas.values,
            actual: orden,
            etiqueta: (OrdenPistas o) => o.etiqueta,
            onSelect: (OrdenPistas o) =>
                ref.read(ordenPistasProvider.notifier).seleccionar(o),
            onLimpiar: () => ref.read(ordenPistasProvider.notifier).limpiar(),
          ),
        ),
        // Barra de selección. "Seleccionar" solo se muestra si hay algo por
        // descargar (pistas incompletas): si toda la biblioteca ya está
        // descargada no aparece, y reaparece sola cuando algo queda incompleto
        // (se quitó una descarga o el PC sincronizó pistas nuevas) — la fuente
        // `pistasCompletasProvider` es reactiva.
        if (_seleccionando)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 2),
            child: Row(
              children: <Widget>[
                TextButton(
                  onPressed: incompletas.isEmpty
                      ? null
                      : () => setState(() {
                            if (todasMarcadas) {
                              _sel.clear();
                            } else {
                              _sel
                                ..clear()
                                ..addAll(incompletas.map((Pista p) => p.id));
                            }
                          }),
                  child: Text(
                    todasMarcadas ? 'Ninguna' : 'Todas',
                    style: TextStyle(color: c.accent),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_sel.length}',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: FontWeight.w700,
                    color: c.text2,
                  ),
                ),
                IconButton(
                  tooltip: 'Descargar seleccionadas',
                  onPressed: _sel.isEmpty ? null : _descargar,
                  icon: Icon(AppIcons.download, color: c.accent),
                ),
                IconButton(
                  tooltip: 'Cancelar',
                  onPressed: _salir,
                  icon: Icon(AppIcons.close, color: c.text2),
                ),
              ],
            ),
          )
        else if (incompletas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 6, 2),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _seleccionando = true),
                child: Text(
                  'Seleccionar',
                  style: TextStyle(color: c.text2),
                ),
              ),
            ),
          ),
        Expanded(
          child: pistas.isEmpty
              ? const _SinResultados()
              : MaxWidth(
                  child: _seleccionando
                      ? ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24),
                          itemCount: pistas.length,
                          itemBuilder: (BuildContext context, int i) {
                            final Pista p = pistas[i];
                            final bool ya = completas.contains(p.id);
                            return CheckboxListTile(
                              value: ya || _sel.contains(p.id),
                              onChanged: ya
                                  ? null
                                  : (bool? v) => setState(() {
                                        if (v ?? false) {
                                          _sel.add(p.id);
                                        } else {
                                          _sel.remove(p.id);
                                        }
                                      }),
                              activeColor: c.accent,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                p.titulo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontWeight: FontWeight.w600,
                                  color: c.text,
                                ),
                              ),
                              subtitle: Text(
                                ya
                                    ? '${p.artistaNombre} · descargada'
                                    : p.artistaNombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontSize: 12.5,
                                  color: ya ? c.accent : c.text3,
                                ),
                              ),
                            );
                          },
                        )
                      : PistaListView(
                          pistas: pistas,
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                        ),
                ),
        ),
      ],
    );
  }
}
