import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';

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
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onAbrirOrden;
  final bool ordenActivo;

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
        ],
      ),
    );
  }
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
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg2,
    showDragHandle: true,
    // Se presenta sobre el navegador raíz para que la hoja quede ENCIMA del
    // mini-reproductor y la barra inferior (si no, sus opciones de abajo quedan
    // tapadas por el mini-reproductor de la pestaña).
    useRootNavigator: true,
    builder: (BuildContext sheetContext) {
      return SafeArea(
        child: Column(
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
        ),
      );
    },
  );
}
