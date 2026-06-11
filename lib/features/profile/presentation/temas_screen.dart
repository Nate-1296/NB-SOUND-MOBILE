import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/theme/theme_controller.dart';
import '../../../shared/widgets/sub_header.dart';

/// Pantalla de Temas: los 63 temas del escritorio, todos a la vista (2 columnas),
/// sin "mostrar más/menos". Tocar uno lo aplica al instante y lo persiste.
class TemasScreen extends ConsumerWidget {
  const TemasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final String activa = ref.watch(themeControllerProvider);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SubHeader(title: 'Temas'),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 28),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 48,
                ),
                itemCount: kNbThemes.length,
                itemBuilder: (BuildContext context, int i) {
                  final NbThemeDef def = kNbThemes[i];
                  return _ThemeChip(
                    def: def,
                    active: def.key == activa,
                    onTap: () => ref
                        .read(themeControllerProvider.notifier)
                        .select(def.key),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
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
                width: 16,
                height: 16,
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
