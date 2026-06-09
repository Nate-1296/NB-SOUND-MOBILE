import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../core/search/fuzzy.dart';
import '../../../../data/db/daos/local_playlists_dao.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../offline/application/image_resolver.dart';
import '../../application/library_providers.dart';
import '../../application/search_providers.dart';

/// Diálogo para crear/renombrar una playlist local. Devuelve el nombre, o null
/// si se cancela. [inicial] precarga el campo (renombrar).
Future<String?> pedirNombrePlaylist(
  BuildContext context, {
  String titulo = 'Nueva playlist',
  String inicial = '',
}) {
  final TextEditingController ctrl = TextEditingController(text: inicial);
  final NbColors c = context.nb;
  return showDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: c.bg2,
        title: Text(
          titulo,
          style: TextStyle(
            fontFamily: NbFonts.display,
            fontWeight: FontWeight.w800,
            color: c.text,
          ),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: TextStyle(color: c.text, fontFamily: NbFonts.ui),
          decoration: InputDecoration(
            hintText: 'Nombre',
            hintStyle: TextStyle(color: c.text3),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.line2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.accent),
            ),
          ),
          onSubmitted: (String v) =>
              Navigator.of(dialogContext).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.text2)),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.ink,
            ),
            child: const Text('Guardar'),
          ),
        ],
      );
    },
  );
}

/// Crea una playlist local preguntando el nombre. Devuelve su id, o null.
Future<int?> crearPlaylistLocal(BuildContext context, WidgetRef ref) async {
  final String? nombre = await pedirNombrePlaylist(context);
  if (nombre == null || nombre.isEmpty) {
    return null;
  }
  return ref.read(localPlaylistsDaoProvider).crear(nombre);
}

/// Hoja inferior para **añadir canciones** a la playlist local [playlistId]:
/// buscador difuso + recomendaciones iniciales; cada fila tiene `+` (añadir) o
/// `✓` (ya está → quitar).
Future<void> agregarPistasAPlaylist(
  BuildContext context,
  WidgetRef ref,
  int playlistId,
) {
  final NbColors c = context.nb;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg2,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        _AgregarPistasSheet(playlistId: playlistId),
  );
}

class _AgregarPistasSheet extends ConsumerStatefulWidget {
  const _AgregarPistasSheet({required this.playlistId});
  final int playlistId;

  @override
  ConsumerState<_AgregarPistasSheet> createState() =>
      _AgregarPistasSheetState();
}

class _AgregarPistasSheetState extends ConsumerState<_AgregarPistasSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 90), () {
      if (mounted) {
        setState(() => _q = v);
      }
    });
  }

  /// Recomendaciones iniciales (sin búsqueda): lo que el usuario probablemente
  /// quiera añadir — recientes + favoritas + más escuchadas, sin repetir, y se
  /// completa con el catálogo. Tope para no saturar.
  List<Pista> _recomendaciones() {
    final List<Pista> out = <Pista>[];
    final Set<int> vistos = <int>{};
    void agregar(List<Pista> src) {
      for (final Pista p in src) {
        if (vistos.add(p.id)) {
          out.add(p);
        }
      }
    }

    agregar(ref.watch(recientesProvider).value ?? const <Pista>[]);
    agregar(ref.watch(favoritasProvider).value ?? const <Pista>[]);
    agregar(ref.watch(masEscuchadasProvider).value ?? const <Pista>[]);
    agregar(ref.watch(pistasProvider).value ?? const <Pista>[]);
    return out.length > 60 ? out.sublist(0, 60) : out;
  }

  List<Pista> _resultados() {
    final String q = normalizar(_q);
    if (q.isEmpty) {
      return _recomendaciones();
    }
    final List<PistaBusq> index = ref.watch(pistaIndexProvider);
    final List<({double s, Pista p})> scored = <({double s, Pista p})>[];
    for (final PistaBusq item in index) {
      final double s = item.puntuar(q);
      if (s >= 0.35) {
        scored.add((s: s, p: item.pista));
      }
    }
    scored.sort((({double s, Pista p}) a, ({double s, Pista p}) b) =>
        b.s.compareTo(a.s));
    return <Pista>[
      for (final ({double s, Pista p}) e in scored.take(60)) e.p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Set<int> miembros =
        (ref.watch(pistasDePlaylistLocalProvider(widget.playlistId)).value ??
                const <Pista>[])
            .map((Pista p) => p.id)
            .toSet();
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final List<Pista> pistas = _resultados();
    final double h = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: h * 0.82,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Añadir canciones',
                  style: TextStyle(
                    fontFamily: NbFonts.display,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                autofocus: false,
                style: TextStyle(fontFamily: NbFonts.ui, color: c.text),
                decoration: InputDecoration(
                  hintText: 'Buscar canciones',
                  hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
                  prefixIcon: Icon(AppIcons.search, color: c.text3, size: 20),
                  suffixIcon: _q.isEmpty
                      ? null
                      : IconButton(
                          icon: Icon(AppIcons.close, color: c.text3, size: 18),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _q = '');
                          },
                        ),
                  filled: true,
                  fillColor: c.bg3,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
            Expanded(
              child: pistas.isEmpty
                  ? Center(
                      child: Text(
                        'Sin resultados',
                        style: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      itemCount: pistas.length,
                      itemBuilder: (BuildContext context, int i) {
                        final Pista p = pistas[i];
                        final bool dentro = miembros.contains(p.id);
                        return ListTile(
                          leading: Cover(
                            image: resolver.imageFor(
                              p.coverPath,
                              cacheWidth: coverCachePx(context, 44),
                            ),
                            size: 44,
                            radius: 8,
                            shadow: false,
                          ),
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
                            p.artistaNombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              fontSize: 12.5,
                              color: c.text3,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: dentro ? 'Quitar' : 'Añadir',
                            onPressed: () {
                              final LocalPlaylistsDao dao =
                                  ref.read(localPlaylistsDaoProvider);
                              if (dentro) {
                                dao.quitarPista(widget.playlistId, p.id);
                              } else {
                                dao.anadirPista(widget.playlistId, p.id);
                              }
                            },
                            icon: Icon(
                              dentro ? AppIcons.check : AppIcons.plus,
                              color: dentro ? c.accent : c.text2,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja inferior para añadir [pistaId] a una playlist local (o crear una nueva).
Future<void> anadirAPlaylist(
  BuildContext context,
  WidgetRef ref,
  int pistaId,
) {
  final NbColors c = context.nb;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg2,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Consumer(
          builder: (BuildContext context, WidgetRef ref, Widget? _) {
            final List<PlaylistLocal> locales =
                ref.watch(playlistsLocalesProvider).value ??
                    const <PlaylistLocal>[];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Añadir a playlist',
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
                  leading: Icon(AppIcons.plus, color: c.accent),
                  title: Text(
                    'Nueva playlist',
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                  onTap: () async {
                    final int? id = await crearPlaylistLocal(sheetContext, ref);
                    if (id != null) {
                      await ref
                          .read(localPlaylistsDaoProvider)
                          .anadirPista(id, pistaId);
                    }
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: <Widget>[
                      for (final PlaylistLocal pl in locales)
                        ListTile(
                          leading: Icon(AppIcons.note, color: c.text2),
                          title: Text(
                            pl.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NbFonts.ui,
                              fontWeight: FontWeight.w600,
                              color: c.text,
                            ),
                          ),
                          onTap: () async {
                            await ref
                                .read(localPlaylistsDaoProvider)
                                .anadirPista(pl.id, pistaId);
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
