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
import '../../application/library_providers.dart';
import '../widgets/library_cards.dart';
import '../widgets/pista_list.dart';

enum _Sub { albumes, artistas, pistas }

/// Pestaña Biblioteca: sub-secciones Álbumes / Artistas / Pistas.
class BibliotecaScreen extends ConsumerStatefulWidget {
  const BibliotecaScreen({super.key});

  @override
  ConsumerState<BibliotecaScreen> createState() => _BibliotecaScreenState();
}

class _BibliotecaScreenState extends ConsumerState<BibliotecaScreen> {
  _Sub _sub = _Sub.albumes;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Column(
      children: <Widget>[
        TopBar(
          title: 'Tu biblioteca',
          onProfile: () => context.push('/profile'),
          trailing: IconButton(
            onPressed: () => context.go('/buscar'),
            icon: Icon(AppIcons.search, size: 22, color: c.text2),
          ),
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
        return _AlbumesGrid();
      case _Sub.artistas:
        return _ArtistasList();
      case _Sub.pistas:
        return const _PistasList();
    }
  }
}

class _AlbumesGrid extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Album> albums =
        ref.watch(albumsProvider).value ?? const <Album>[];
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridColumns(MediaQuery.sizeOf(context).width),
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: albums.length,
      itemBuilder: (BuildContext context, int i) =>
          AlbumCard(album: albums[i]),
    );
  }
}

class _ArtistasList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Artista> artistas =
        ref.watch(artistasProvider).value ?? const <Artista>[];
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      itemCount: artistas.length,
      itemBuilder: (BuildContext context, int i) =>
          ArtistTile(artista: artistas[i]),
    );
  }
}

class _PistasList extends ConsumerStatefulWidget {
  const _PistasList();

  @override
  ConsumerState<_PistasList> createState() => _PistasListState();
}

class _PistasListState extends ConsumerState<_PistasList> {
  bool _seleccionando = false;
  final Set<int> _sel = <int>{};

  void _salir() => setState(() {
        _seleccionando = false;
        _sel.clear();
      });

  void _descargar() {
    final DownloadQueueController q =
        ref.read(downloadQueueProvider.notifier);
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
    final List<Pista> pistas =
        ref.watch(pistasProvider).value ?? const <Pista>[];
    final Set<int> descargadas =
        ref.watch(descargadasProvider).value ?? const <int>{};

    return Column(
      children: <Widget>[
        // Barra: entrar a selección o acciones de la selección activa.
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 6, 2),
          child: _seleccionando
              ? Row(
                  children: <Widget>[
                    TextButton(
                      onPressed: () => setState(() {
                        if (_sel.length == pistas.length) {
                          _sel.clear();
                        } else {
                          _sel
                            ..clear()
                            ..addAll(pistas.map((Pista p) => p.id));
                        }
                      }),
                      child: Text(
                        _sel.length == pistas.length
                            ? 'Ninguna'
                            : 'Todas',
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
                )
              : Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: pistas.isEmpty
                        ? null
                        : () => setState(() => _seleccionando = true),
                    child: Text(
                      'Seleccionar',
                      style: TextStyle(color: c.text2),
                    ),
                  ),
                ),
        ),
        Expanded(
          child: _seleccionando
              ? ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: pistas.length,
                  itemBuilder: (BuildContext context, int i) {
                    final Pista p = pistas[i];
                    final bool ya = descargadas.contains(p.id);
                    return CheckboxListTile(
                      value: _sel.contains(p.id),
                      onChanged: (bool? v) => setState(() {
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
                        ya ? '${p.artistaNombre} · descargada' : p.artistaNombre,
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
                  child: PistaList(pistas: pistas, comoColeccion: false),
                ),
        ),
      ],
    );
  }
}
