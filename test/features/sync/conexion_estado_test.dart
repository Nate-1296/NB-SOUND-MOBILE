import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/sync/application/conexion_provider.dart';

void main() {
  group('conexionEstadoDe', () {
    test('sin emparejamiento ⇒ sinEnlace (aunque "alcanzable" sea true)', () {
      expect(
        conexionEstadoDe(emparejado: false, alcanzable: false),
        ConexionEstado.sinEnlace,
      );
      expect(
        conexionEstadoDe(emparejado: false, alcanzable: true),
        ConexionEstado.sinEnlace,
      );
    });

    test('emparejado pero no alcanzable ⇒ desconectado', () {
      expect(
        conexionEstadoDe(emparejado: true, alcanzable: false),
        ConexionEstado.desconectado,
      );
    });

    test('emparejado y alcanzable ⇒ conectado', () {
      expect(
        conexionEstadoDe(emparejado: true, alcanzable: true),
        ConexionEstado.conectado,
      );
    });

    test('etiquetas legibles', () {
      expect(ConexionEstado.sinEnlace.etiqueta, 'Sin enlace');
      expect(ConexionEstado.desconectado.etiqueta, 'Desconectado');
      expect(ConexionEstado.conectado.etiqueta, 'Conectado');
    });

    test('hayPc distingue enlace de su ausencia', () {
      expect(ConexionEstado.sinEnlace.hayPc, isFalse);
      expect(ConexionEstado.desconectado.hayPc, isTrue);
      expect(ConexionEstado.conectado.hayPc, isTrue);
    });
  });
}
