import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/theme/nb_colors.dart';
import '../../../../shared/theme/nb_theme.dart';
import '../../../../shared/widgets/app_icons.dart';
import '../../../../shared/widgets/placeholder_body.dart';
import '../../../../shared/widgets/top_bar.dart';
import '../../application/library_providers.dart';
import '../widgets/pista_list.dart';

/// Pestaña Buscar: búsqueda local sobre pistas por título o artista.
class BuscarScreen extends ConsumerStatefulWidget {
  const BuscarScreen({super.key});

  @override
  ConsumerState<BuscarScreen> createState() => _BuscarScreenState();
}

class _BuscarScreenState extends ConsumerState<BuscarScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final String query = ref.watch(busquedaQueryProvider);
    final List<Pista> resultados =
        ref.watch(resultadosBusquedaProvider).value ?? const <Pista>[];

    // Pestaña raíz: atrás cerraría la app. Si hay búsqueda activa, se intercepta
    // para limpiarla (y cerrar el teclado) en lugar de salir.
    return PopScope<Object?>(
      canPop: query.isEmpty,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _controller.clear();
        ref.read(busquedaQueryProvider.notifier).set('');
        FocusScope.of(context).unfocus();
      },
      child: Column(
        children: <Widget>[
          TopBar(title: 'Buscar', onProfile: () => context.push('/profile')),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: TextField(
              controller: _controller,
              onChanged: (String v) =>
                  ref.read(busquedaQueryProvider.notifier).set(v),
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 15,
                color: c.text,
              ),
              decoration: InputDecoration(
                hintText: 'Pistas y artistas',
                hintStyle: TextStyle(color: c.text3, fontFamily: NbFonts.ui),
                prefixIcon: Icon(AppIcons.search, color: c.text3, size: 20),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        icon: Icon(AppIcons.close, color: c.text3, size: 18),
                        onPressed: () {
                          _controller.clear();
                          ref.read(busquedaQueryProvider.notifier).set('');
                        },
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
          Expanded(child: _body(query, resultados)),
        ],
      ),
    );
  }

  Widget _body(String query, List<Pista> resultados) {
    if (query.trim().isEmpty) {
      return const PlaceholderBody(
        icon: AppIcons.search,
        title: 'Busca en tu biblioteca',
        subtitle: 'Escribe el nombre de una pista o un artista.',
      );
    }
    if (resultados.isEmpty) {
      return const PlaceholderBody(
        icon: AppIcons.search,
        title: 'Sin resultados',
        subtitle: 'Prueba con otro término.',
      );
    }
    return PistaListView(
      pistas: resultados,
      comoColeccion: false,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
    );
  }
}
