import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/app/app_shell.dart';

void main() {
  group('decidirAtras (botón atrás del sistema en la raíz de una pestaña)', () {
    test('desde otra pestaña: vuelve a Inicio', () {
      expect(
        decidirAtras(indiceActual: 1, dentroVentana: false),
        BackAction.irInicio,
      );
      expect(
        decidirAtras(indiceActual: 3, dentroVentana: true),
        BackAction.irInicio,
      );
    });

    test('en Inicio, primer atrás: pide confirmación', () {
      expect(
        decidirAtras(indiceActual: 0, dentroVentana: false),
        BackAction.confirmarSalida,
      );
    });

    test('en Inicio, segundo atrás a tiempo: sale', () {
      expect(
        decidirAtras(indiceActual: 0, dentroVentana: true),
        BackAction.salir,
      );
    });

    test('Inicio (índice 0) es la base: nunca sale desde otra pestaña', () {
      for (int i = 1; i < 4; i++) {
        expect(
          decidirAtras(indiceActual: i, dentroVentana: true),
          BackAction.irInicio,
          reason: 'pestaña $i debe ir a Inicio, no salir',
        );
      }
    });
  });
}
