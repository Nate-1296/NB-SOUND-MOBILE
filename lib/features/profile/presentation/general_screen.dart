import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../remote_control/presentation/destination_sheet.dart';
import '../../sync/application/conexion_provider.dart';
import '../application/profile_providers.dart';

/// Vista "General": tarjeta de perfil (toca para ver tus estadísticas), estado de
/// conexión real con el PC y accesos a Configuración, Sincronizar y Descargas.
class GeneralScreen extends ConsumerWidget {
  const GeneralScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final PerfilLocal? perfil = ref.watch(perfilProvider).value;
    final ConexionEstado conexion = ref.watch(conexionPcProvider);

    final String nombre = (perfil?.nombre.isNotEmpty ?? false)
        ? perfil!.nombre
        : 'NB Sound';
    final String inicial = nombre.substring(0, 1).toUpperCase();

    final (Color colorEstado, IconData iconoEstado) = switch (conexion) {
      ConexionEstado.conectado => (const Color(0xFF3DDC84), AppIcons.wifi),
      ConexionEstado.desconectado => (const Color(0xFFFFA502), AppIcons.laptop),
      ConexionEstado.sinEnlace => (c.text3, AppIcons.laptop),
    };

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            const SubHeader(title: 'General'),
            // Tarjeta de perfil: toca para abrir tus estadísticas.
            InkWell(
              onTap: () => context.push('/perfil'),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.soft,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.line2, width: 1.5),
                      ),
                      child: Text(
                        inicial,
                        style: TextStyle(
                          fontFamily: NbFonts.display,
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: c.accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NbFonts.display,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: <Widget>[
                              Icon(iconoEstado, size: 13, color: colorEstado),
                              const SizedBox(width: 6),
                              Text(
                                conexion.etiqueta,
                                style: TextStyle(
                                  fontFamily: NbFonts.ui,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: colorEstado,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(AppIcons.chevronRight, color: c.text3, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            _Tile(
              icon: AppIcons.sliders,
              label: 'Configuración',
              subtitle: 'Ecualizador y temas',
              onTap: () => context.push('/configuracion'),
            ),
            _Tile(
              icon: AppIcons.cast,
              label: 'Reproducir en…',
              subtitle: 'Este teléfono o tu PC',
              onTap: () => mostrarSelectorDestino(context, ref),
            ),
            _Tile(
              icon: AppIcons.sync,
              label: 'Sincronizar con PC',
              onTap: () => context.push('/sync'),
            ),
            _Tile(
              icon: AppIcons.download,
              label: 'Descargas',
              onTap: () => context.push('/descargas'),
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
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;

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
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
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
