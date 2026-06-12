import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/offline/application/download_gate.dart';
import 'package:nb_sound_mobile/features/sync/application/conexion_provider.dart';

void main() {
  group('gateDescarga', () {
    test('sin enlace ⇒ no encola (avisa que falta emparejar)', () {
      expect(gateDescarga(ConexionEstado.sinEnlace), DownloadGate.sinEnlace);
    });

    test('desconectado ⇒ encola avisando (bajará al reconectar)', () {
      expect(
        gateDescarga(ConexionEstado.desconectado),
        DownloadGate.encolarAvisando,
      );
    });

    test('conectado ⇒ encola sin fricción', () {
      expect(gateDescarga(ConexionEstado.conectado), DownloadGate.encolar);
    });

    test('cubre los tres estados de conexión', () {
      // Si se añade un estado nuevo a ConexionEstado, este test obliga a
      // decidir su comportamiento de descarga.
      for (final ConexionEstado e in ConexionEstado.values) {
        expect(gateDescarga(e), isA<DownloadGate>());
      }
    });
  });
}
