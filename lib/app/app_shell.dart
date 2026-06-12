import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/theme/nb_colors.dart';
import '../shared/widgets/bottom_nav.dart';
import '../shared/widgets/mini_player_bar.dart';

/// Qué hacer ante el botón **atrás del sistema** estando en la raíz de una
/// pestaña (sin pantallas apiladas encima). Inicio es la base de todo: desde
/// cualquier otra pestaña, atrás vuelve a Inicio; en Inicio, atrás pide
/// confirmación (un segundo atrás dentro de la ventana sale de la app). Pura y
/// testeable.
enum BackAction { irInicio, confirmarSalida, salir }

BackAction decidirAtras({
  required int indiceActual,
  required bool dentroVentana,
}) {
  if (indiceActual != 0) {
    return BackAction.irInicio;
  }
  return dentroVentana ? BackAction.salir : BackAction.confirmarSalida;
}

/// Shell raíz con barra de navegación inferior persistente y mini-reproductor
/// flotante (refleja el destino activo: este teléfono o el PC).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Shell de navegación con estado de go_router (una rama por pestaña).
  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Ventana para el "doble atrás para salir".
  static const Duration _ventanaSalida = Duration(seconds: 2);

  /// Marca del último atrás en Inicio (para detectar el segundo a tiempo).
  DateTime? _ultimoAtras;

  void _onTap(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  /// Maneja el atrás del sistema cuando la shell es la ruta visible (estamos en
  /// la raíz de una pestaña; las pantallas apiladas — detalle, reproductor,
  /// Buscar con búsqueda activa — lo gestionan antes en su propio navegador).
  void _onPop(bool didPop) {
    if (didPop) {
      return;
    }
    final DateTime ahora = DateTime.now();
    final bool dentroVentana = _ultimoAtras != null &&
        ahora.difference(_ultimoAtras!) <= _ventanaSalida;
    switch (decidirAtras(
      indiceActual: widget.navigationShell.currentIndex,
      dentroVentana: dentroVentana,
    )) {
      case BackAction.irInicio:
        // Cualquier atrás desde otra pestaña lleva a Inicio (la base de todo).
        _ultimoAtras = null;
        widget.navigationShell.goBranch(0);
      case BackAction.confirmarSalida:
        _ultimoAtras = ahora;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              duration: _ventanaSalida,
              content: Text('Pulsa atrás de nuevo para salir'),
            ),
          );
      case BackAction.salir:
        // Sale de la app (atrás del sistema en Inicio dentro de la ventana).
        SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;

    return PopScope<Object?>(
      // La shell nunca se "popea" sola: el atrás lo decide [_onPop] (volver a
      // Inicio o doble atrás para salir).
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) => _onPop(didPop),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(bottom: false, child: widget.navigationShell),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const MiniPlayerBar(),
            BottomNav(
              currentIndex: widget.navigationShell.currentIndex,
              onTap: _onTap,
            ),
          ],
        ),
      ),
    );
  }
}
