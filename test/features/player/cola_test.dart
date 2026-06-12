import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/player/application/playback.dart';
import 'package:nb_sound_mobile/features/player/application/player_controller.dart';

void main() {
  group('planColeccionRemota (reproducir colección en el PC)', () {
    test('reproduce la pista del índice y encola solo el resto', () {
      final ({int play, List<int> next}) plan =
          planColeccionRemota(<int>[10, 20, 30, 40], 1);
      expect(plan.play, 20);
      expect(plan.next, <int>[30, 40]);
    });

    test('desde el principio encola toda la cola siguiente', () {
      final ({int play, List<int> next}) plan =
          planColeccionRemota(<int>[10, 20, 30], 0);
      expect(plan.play, 10);
      expect(plan.next, <int>[20, 30]);
    });

    test('última pista: nada que encolar', () {
      final ({int play, List<int> next}) plan =
          planColeccionRemota(<int>[10, 20, 30], 2);
      expect(plan.play, 30);
      expect(plan.next, <int>[]);
    });

    test('índice fuera de rango se acota', () {
      expect(planColeccionRemota(<int>[10, 20], -5).play, 10);
      expect(planColeccionRemota(<int>[10, 20], 9).play, 20);
    });
  });

  group('planTraspasoLocal (tomar el control en el teléfono, Connect)', () {
    test('PC conectado y sonando: pausa el PC y traspasa reproduciendo', () {
      final TraspasoLocal p = planTraspasoLocal(
        conectado: true,
        pistaId: 42,
        posicionSeg: 12.5,
        reproduciendo: true,
      );
      expect(p.pausarPc, isTrue);
      expect(p.hayTraspaso, isTrue);
      expect(p.pistaId, 42);
      expect(p.posicionSeg, 12.5);
      expect(p.reproducir, isTrue);
    });

    test('PC conectado y en pausa: no pausa de nuevo, traspasa en pausa', () {
      final TraspasoLocal p = planTraspasoLocal(
        conectado: true,
        pistaId: 7,
        posicionSeg: 3,
        reproduciendo: false,
      );
      expect(p.pausarPc, isFalse);
      expect(p.hayTraspaso, isTrue);
      expect(p.reproducir, isFalse);
    });

    test('sin pista válida en el PC: no hay traspaso', () {
      expect(
        planTraspasoLocal(
          conectado: true,
          pistaId: null,
          posicionSeg: 0,
          reproduciendo: true,
        ).hayTraspaso,
        isFalse,
      );
      expect(
        planTraspasoLocal(
          conectado: true,
          pistaId: 0,
          posicionSeg: 0,
          reproduciendo: true,
        ).hayTraspaso,
        isFalse,
      );
    });

    test('PC no conectado: nunca se intenta pausar el PC', () {
      final TraspasoLocal p = planTraspasoLocal(
        conectado: false,
        pistaId: 9,
        posicionSeg: 0,
        reproduciendo: true,
      );
      expect(p.pausarPc, isFalse);
    });
  });

  group('indiceTrasMover (reordenar la cola)', () {
    test('mover la pista en curso la sigue', () {
      expect(indiceTrasMover(0, 0, 3), 3);
    });

    test('mover un elemento anterior a una posición posterior', () {
      // [a,b,c,d] sonando c(2); mover a(0) al final → [b,c,d,a]: c queda en 1.
      expect(indiceTrasMover(2, 0, 3), 1);
    });

    test('mover un elemento posterior delante de la actual', () {
      // [a,b,c,d] sonando b(1); mover d(3) al inicio → [d,a,b,c]: b queda en 2.
      expect(indiceTrasMover(1, 3, 0), 2);
    });

    test('mover entre dos posiciones que no rodean a la actual no la afecta', () {
      // sonando a(0); mover c(2) a d-pos(3) no toca a.
      expect(indiceTrasMover(0, 2, 3), 0);
    });
  });

  group('indiceTrasQuitar (quitar de la cola)', () {
    test('quitar antes de la actual la desplaza una atrás', () {
      expect(indiceTrasQuitar(2, 0), 1);
    });

    test('quitar después de la actual no la afecta', () {
      expect(indiceTrasQuitar(2, 3), 2);
    });
  });
}
