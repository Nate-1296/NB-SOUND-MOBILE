import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../application/library_providers.dart';

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
