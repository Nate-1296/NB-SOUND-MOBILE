import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/db/database.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/placeholder_body.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../library/application/library_providers.dart';
import '../application/download_providers.dart';
import '../data/download_repository.dart';

/// Gestión del audio descargado para escucha offline.
class DescargasScreen extends ConsumerWidget {
  const DescargasScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final List<DescargaAudio> descargas =
        ref.watch(descargasProvider).value ?? const <DescargaAudio>[];
    final Map<int, Pista> porId = <int, Pista>{
      for (final Pista p in ref.watch(pistasProvider).value ?? const <Pista>[])
        p.id: p,
    };
    final DownloadQueueState queue = ref.watch(downloadQueueProvider);

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SubHeader(title: 'Descargas'),
            if (queue.activo)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: LinearProgressIndicator(
                  value: queue.progreso,
                  backgroundColor: c.line2,
                  color: c.accent,
                ),
              ),
            Expanded(
              child: descargas.isEmpty
                  ? const PlaceholderBody(
                      icon: AppIcons.download,
                      title: 'Sin descargas',
                      subtitle:
                          'Descarga pistas, álbumes o playlists para escucharlas '
                          'sin conexión.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: descargas.length,
                      itemBuilder: (BuildContext context, int i) {
                        final DescargaAudio d = descargas[i];
                        return _DescargaTile(
                          descarga: d,
                          pista: porId[d.pistaId],
                          progreso: d.pistaId == queue.actual
                              ? queue.progreso
                              : null,
                          onEliminar: () => ref
                              .read(downloadQueueProvider.notifier)
                              .eliminar(d.pistaId),
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

class _DescargaTile extends StatelessWidget {
  const _DescargaTile({
    required this.descarga,
    required this.pista,
    required this.progreso,
    required this.onEliminar,
  });

  final DescargaAudio descarga;
  final Pista? pista;
  final double? progreso;
  final VoidCallback onEliminar;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final (IconData icon, Color color, String label) = switch (descarga.estado) {
      DownloadEstado.done => (AppIcons.downloadDone, c.accent, 'Descargada'),
      DownloadEstado.downloading => (
          AppIcons.downloading,
          c.accent,
          progreso != null
              ? 'Descargando ${(progreso! * 100).round()}%'
              : 'Descargando…',
        ),
      DownloadEstado.failed => (AppIcons.close, const Color(0xFFFF6B6B), 'Falló'),
      _ => (AppIcons.download, c.text3, 'En cola'),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        pista?.titulo ?? 'Pista ${descarga.pistaId}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          color: c.text,
        ),
      ),
      subtitle: Text(
        pista != null ? '${pista!.artistaNombre} · $label' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text2,
        ),
      ),
      trailing: IconButton(
        onPressed: onEliminar,
        icon: Icon(AppIcons.trash, color: c.text3, size: 20),
      ),
    );
  }
}
