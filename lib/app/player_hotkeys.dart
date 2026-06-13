import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/player/application/playback.dart';

/// Atajos de teclado del reproductor para dispositivos con teclado físico
/// (Chromebook, tablets/teléfonos con teclado). Se monta por encima del
/// Navigator (en el `builder` de la app) para capturarlos en cualquier pantalla:
///
/// - **Espacio** / **Play-Pause** (tecla multimedia): reproducir/pausar.
/// - **Flecha →/←**: avanzar/retroceder 10 s.
/// - **Ctrl+→/←** o **Anterior/Siguiente** (teclas multimedia): pista anterior/siguiente.
///
/// Al capturar la tecla **Espacio**, además, se evita el comportamiento por
/// defecto del sistema en Chromebook (el marco de foco verde / scroll inútil).
/// Los campos de texto enfocados consumen sus teclas antes (no se disparan los
/// atajos mientras se escribe).
class PlayerHotkeys extends ConsumerWidget {
  const PlayerHotkeys({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final PlaybackActions acciones = ref.read(playbackActionsProvider);
    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.mediaPlayPause): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.mediaPlay): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.mediaPause): _PlayPauseIntent(),
        SingleActivator(LogicalKeyboardKey.mediaTrackNext): _NextIntent(),
        SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): _PrevIntent(),
        SingleActivator(LogicalKeyboardKey.arrowRight): _SeekIntent(10),
        SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekIntent(-10),
        SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            _NextIntent(),
        SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            _PrevIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _PlayPauseIntent: CallbackAction<_PlayPauseIntent>(
            onInvoke: (_) {
              acciones.togglePlay();
              return null;
            },
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (_) {
              acciones.next();
              return null;
            },
          ),
          _PrevIntent: CallbackAction<_PrevIntent>(
            onInvoke: (_) {
              acciones.prev();
              return null;
            },
          ),
          _SeekIntent: CallbackAction<_SeekIntent>(
            onInvoke: (_SeekIntent i) {
              acciones.seekRelativo(i.segundos);
              return null;
            },
          ),
        },
        child: child,
      ),
    );
  }
}

class _PlayPauseIntent extends Intent {
  const _PlayPauseIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _SeekIntent extends Intent {
  const _SeekIntent(this.segundos);
  final int segundos;
}
