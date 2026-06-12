import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../player/application/playback.dart';
import '../../sync/application/conexion_provider.dart';

/// Hoja para elegir dónde suena la música (Spotify Connect).
Future<void> mostrarSelectorDestino(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg2,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
      // Consumer: el estado de conexión (y el destino activo) se reflejan en
      // vivo dentro de la hoja, así "Mi PC" se habilita/atenúa al instante.
      return Consumer(
        builder: (BuildContext context, WidgetRef ref, _) {
          final PlaybackTarget actual = ref.watch(playbackTargetProvider);
          final bool pcConectado =
              ref.watch(conexionPcProvider) == ConexionEstado.conectado;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Reproducir en',
                      style: TextStyle(
                        fontFamily: NbFonts.display,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                  ),
                ),
                _DestinoTile(
                  icon: AppIcons.phone,
                  label: 'Este teléfono',
                  activo: actual == PlaybackTarget.local,
                  onTap: () {
                    ref.read(playbackTargetProvider.notifier).usarLocal();
                    Navigator.of(sheetContext).pop();
                  },
                ),
                _DestinoTile(
                  icon: AppIcons.laptop,
                  label: 'Mi PC',
                  activo: actual == PlaybackTarget.remote,
                  // Solo se puede reproducir en el PC si está conectado: si no,
                  // se muestra atenuado y sin posibilidad de pulsarlo.
                  enabled: pcConectado,
                  subtitle: pcConectado ? null : 'No conectado',
                  onTap: () async {
                    final bool ok = await ref
                        .read(playbackTargetProvider.notifier)
                        .usarRemoto();
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Empareja un PC primero (Perfil → '
                              'Sincronizar con PC).'),
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      );
    },
  );
}

class _DestinoTile extends StatelessWidget {
  const _DestinoTile({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
    this.enabled = true,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;
  final bool enabled;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color principal =
        activo ? c.accent : (enabled ? c.text : c.text3);
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      leading: Icon(icon, color: principal),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: principal,
        ),
      ),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12,
                color: c.text3,
              ),
            ),
      trailing: activo ? Icon(AppIcons.check, color: c.accent) : null,
    );
  }
}
