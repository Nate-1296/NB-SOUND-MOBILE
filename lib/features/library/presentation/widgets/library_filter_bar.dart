import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/sheet.dart';
import '../../application/library_filters.dart';

/// Barra de filtro de una sección de biblioteca/playlists: buscador (con debounce
/// propio) + botón de orden. Reutilizable e independiente por sección. El botón de
/// orden se resalta cuando hay un orden distinto del por defecto.
class LibraryFilterBar extends StatefulWidget {
  const LibraryFilterBar({
    super.key,
    required this.hint,
    required this.onChanged,
    required this.onAbrirOrden,
    this.ordenActivo = false,
    this.vistaIcono,
    this.onAbrirVista,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onAbrirOrden;
  final bool ordenActivo;

  /// Icono del modo de visualización actual (lista/cuadrícula). Si se da junto a
  /// [onAbrirVista], se muestra un botón para cambiar el aspecto de la sección.
  final IconData? vistaIcono;
  final VoidCallback? onAbrirVista;

  @override
  State<LibraryFilterBar> createState() => _LibraryFilterBarState();
}

class _LibraryFilterBarState extends State<LibraryFilterBar> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  bool _hayTexto = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    if ((v.isNotEmpty) != _hayTexto) {
      setState(() => _hayTexto = v.isNotEmpty);
    }
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 90),
      () => widget.onChanged(v),
    );
  }

  void _limpiar() {
    _debounce?.cancel();
    _ctrl.clear();
    setState(() => _hayTexto = false);
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 14, 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 14.5,
                color: c.text,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hint,
                hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
                prefixIcon: Icon(AppIcons.search, color: c.text3, size: 19),
                suffixIcon: _hayTexto
                    ? IconButton(
                        icon: Icon(AppIcons.close, color: c.text3, size: 17),
                        onPressed: _limpiar,
                      )
                    : null,
                filled: true,
                fillColor: c.bg2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(13),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 2),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Ordenar',
            onPressed: widget.onAbrirOrden,
            style: IconButton.styleFrom(
              backgroundColor: widget.ordenActivo ? c.soft : c.bg2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
                side: BorderSide(
                  color: widget.ordenActivo ? c.accent : c.line2,
                ),
              ),
            ),
            icon: Icon(
              AppIcons.sliders,
              size: 20,
              color: widget.ordenActivo ? c.accent : c.text2,
            ),
          ),
          if (widget.vistaIcono != null && widget.onAbrirVista != null) ...<Widget>[
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Modo de visualización',
              onPressed: widget.onAbrirVista,
              style: IconButton.styleFrom(
                backgroundColor: c.bg2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                  side: BorderSide(color: c.line2),
                ),
              ),
              icon: Icon(widget.vistaIcono, size: 20, color: c.text2),
            ),
          ],
        ],
      ),
    );
  }
}

/// Icono representativo de un modo de visualización (para el botón de la barra).
IconData iconoVista(LibraryViewMode m) => switch (m) {
      LibraryViewMode.lista => AppIcons.viewList,
      LibraryViewMode.gridPequena => AppIcons.viewGridSmall,
      LibraryViewMode.gridMediana => AppIcons.viewGrid,
    };

/// Hoja para elegir el modo de visualización de una sección. Marca el activo.
Future<void> mostrarVistaSheet({
  required BuildContext context,
  required LibraryViewMode actual,
  required ValueChanged<LibraryViewMode> onSelect,
}) {
  return mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      final NbColors c = sheetContext.nb;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Cómo se ve',
                style: TextStyle(
                  fontFamily: NbFonts.display,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ),
          ),
          for (final LibraryViewMode m in LibraryViewMode.values)
            ListTile(
              dense: true,
              onTap: () {
                onSelect(m);
                Navigator.of(sheetContext).pop();
              },
              leading: Icon(
                iconoVista(m),
                color: m == actual ? c.accent : c.text3,
              ),
              title: Text(
                m.etiqueta,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: m == actual ? FontWeight.w700 : FontWeight.w600,
                  color: m == actual ? c.accent : c.text,
                ),
              ),
              trailing: m == actual
                  ? Icon(AppIcons.check, color: c.accent, size: 20)
                  : null,
            ),
          const SizedBox(height: 8),
        ],
      );
    },
  );
}

/// Hoja de selección de orden con la opción activa marcada y "Limpiar filtros"
/// (vuelve al orden por defecto). Genérica sobre el tipo de criterio [T].
Future<void> mostrarOrdenSheet<T>({
  required BuildContext context,
  required String titulo,
  required List<T> opciones,
  required T actual,
  required String Function(T) etiqueta,
  required ValueChanged<T> onSelect,
  required VoidCallback onLimpiar,
}) {
  final NbColors c = context.nb;
  return mostrarHojaMenu<void>(
    context,
    builder: (BuildContext sheetContext) {
      return Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: NbFonts.display,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
            ),
            for (final T o in opciones)
              ListTile(
                dense: true,
                onTap: () {
                  onSelect(o);
                  Navigator.of(sheetContext).pop();
                },
                leading: Icon(
                  o == actual ? AppIcons.check : AppIcons.list,
                  color: o == actual ? c.accent : c.text3,
                ),
                title: Text(
                  etiqueta(o),
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontWeight: o == actual ? FontWeight.w700 : FontWeight.w600,
                    color: o == actual ? c.accent : c.text,
                  ),
                ),
              ),
            const Divider(height: 8),
            ListTile(
              onTap: () {
                onLimpiar();
                Navigator.of(sheetContext).pop();
              },
              leading: Icon(AppIcons.refresh, color: c.text2),
              title: Text(
                'Limpiar filtros',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontWeight: FontWeight.w600,
                  color: c.text2,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
    },
  );
}
