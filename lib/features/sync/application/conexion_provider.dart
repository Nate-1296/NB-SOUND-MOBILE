import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/secure_store.dart';
import 'sync_controller.dart';

/// Estado de conexión con el PC, de cara al usuario:
/// - [sinEnlace]: no hay emparejamiento (nunca se enlazó o se desvinculó).
/// - [desconectado]: hay emparejamiento, pero el PC no responde ahora mismo.
/// - [conectado]: hay emparejamiento y el PC respondió al sondeo.
enum ConexionEstado {
  sinEnlace,
  desconectado,
  conectado;

  /// Etiqueta corta para la UI (vista General, etc.).
  String get etiqueta => switch (this) {
        ConexionEstado.sinEnlace => 'Sin enlace',
        ConexionEstado.desconectado => 'Desconectado',
        ConexionEstado.conectado => 'Conectado',
      };

  bool get hayPc => this != ConexionEstado.sinEnlace;
}

/// Derivación pura del estado (testeable sin red): combina si hay emparejamiento
/// con si el PC es alcanzable.
ConexionEstado conexionEstadoDe({
  required bool emparejado,
  required bool alcanzable,
}) {
  if (!emparejado) {
    return ConexionEstado.sinEnlace;
  }
  return alcanzable ? ConexionEstado.conectado : ConexionEstado.desconectado;
}

/// Sondea si el PC emparejado responde (`/ping`). Se re-evalúa cuando cambia el
/// emparejamiento o el estado de sync (cada sync con éxito/fallo refresca el
/// resultado), así "Conectado/Desconectado" se mantiene al día sin temporizadores
/// propios. Durante el re-sondeo conserva el último valor conocido (sin parpadeo).
final FutureProvider<bool> pcAlcanzableProvider =
    FutureProvider<bool>((Ref ref) async {
  // Cualquier transición de sync (emparejar, syncing, lastSync, syncError)
  // dispara un re-sondeo fresco.
  final SyncState estado = ref.watch(syncControllerProvider);
  final PairedPc? pc = estado.pc;
  if (pc == null) {
    return false;
  }
  return ref.read(pairingRepositoryProvider).reachable(pc);
});

/// Estado de conexión observable para la UI (reproductor, General).
final Provider<ConexionEstado> conexionPcProvider =
    Provider<ConexionEstado>((Ref ref) {
  final PairedPc? pc =
      ref.watch(syncControllerProvider.select((SyncState s) => s.pc));
  final bool alcanzable = ref.watch(pcAlcanzableProvider).value ?? false;
  return conexionEstadoDe(emparejado: pc != null, alcanzable: alcanzable);
});
