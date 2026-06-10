import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'player_controller.dart';

/// Temporizador de apagado ("sleep timer"): pausa la reproducción tras la
/// duración elegida. El estado expone la duración seleccionada (null = apagado);
/// un [Timer] interno pausa el reproductor al expirar.
class SleepTimer extends Notifier<Duration?> {
  Timer? _timer;

  @override
  Duration? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  /// Programa la pausa dentro de [d]. Reemplaza un temporizador previo.
  void activar(Duration d) {
    _timer?.cancel();
    state = d;
    _timer = Timer(d, () {
      ref.read(playerControllerProvider.notifier).pausar();
      _timer = null;
      state = null;
    });
  }

  void cancelar() {
    _timer?.cancel();
    _timer = null;
    state = null;
  }

  bool get activo => state != null;
}

final NotifierProvider<SleepTimer, Duration?> sleepTimerProvider =
    NotifierProvider<SleepTimer, Duration?>(SleepTimer.new);
