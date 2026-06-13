import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';

/// Configuración: accesos a Ecualizador, Temas (los 63 del escritorio) e Ícono de
/// la app. Cada uno abre su propia pantalla.
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
            _Tile(
              icon: AppIcons.equalizer,
              label: 'Ecualizador',
              subtitle: 'Presets, bandas, normalizador y omitir silencios',
              onTap: () => context.push('/ecualizador'),
            ),
            _Tile(
              icon: AppIcons.palette2,
              label: 'Temas',
              subtitle: 'Los 63 temas de NB Sound',
              onTap: () => context.push('/temas'),
            ),
            _Tile(
              icon: AppIcons.image,
              label: 'Ícono de la app',
              subtitle: 'Cambia el ícono de tu pantalla de inicio',
              onTap: () => context.push('/icono-app'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c.text2, size: 22),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text3,
        ),
      ),
      trailing: Icon(AppIcons.chevronRight, color: c.text3, size: 20),
    );
  }
}
