import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/offline/application/download_providers.dart';

/// Lógica pura del contador de Descargas (cuántas van, cuántas faltan, progreso
/// del lote y ETA). No toca DB ni red: solo el estado derivado.
void main() {
  group('DownloadQueueState · contador', () {
    test('inactivo: sin pendientes, sin progreso ni ETA', () {
      const DownloadQueueState s = DownloadQueueState();
      expect(s.activo, isFalse);
      expect(s.restantes, 0);
      expect(s.totalLote, 0);
      expect(s.progresoLote, isNull);
      expect(s.eta, isNull);
    });

    test('lote recién iniciado: total = pendientes, 0 completadas', () {
      const DownloadQueueState s = DownloadQueueState(pendientes: <int>[1, 2, 3]);
      expect(s.restantes, 3);
      expect(s.totalLote, 3);
      expect(s.progresoLote, 0.0);
      expect(s.eta, isNull, reason: 'sin muestra de tiempo todavía');
    });

    test('a mitad de lote: cuenta correcta y progreso parcial', () {
      const DownloadQueueState s = DownloadQueueState(
        pendientes: <int>[2, 3],
        actual: 2,
        completados: 1,
        tiempoCompletadosMs: 10000,
      );
      expect(s.activo, isTrue);
      expect(s.restantes, 2);
      expect(s.totalLote, 3); // 1 completada + 2 que faltan
      expect(s.progresoLote, closeTo(1 / 3, 1e-9));
    });

    test('progreso por bytes de la pista en curso es independiente del lote', () {
      const DownloadQueueState s = DownloadQueueState(
        pendientes: <int>[2],
        actual: 2,
        recibidos: 50,
        total: 100,
      );
      expect(s.progreso, closeTo(0.5, 1e-9));
    });

    test('ETA promedia el tiempo por pista y descuenta el ya invertido', () {
      // 1 pista completada en 10 s; faltan 2 (incluida la en curso) => ~20 s
      // menos lo transcurrido en la actual.
      final DownloadQueueState recienEmpezada = DownloadQueueState(
        pendientes: const <int>[2, 3],
        actual: 2,
        completados: 1,
        tiempoCompletadosMs: 10000,
        inicioActual: DateTime.now(),
      );
      final Duration? eta1 = recienEmpezada.eta;
      expect(eta1, isNotNull);
      expect(eta1!.inSeconds, inInclusiveRange(18, 20));

      // Misma situación pero ya llevamos ~5 s en la pista actual => ETA menor.
      final DownloadQueueState avanzada = DownloadQueueState(
        pendientes: const <int>[2, 3],
        actual: 2,
        completados: 1,
        tiempoCompletadosMs: 10000,
        inicioActual: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      final Duration? eta2 = avanzada.eta;
      expect(eta2, isNotNull);
      expect(eta2!.inSeconds, inInclusiveRange(13, 16));
      expect(eta2 < eta1, isTrue);
    });

    test('ETA nunca es negativa aunque la pista actual se demore', () {
      final DownloadQueueState lenta = DownloadQueueState(
        pendientes: const <int>[2],
        actual: 2,
        completados: 1,
        tiempoCompletadosMs: 5000, // estimaba 5 s/pista
        inicioActual: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      expect(lenta.eta, Duration.zero);
    });
  });

  group('DownloadQueueState · copyWith', () {
    test('limpiarActual borra la pista en curso y su inicio', () {
      final DownloadQueueState s = DownloadQueueState(
        pendientes: const <int>[2, 3],
        actual: 2,
        inicioActual: DateTime.now(),
      ).copyWith(limpiarActual: true);
      expect(s.actual, isNull);
      expect(s.inicioActual, isNull);
    });

    test('reiniciarBytes pone recibidos/total en cero/null', () {
      const DownloadQueueState s = DownloadQueueState(recibidos: 80, total: 120);
      final DownloadQueueState limpio = s.copyWith(reiniciarBytes: true);
      expect(limpio.recibidos, 0);
      expect(limpio.total, isNull);
    });

    test('conserva los campos no especificados', () {
      const DownloadQueueState s = DownloadQueueState(
        pendientes: <int>[5, 6],
        completados: 2,
        tiempoCompletadosMs: 4000,
      );
      final DownloadQueueState s2 = s.copyWith(completados: 3);
      expect(s2.completados, 3);
      expect(s2.pendientes, <int>[5, 6]);
      expect(s2.tiempoCompletadosMs, 4000);
    });
  });
}
