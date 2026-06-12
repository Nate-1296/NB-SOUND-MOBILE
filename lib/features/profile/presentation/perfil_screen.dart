import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../library/application/library_providers.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/data/offline_store.dart';
import '../../sync/application/conexion_provider.dart';
import '../application/profile_providers.dart';

/// Perfil del usuario con estadísticas locales (pistas, favoritas, álbumes,
/// artistas, playlists, reproducciones, espacio y karaoke), foto editable y
/// nombre persistente (no se sobreescribe con el del PC al sincronizar). Se abre
/// desde "General" al tocar la tarjeta de perfil.
class PerfilScreen extends ConsumerWidget {
  const PerfilScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ConexionEstado conexion = ref.watch(conexionPcProvider);
    final String nombre = ref.watch(nombrePerfilProvider);
    final ImageProvider? foto = ref.watch(avatarPerfilProvider);

    final int nPistas = ref.watch(pistasProvider).value?.length ?? 0;
    final int nFavoritas = ref.watch(favoritasProvider).value?.length ?? 0;
    final int nAlbumes = ref.watch(albumsProvider).value?.length ?? 0;
    final int nArtistas = ref.watch(artistasProvider).value?.length ?? 0;
    final int nPlaylists =
        (ref.watch(playlistsLocalesProvider).value?.length ?? 0) +
            ref.watch(playlistsGuardadasProvider).length;
    final int nReproducciones = (ref.watch(conteoPorPistaProvider).value ??
            const <int, int>{})
        .values
        .fold<int>(0, (int a, int b) => a + b);
    final int nKaraoke =
        ref.watch(resumenDescargasProvider).value?.stemsDone ?? 0;
    final EspacioOffline espacio =
        ref.watch(espacioOfflineProvider).value ?? const EspacioOffline();

    final String mostrado = nombre.isEmpty ? 'NB Sound' : nombre;
    final String inicial = mostrado.substring(0, 1).toUpperCase();

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
                  // Avatar: toca para cambiar/quitar la foto.
                  GestureDetector(
                    onTap: () => _menuFoto(context, ref, tieneFoto: foto != null),
                    child: Stack(
                      children: <Widget>[
                        Container(
                          width: 96,
                          height: 96,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c.soft,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.line2, width: 1.5),
                            image: foto != null
                                ? DecorationImage(image: foto, fit: BoxFit.cover)
                                : null,
                          ),
                          child: foto != null
                              ? null
                              : Text(
                                  inicial,
                                  style: TextStyle(
                                    fontFamily: NbFonts.display,
                                    fontSize: 38,
                                    fontWeight: FontWeight.w800,
                                    color: c.accent,
                                  ),
                                ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: c.accent,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.bg, width: 2),
                            ),
                            child: Icon(AppIcons.edit, color: c.ink, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Nombre: toca para editarlo (persistente).
                  GestureDetector(
                    onTap: () => _editarNombre(context, ref, nombre),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            mostrado,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: NbFonts.display,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(AppIcons.edit, color: c.text3, size: 18),
                      ],
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
            _filaStats(<Widget>[
              _Stat(icon: AppIcons.note, valor: '$nPistas', etiqueta: 'pistas'),
              _Stat(
                  icon: AppIcons.heart,
                  valor: '$nFavoritas',
                  etiqueta: 'favoritas'),
            ]),
            _filaStats(<Widget>[
              _Stat(icon: AppIcons.disc, valor: '$nAlbumes', etiqueta: 'álbumes'),
              _Stat(
                  icon: AppIcons.user, valor: '$nArtistas', etiqueta: 'artistas'),
            ]),
            _filaStats(<Widget>[
              _Stat(
                  icon: AppIcons.queue,
                  valor: '$nPlaylists',
                  etiqueta: 'playlists'),
              _Stat(
                icon: AppIcons.play,
                valor: '$nReproducciones',
                etiqueta: 'reproducciones',
              ),
            ]),
            _filaStats(<Widget>[
              _Stat(
                icon: AppIcons.download,
                valor: _formatBytes(espacio.total),
                etiqueta: 'descargado',
              ),
              _Stat(
                  icon: AppIcons.mic, valor: '$nKaraoke', etiqueta: 'con karaoke'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _filaStats(List<Widget> hijos) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
        child: Row(
          children: <Widget>[
            hijos[0],
            const SizedBox(width: 12),
            hijos[1],
          ],
        ),
      );

  Future<void> _editarNombre(
      BuildContext context, WidgetRef ref, String actual) async {
    final NbColors c = context.nb;
    final TextEditingController ctrl = TextEditingController(text: actual);
    final String? nuevo = await showDialog<String>(
      context: context,
      builder: (BuildContext dctx) => AlertDialog(
        backgroundColor: c.bg2,
        title: Text('Tu nombre',
            style: TextStyle(color: c.text, fontFamily: NbFonts.display)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: c.text, fontFamily: NbFonts.ui),
          decoration: InputDecoration(
            hintText: 'Escribe tu nombre',
            hintStyle: TextStyle(color: c.text3),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.line2),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: c.accent),
            ),
          ),
          onSubmitted: (String v) => Navigator.of(dctx).pop(v.trim()),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dctx).pop(),
            child: Text('Cancelar', style: TextStyle(color: c.text2)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: c.accent,
              foregroundColor: c.ink,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (nuevo != null) {
      await ref.read(perfilUsuarioProvider.notifier).setNombre(nuevo);
    }
  }

  Future<void> _menuFoto(BuildContext context, WidgetRef ref,
      {required bool tieneFoto}) async {
    final NbColors c = context.nb;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg2,
      showDragHandle: true,
      builder: (BuildContext sctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: Icon(AppIcons.user, color: c.text),
              title: Text('Elegir de la galería',
                  style: TextStyle(color: c.text, fontFamily: NbFonts.ui)),
              onTap: () async {
                Navigator.of(sctx).pop();
                await _elegirFoto(context, ref);
              },
            ),
            if (tieneFoto)
              ListTile(
                leading: const Icon(AppIcons.trash, color: Color(0xFFE5484D)),
                title: const Text('Quitar foto',
                    style: TextStyle(
                        color: Color(0xFFE5484D), fontFamily: NbFonts.ui)),
                onTap: () async {
                  Navigator.of(sctx).pop();
                  await ref.read(perfilUsuarioProvider.notifier).setFoto(null);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _elegirFoto(BuildContext context, WidgetRef ref) async {
    try {
      final XFile? picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 88,
      );
      if (picked == null) {
        return;
      }
      // Copia a documentos para que persista (la caché del picker puede limpiarse).
      final Directory docs = await getApplicationDocumentsDirectory();
      final String ext = p.extension(picked.path).isEmpty
          ? '.jpg'
          : p.extension(picked.path);
      final String destino = p.join(
          docs.path, 'perfil_${DateTime.now().millisecondsSinceEpoch}$ext');
      await File(picked.path).copy(destino);
      await ref.read(perfilUsuarioProvider.notifier).setFoto(destino);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar la imagen.')),
        );
      }
    }
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
