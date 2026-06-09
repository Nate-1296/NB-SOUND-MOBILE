import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../library/application/library_providers.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/data/offline_store.dart';
import '../../sync/application/conexion_provider.dart';
import '../application/profile_providers.dart';

/// Perfil del usuario con estadísticas locales: pistas y favoritas en el teléfono,
/// espacio ocupado por las descargas y nº de pistas con karaoke. Se abre desde
/// "General" al tocar la tarjeta de perfil.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final PerfilLocal? perfil = ref.watch(perfilProvider).value;
    final ConexionEstado conexion = ref.watch(conexionPcProvider);
    final int nPistas = ref.watch(pistasProvider).value?.length ?? 0;
    final int nFavoritas = ref.watch(favoritasProvider).value?.length ?? 0;
    final int nKaraoke =
        ref.watch(resumenDescargasProvider).value?.stemsDone ?? 0;
    final EspacioOffline espacio =
        ref.watch(espacioOfflineProvider).value ?? const EspacioOffline();

    final String nombre = (perfil?.nombre.isNotEmpty ?? false)
        ? perfil!.nombre
        : 'NB Sound';
    final String inicial = nombre.substring(0, 1).toUpperCase();

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            const SubHeader(title: 'Perfil'),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                children: <Widget>[
                  Container(
                    width: 84,
                    height: 84,
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
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: c.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: NbFonts.display,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    conexion.etiqueta,
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.text3,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  _Stat(icon: AppIcons.note, valor: '$nPistas', etiqueta: 'pistas'),
                  const SizedBox(width: 12),
                  _Stat(
                    icon: AppIcons.heart,
                    valor: '$nFavoritas',
                    etiqueta: 'favoritas',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: <Widget>[
                  _Stat(
                    icon: AppIcons.download,
                    valor: _formatBytes(espacio.total),
                    etiqueta: 'descargado',
                  ),
                  const SizedBox(width: 12),
                  _Stat(
                    icon: AppIcons.mic,
                    valor: '$nKaraoke',
                    etiqueta: 'con karaoke',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.valor,
    required this.etiqueta,
  });
  final IconData icon;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(icon, color: c.accent, size: 18),
            const SizedBox(height: 10),
            Text(
              valor,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: NbFonts.display,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: c.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              etiqueta,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: c.text3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formato compacto de tamaño en disco.
String _formatBytes(int b) {
  if (b < 1024) {
    return '$b B';
  }
  const List<String> u = <String>['KB', 'MB', 'GB', 'TB'];
  double v = b / 1024;
  int i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v.toStringAsFixed(v >= 10 ? 0 : 1)} ${u[i]}';
}
