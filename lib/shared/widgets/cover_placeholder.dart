import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import 'app_icons.dart';

/// Tipo de contenido cuya portada/foto falta, para elegir un respaldo visual
/// **distinto** por tipo (disco para álbum, persona para artista, nota/barras
/// para pista, lista para playlist). Permite que un álbum, un artista o una
/// pista sin carátula muestren un placeholder reconocible en cualquier vista
/// (inicio, buscar, biblioteca, playlists, reproductor…), en vez del antiguo
/// cuadrado gris plano.
enum CoverKind { album, artist, track, playlist }

/// Icono de respaldo para cada [CoverKind].
IconData iconForCoverKind(CoverKind kind) => switch (kind) {
      CoverKind.album => AppIcons.albumFallback,
      CoverKind.artist => AppIcons.artistFallback,
      CoverKind.track => AppIcons.trackFallback,
      CoverKind.playlist => AppIcons.playlistFallback,
    };

/// Degradado de respaldo en tono de marca, **variado de forma determinista** por
/// [seed] (id/título estable) para que no todas las portadas faltantes se vean
/// idénticas, pero siempre **armónico con el tema activo**: se deriva de los
/// colores del tema (no introduce colores que choquen con los 63 temas).
LinearGradient coverPlaceholderGradient(NbColors c, Object? seed) {
  final int h = (seed?.hashCode ?? 0) & 0x7fffffff;
  // Tinte de acento muy tenue y ligeramente variable (0.10–0.26): hace que el
  // respaldo se lea como portada intencional, no como un skeleton de carga.
  final double t = 0.10 + (h % 5) * 0.04;
  final Color base = Color.lerp(c.bg3, c.accent, t)!;
  final Color base2 = Color.lerp(c.bg3, c.ambient, t * 0.6)!;
  // Alterna la diagonal según el seed: más variedad sin colores nuevos.
  final bool flip = (h ~/ 5).isEven;
  return LinearGradient(
    begin: flip ? Alignment.topLeft : Alignment.topRight,
    end: flip ? Alignment.bottomRight : Alignment.bottomLeft,
    colors: <Color>[base, base2],
  );
}

/// Respaldo cuadrado tipado: degradado de marca + icono/animación según el
/// [kind]. Pensado para **rellenar** su caja (el llamador clipa las esquinas):
/// se usa como hijo de [Cover] cuando no hay imagen.
///
/// [animated] habilita una animación ligera (un único [AnimationController]):
/// barras de ecualizador para pistas, respiración del icono para el resto.
/// **Usar solo en contextos de placeholder único visible** (reproductor,
/// mini-reproductor, héroes de detalle); en listas/rejillas dejarlo estático.
class CoverPlaceholder extends StatelessWidget {
  const CoverPlaceholder({
    super.key,
    required this.kind,
    this.seed,
    this.animated = false,
    this.iconSizeFactor = 0.42,
  });

  final CoverKind kind;
  final Object? seed;
  final bool animated;

  /// Tamaño del icono como fracción del lado de la caja (acotado 14–160 px).
  final double iconSizeFactor;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: coverPlaceholderGradient(c, seed)),
      child: LayoutBuilder(
        builder: (BuildContext ctx, BoxConstraints cons) {
          final double dim = math.min(
            cons.maxWidth.isFinite ? cons.maxWidth : 64,
            cons.maxHeight.isFinite ? cons.maxHeight : 64,
          );
          final double iconSize = (dim * iconSizeFactor).clamp(14.0, 160.0);
          return Center(
            child: _content(c, iconSize),
          );
        },
      ),
    );
  }

  Widget _content(NbColors c, double iconSize) {
    if (animated && kind == CoverKind.track) {
      return EqualizerBars(color: c.text2, maxHeight: iconSize);
    }
    final Widget icon =
        Icon(iconForCoverKind(kind), size: iconSize, color: c.text3);
    return animated ? Breathing(child: icon) : icon;
  }
}

/// Anima a su hijo con una "respiración" sutil (escala + opacidad), con un único
/// [AnimationController]. Barato: pensado para un placeholder único visible.
class Breathing extends StatefulWidget {
  const Breathing({
    super.key,
    required this.child,
    this.minScale = 0.92,
    this.maxScale = 1.08,
    this.minOpacity = 0.65,
    this.period = const Duration(milliseconds: 2600),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final double minOpacity;
  final Duration period;

  @override
  State<Breathing> createState() => _BreathingState();
}

class _BreathingState extends State<Breathing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.period)
        ..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curve =
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    return AnimatedBuilder(
      animation: curve,
      builder: (BuildContext context, Widget? child) {
        final double t = curve.value;
        final double scale =
            widget.minScale + (widget.maxScale - widget.minScale) * t;
        final double opacity = widget.minOpacity + (1 - widget.minOpacity) * t;
        return Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: widget.child,
    );
  }
}

/// Barras de ecualizador animadas (placeholder "vivo" para pistas). Un único
/// [AnimationController]; cuatro barras con fase desfasada. Barato y
/// reconocible como "música".
class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    required this.color,
    required this.maxHeight,
  });

  final Color color;
  final double maxHeight;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  // Fases distintas por barra para un movimiento orgánico (no al unísono).
  static const List<double> _phases = <double>[0.0, 0.35, 0.7, 0.18];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _barHeight(double maxH, double t, double phase) {
    final double v = 0.30 + 0.70 * (0.5 + 0.5 * math.sin((t + phase) * 2 * math.pi));
    return maxH * v;
  }

  @override
  Widget build(BuildContext context) {
    final double maxH = widget.maxHeight;
    final double w = (maxH * 0.16).clamp(2.0, 22.0);
    final double gap = (maxH * 0.12).clamp(2.0, 14.0);
    return SizedBox(
      height: maxH,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (BuildContext context, Widget? _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (int i = 0; i < _phases.length; i++) ...<Widget>[
                if (i > 0) SizedBox(width: gap),
                Container(
                  width: w,
                  height: _barHeight(maxH, _ctrl.value, _phases[i]),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(w / 2),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// Celda de un mosaico/portada de playlist: imagen real o respaldo tipado.
/// Permite que las pistas sin carátula se reflejen como placeholder dentro del
/// mosaico ("si no hay carátula en una o varias, queda como si fuera esa la
/// portada").
sealed class CoverTile {
  const CoverTile();
}

/// Celda con imagen real.
class CoverImageTile extends CoverTile {
  const CoverImageTile(this.image);
  final ImageProvider image;
}

/// Celda de respaldo tipado (pista sin carátula, por defecto).
class CoverFallbackTile extends CoverTile {
  const CoverFallbackTile({this.kind = CoverKind.track, this.seed});
  final CoverKind kind;
  final Object? seed;
}
