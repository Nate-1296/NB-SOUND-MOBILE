import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/sub_header.dart';
import '../application/equalizer_controller.dart';

/// Pantalla de ecualizador (Android): activar/desactivar, presets, bandas
/// ajustables (que pasan a "Personalizado"), normalizador de volumen y omitir
/// silencios. En iOS/otros muestra que no está disponible.
class EcualizadorScreen extends ConsumerWidget {
  const EcualizadorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final EqEstado eq = ref.watch(equalizerControllerProvider);
    final EqualizerController ctrl =
        ref.read(equalizerControllerProvider.notifier);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            const SubHeader(title: 'Ecualizador'),
            if (!eq.soportado)
              const _Aviso(
                icon: AppIcons.equalizer,
                texto:
                    'El ecualizador está disponible solo en Android por ahora.',
              )
            else ...<Widget>[
              // Activar
              _SwitchTile(
                titulo: 'Ecualizador',
                subtitulo: 'Ajusta las frecuencias del sonido.',
                valor: eq.habilitado,
                onChanged: ctrl.setHabilitado,
              ),
              const SectionLabel(
                label: 'Presets',
                padding: EdgeInsets.fromLTRB(22, 8, 18, 10),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final EqPreset p in EqPreset.values)
                      if (p != EqPreset.custom || eq.preset == EqPreset.custom)
                        _PresetChip(
                          label: p.etiqueta,
                          activo: eq.preset == p,
                          onTap: () => ctrl.seleccionarPreset(p),
                        ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const SectionLabel(
                label: 'Bandas',
                padding: EdgeInsets.fromLTRB(22, 0, 18, 8),
              ),
              if (!eq.bandasListas)
                const _Aviso(
                  icon: AppIcons.play,
                  texto:
                      'Reproduce una canción para ajustar las bandas del '
                      'ecualizador de tu dispositivo.',
                )
              else
                _Bandas(eq: eq, ctrl: ctrl),
              const SizedBox(height: 18),
              const SectionLabel(
                label: 'Sonido',
                padding: EdgeInsets.fromLTRB(22, 0, 18, 8),
              ),
              _SwitchTile(
                titulo: 'Normalizador de volumen',
                subtitulo: 'Sube el volumen percibido de pistas suaves.',
                valor: eq.normalizar,
                onChanged: ctrl.setNormalizar,
              ),
              _SwitchTile(
                titulo: 'Omitir silencios',
                subtitulo: 'Salta los silencios al inicio/fin de las pistas.',
                valor: eq.omitirSilencios,
                onChanged: ctrl.setOmitirSilencios,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de bandas con sliders verticales (dB) y etiqueta de frecuencia.
class _Bandas extends StatelessWidget {
  const _Bandas({required this.eq, required this.ctrl});

  final EqEstado eq;
  final EqualizerController ctrl;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < eq.ganancias.length; i++)
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      '${eq.ganancias[i] >= 0 ? '+' : ''}${eq.ganancias[i].toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.text2,
                      ),
                    ),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            activeTrackColor: c.accent,
                            inactiveTrackColor: c.line2,
                            thumbColor: c.accent,
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            min: eq.minDb,
                            max: eq.maxDb,
                            value: eq.ganancias[i].clamp(eq.minDb, eq.maxDb),
                            onChanged: (double v) => ctrl.setGanancia(i, v),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatHz(eq.frecuencias.length > i
                          ? eq.frecuencias[i]
                          : 0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _formatHz(double hz) {
    if (hz >= 1000) {
      final double k = hz / 1000;
      return '${k % 1 == 0 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)} kHz';
    }
    return '${hz.round()} Hz';
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.activo,
    required this.onTap,
  });

  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Material(
      color: activo ? c.soft : c.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: activo ? c.accent : c.line2),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: activo ? c.accent : c.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.titulo,
    required this.subtitulo,
    required this.valor,
    required this.onChanged,
  });

  final String titulo;
  final String subtitulo;
  final bool valor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return SwitchListTile(
      value: valor,
      activeThumbColor: c.accent,
      onChanged: onChanged,
      title: Text(
        titulo,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        subtitulo,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text3,
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  const _Aviso({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: <Widget>[
          Icon(icon, color: c.text3, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 13,
                height: 1.4,
                color: c.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
