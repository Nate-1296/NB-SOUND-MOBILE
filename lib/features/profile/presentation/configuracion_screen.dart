import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/section_label.dart';
import '../../../shared/widgets/sub_header.dart';

/// Configuración: Ecualizador y Temas (los 63 del escritorio, en lista expandible
/// de 9 en 9).
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            const SubHeader(title: 'Configuración'),
            ListTile(
              onTap: () => context.push('/ecualizador'),
              leading: Icon(AppIcons.equalizer, color: c.text2, size: 22),
              title: Text(
                'Ecualizador',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: c.text,
                ),
              ),
              subtitle: Text(
                'Presets, bandas, normalizador y omitir silencios',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  color: c.text3,
                ),
              ),
              trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
            ),
            const SizedBox(height: 16),
            const SectionLabel(
              label: 'Temas',
              padding: EdgeInsets.fromLTRB(22, 0, 18, 12),
            ),
            const _ThemesPicker(),
          ],
        ),
      ),
    );
  }
}

/// Selector de temas expandible: muestra 9, "Mostrar más" revela 9 más,
/// "Mostrar menos" vuelve a 9.
class _ThemesPicker extends ConsumerStatefulWidget {
  const _ThemesPicker();

  @override
  ConsumerState<_ThemesPicker> createState() => _ThemesPickerState();
}

class _ThemesPickerState extends ConsumerState<_ThemesPicker> {
  static const int _paso = 9;
  int _visibles = _paso;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final String activa = ref.watch(themeControllerProvider);
    final int total = kNbThemes.length;
    final int n = _visibles.clamp(0, total);

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < n; i += 2)
                Padding(
                  padding: EdgeInsets.only(bottom: i + 2 < n ? 10 : 0),
                  child: Row(
                    children: <Widget>[
                      Expanded(child: _chip(ref, kNbThemes[i], activa)),
                      const SizedBox(width: 10),
                      if (i + 1 < n)
                        Expanded(child: _chip(ref, kNbThemes[i + 1], activa))
                      else
                        const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (n < total)
              TextButton.icon(
                onPressed: () => setState(
                    () => _visibles = (_visibles + _paso).clamp(0, total)),
                icon: Icon(AppIcons.expandMore, size: 18, color: c.accent),
                label: Text(
                  'Mostrar más',
                  style: TextStyle(color: c.accent, fontFamily: NbFonts.ui),
                ),
              ),
            if (n > _paso)
              TextButton.icon(
                onPressed: () => setState(() => _visibles = _paso),
                icon: Icon(AppIcons.expandLess, size: 18, color: c.text2),
                label: Text(
                  'Mostrar menos',
                  style: TextStyle(color: c.text2, fontFamily: NbFonts.ui),
                ),
              ),
          ],
        ),
        if (n < total)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '$n de $total temas',
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12,
                color: c.text3,
              ),
            ),
          ),
      ],
    );
  }

  Widget _chip(WidgetRef ref, NbThemeDef def, String activa) => _ThemeChip(
        def: def,
        active: def.key == activa,
        onTap: () => ref.read(themeControllerProvider.notifier).select(def.key),
      );
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.def,
    required this.active,
    required this.onTap,
  });

  final NbThemeDef def;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color dot = def.colors.accent;
    return Material(
      color: active ? c.soft : c.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: active ? c.accent : c.line2, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: <Widget>[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: dot,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.line2, width: 0.5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  def.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: active ? c.accent : c.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
