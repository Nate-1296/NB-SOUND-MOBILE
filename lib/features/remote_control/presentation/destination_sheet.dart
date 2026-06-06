import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../player/application/playback.dart';

/// Hoja para elegir dónde suena la música (Spotify Connect).
Future<void> mostrarSelectorDestino(BuildContext context, WidgetRef ref) {
  final NbColors c = context.nb;
  final PlaybackTarget actual = ref.read(playbackTargetProvider);

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: c.bg2,
    showDragHandle: true,
    builder: (BuildContext sheetContext) {
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
}

class _DestinoTile extends StatelessWidget {
  const _DestinoTile({
    required this.icon,
    required this.label,
    required this.activo,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool activo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: activo ? c.accent : c.text),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: activo ? c.accent : c.text,
        ),
      ),
      trailing: activo ? Icon(AppIcons.check, color: c.accent) : null,
    );
  }
}
