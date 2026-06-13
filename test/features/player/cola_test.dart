import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/player/application/playback.dart';
import 'package:nb_sound_mobile/features/player/application/player_controller.dart';

Pista _p(int id) => Pista(
      id: id,
      titulo: 'T$id',
      artistaNombre: 'A$id',
      duracionSeg: 100,
      syncVersion: 0,
      origen: id < 0 ? 'local' : 'pc',
    );

void main() {
  group('planSetQueueRemota (cola espejada hacia el PC)', () {
    test('manda toda la colección y reubica el índice tocado', () {
      final ({List<int> ids, int indice}) plan =
          planSetQueueRemota(<Pista>[_p(10), _p(20), _p(30), _p(40)], 1);
      expect(plan.ids, <int>[10, 20, 30, 40]);
      expect(plan.indice, 1);
    });

    test('filtra la música local (id < 0) y reubica el índice', () {
      // [local(-1), 20, local(-2), 40], se toca el índice 3 (id 40).
      final ({List<int> ids, int indice}) plan =
          planSetQueueRemota(<Pista>[_p(-1), _p(20), _p(-2), _p(40)], 3);
      expect(plan.ids, <int>[20, 40]); // sin locales
      expect(plan.indice, 1); // 40 quedó en la posición 1 de la lista filtrada
    });

    test('si la pista tocada es local, no se hace nada (ids vacío)', () {
      final ({List<int> ids, int indice}) plan =
          planSetQueueRemota(<Pista>[_p(-1), _p(20)], 0);
      expect(plan.ids, isEmpty);
    });

    test('lista vacía o índice fuera de rango ⇒ ids vacío', () {
      expect(planSetQueueRemota(<Pista>[], 0).ids, isEmpty);
      expect(planSetQueueRemota(<Pista>[_p(10)], 5).ids, isEmpty);
      expect(planSetQueueRemota(<Pista>[_p(10)], -1).ids, isEmpty);
    });
  });

  group('planHandoffRemoto (pasar el control al PC con cola completa)', () {
    test('espeja la cola entera y reubica el índice, conservando posición', () {
      final HandoffRemoto plan = planHandoffRemoto(
        <Pista>[_p(10), _p(20), _p(30), _p(40)],
        2,
        37.5,
      );
      expect(plan.hayCola, isTrue);
      expect(plan.ids, <int>[10, 20, 30, 40]);
      expect(plan.indice, 2);
      expect(plan.posicionSeg, 37.5);
    });

    test('filtra la música local (id < 0) y cuenta solo las no locales', () {
      // [local(-1), 20, local(-2), 40, 50] sonando el índice 3 (id 40).
      final HandoffRemoto plan = planHandoffRemoto(
        <Pista>[_p(-1), _p(20), _p(-2), _p(40), _p(50)],
        3,
        5,
      );
      expect(plan.ids, <int>[20, 40, 50]);
      expect(plan.indice, 1); // 40 es la 2ª no local
    });

    test('si la pista en curso es local, no hay cola que espejar', () {
      final HandoffRemoto plan =
          planHandoffRemoto(<Pista>[_p(-1), _p(20)], 0, 3);
      expect(plan.hayCola, isFalse);
    });

    test('cola vacía o índice fuera de rango ⇒ sin cola', () {
      expect(planHandoffRemoto(<Pista>[], 0, 0).hayCola, isFalse);
      expect(planHandoffRemoto(<Pista>[_p(10)], 5, 0).hayCola, isFalse);
      expect(planHandoffRemoto(<Pista>[_p(10)], -1, 0).hayCola, isFalse);
    });

    test('posición negativa se normaliza a 0', () {
      expect(planHandoffRemoto(<Pista>[_p(10)], 0, -4).posicionSeg, 0);
    });
  });

  group('mapearColaRemota (traer la cola del PC al teléfono)', () {
    Map<int, Pista> porId(List<int> ids) =>
        <int, Pista>{for (final int id in ids) id: _p(id)};

    test('todas las ids existen: pistas en orden, mismo índice', () {
      final ({List<Pista> pistas, int index}) m = mapearColaRemota(
        <int>[10, 20, 30],
        1,
        porId(<int>[10, 20, 30]),
      );
      expect(m.pistas.map((Pista p) => p.id), <int>[10, 20, 30]);
      expect(m.index, 1);
    });

    test('omite las ids inexistentes y reubica el índice en curso', () {
      // El PC manda [10, 20, 30, 40]; 20 no está en la biblioteca. Suena 30 (i=2).
      final ({List<Pista> pistas, int index}) m = mapearColaRemota(
        <int>[10, 20, 30, 40],
        2,
        porId(<int>[10, 30, 40]),
      );
      expect(m.pistas.map((Pista p) => p.id), <int>[10, 30, 40]);
      expect(m.index, 1); // 30 quedó en la posición 1 de la lista filtrada
    });

    test('si la pista en curso falta, apunta a la siguiente disponible', () {
      // Suena 20 (i=1) pero 20 no existe; debe caer en 30 (la siguiente).
      final ({List<Pista> pistas, int index}) m = mapearColaRemota(
        <int>[10, 20, 30],
        1,
        porId(<int>[10, 30]),
      );
      expect(m.pistas.map((Pista p) => p.id), <int>[10, 30]);
      expect(m.index, 1); // posición donde habría caído 20 → ahora 30
    });

    test('ninguna id existe ⇒ pistas vacío', () {
      final ({List<Pista> pistas, int index}) m =
          mapearColaRemota(<int>[10, 20], 0, const <int, Pista>{});
      expect(m.pistas, isEmpty);
      expect(m.index, 0);
    });

    test('índice fuera de rango se acota a la última', () {
      final ({List<Pista> pistas, int index}) m = mapearColaRemota(
        <int>[10, 20],
        9,
        porId(<int>[10, 20]),
      );
      expect(m.index, 1);
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
