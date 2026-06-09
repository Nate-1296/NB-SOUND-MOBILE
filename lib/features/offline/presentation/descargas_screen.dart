import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/daos/assets_dao.dart';
import '../../../data/db/daos/downloads_dao.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../data/db/database.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/placeholder_body.dart';
import '../../../shared/widgets/sub_header.dart';
import '../../library/application/library_providers.dart';
import '../application/download_providers.dart';
import '../data/download_repository.dart';
import '../data/offline_store.dart';

/// Gestión de la descarga offline: contadores reales (N de M), desglose por
/// categoría, espacio en disco, playlists guardadas y la lista de pistas.
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
        child: CustomScrollView(
          slivers: <Widget>[
            const SliverToBoxAdapter(child: SubHeader(title: 'Descargas')),
            const SliverToBoxAdapter(child: _Resumen()),
            if (queue.restantes > 0)
              SliverToBoxAdapter(child: _DownloadCounter(queue: queue)),
            const SliverToBoxAdapter(child: _Acciones()),
            const SliverToBoxAdapter(child: _PlaylistsGuardadasSection()),
            if (descargas.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: PlaceholderBody(
                  icon: AppIcons.download,
                  title: 'Sin descargas',
                  subtitle:
                      'Descarga pistas, álbumes o playlists para escucharlas '
                      'sin conexión.',
                ),
              )
            else ...<Widget>[
              const SliverToBoxAdapter(child: _SeccionTitulo('Pistas')),
              SliverList.builder(
                itemCount: descargas.length,
                itemBuilder: (BuildContext context, int i) {
                  final DescargaAudio d = descargas[i];
                  return _DescargaTile(
                    descarga: d,
                    pista: porId[d.pistaId],
                    progreso:
                        d.pistaId == queue.actual ? queue.progreso : null,
                    onEliminar: () => ref
                        .read(downloadQueueProvider.notifier)
                        .eliminar(d.pistaId),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de resumen con los contadores fijos (N de M) y el desglose por
/// categoría + espacio en disco. Datos reactivos de la BD (no del lote en curso).
class _Resumen extends ConsumerWidget {
  const _Resumen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ResumenDescargas r =
        ref.watch(resumenDescargasProvider).value ?? const ResumenDescargas();
    final int total = ref.watch(totalPistasProvider).value ?? 0;
    final ConteoAsset covers =
        ref.watch(conteoCoversProvider).value ?? const ConteoAsset();
    final ConteoAsset artistas =
        ref.watch(conteoArtistasProvider).value ?? const ConteoAsset();
    final EspacioOffline espacio =
        ref.watch(espacioOfflineProvider).value ?? const EspacioOffline();

    final int fallidas =
        r.totalFallidas + covers.failed + artistas.failed;
    final double? progreso =
        total > 0 ? (r.audioDone / total).clamp(0.0, 1.0) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Pistas descargadas',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${r.audioDone} de $total',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progreso,
                minHeight: 6,
                backgroundColor: c.line2,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _Chip(icon: AppIcons.disc, label: 'Portadas', n: covers.done),
                _Chip(icon: AppIcons.user, label: 'Artistas', n: artistas.done),
                _Chip(icon: AppIcons.note, label: 'Letras', n: r.lyricsDone),
                _Chip(
                    icon: AppIcons.mic, label: 'Karaoke', n: r.stemsDone),
                if (fallidas > 0)
                  _Chip(
                    icon: AppIcons.close,
                    label: 'Con error',
                    n: fallidas,
                    color: const Color(0xFFFF6B6B),
                  ),
              ],
            ),
            if (espacio.total > 0) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Ocupado: ${_formatBytes(espacio.total)}  ·  '
                'audio ${_formatBytes(espacio.audio)} · '
                'karaoke ${_formatBytes(espacio.stems)} · '
                'imágenes ${_formatBytes(espacio.covers + espacio.artists)}',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 11.5,
                  color: c.text3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.n,
    this.color,
  });

  final IconData icon;
  final String label;
  final int n;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Color col = color ?? c.text2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.bg3,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: col),
          const SizedBox(width: 6),
          Text(
            '$label $n',
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Acciones globales: reintentar fallidas y el espejo offline completo.
class _Acciones extends ConsumerWidget {
  const _Acciones();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final ResumenDescargas r =
        ref.watch(resumenDescargasProvider).value ?? const ResumenDescargas();
    final ConteoAsset covers =
        ref.watch(conteoCoversProvider).value ?? const ConteoAsset();
    final ConteoAsset artistas =
        ref.watch(conteoArtistasProvider).value ?? const ConteoAsset();
    final int fallidas = r.totalFallidas + covers.failed + artistas.failed;
    final bool descargarTodo =
        ref.watch(descargarTodoProvider).value ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
      child: Column(
        children: <Widget>[
          if (fallidas > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ref
                      .read(downloadQueueProvider.notifier)
                      .reintentarFallidas(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.line2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(AppIcons.refresh, size: 18, color: c.accent),
                  label: Text(
                    'Reintentar ${fallidas == 1 ? '1 descarga' : '$fallidas descargas'} con error',
                    style: TextStyle(
                      fontFamily: NbFonts.ui,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                    ),
                  ),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
            decoration: BoxDecoration(
              color: c.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.line2),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Descargar todo',
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mantén un espejo offline de toda la biblioteca.',
                        style: TextStyle(
                          fontFamily: NbFonts.ui,
                          fontSize: 11.5,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: descargarTodo,
                  activeThumbColor: c.accent,
                  onChanged: (bool v) async {
                    await ref.read(syncStateDaoProvider).setValor(
                          SyncStateDao.kDescargarTodo,
                          v ? '1' : '0',
                        );
                    if (v) {
                      await ref
                          .read(downloadQueueProvider.notifier)
                          .encolarTodo();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sección de playlists guardadas con su progreso de descarga (N/total).
class _PlaylistsGuardadasSection extends ConsumerWidget {
  const _PlaylistsGuardadasSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<Playlist> guardadas = ref.watch(playlistsGuardadasProvider);
    if (guardadas.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const _SeccionTitulo('Playlists guardadas'),
        for (final Playlist pl in guardadas) _PlaylistGuardadaTile(playlist: pl),
      ],
    );
  }
}

class _PlaylistGuardadaTile extends ConsumerWidget {
  const _PlaylistGuardadaTile({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final List<Pista> pistas =
        ref.watch(pistasDePlaylistProvider(playlist.id)).value ??
            const <Pista>[];
    final Set<int> completas = ref.watch(pistasCompletasProvider);
    final int total = pistas.length;
    final int hechas =
        pistas.where((Pista p) => completas.contains(p.id)).length;
    final bool listo = total > 0 && hechas >= total;

    return ListTile(
      leading: Icon(
        listo ? AppIcons.downloadDone : AppIcons.downloading,
        color: c.accent,
      ),
      title: Text(
        playlist.nombre,
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
        listo ? '$total pistas · al día' : 'Descargando · $hechas/$total',
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 12.5,
          color: c.text2,
        ),
      ),
    );
  }
}

class _SeccionTitulo extends StatelessWidget {
  const _SeccionTitulo(this.texto);
  final String texto;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: c.text3,
        ),
      ),
    );
  }
}

/// Contador en vivo del lote de descargas: cuántas van, cuántas faltan, barra
/// de progreso global y ETA estimada. Visible mientras hay pistas en cola.
class _DownloadCounter extends StatelessWidget {
  const _DownloadCounter({required this.queue});

  final DownloadQueueState queue;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final Duration? eta = queue.eta;
    final String faltan = queue.restantes == 1
        ? 'Falta 1 pista'
        : 'Faltan ${queue.restantes} pistas';
    final String detalle =
        eta != null ? '$faltan · ~${_formatEta(eta)}' : faltan;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.line2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(AppIcons.downloading, color: c.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Descargando',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                Text(
                  '${queue.completados}/${queue.totalLote}',
                  style: TextStyle(
                    fontFamily: NbFonts.ui,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: queue.progresoLote,
                minHeight: 6,
                backgroundColor: c.line2,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detalle,
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12.5,
                color: c.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Formato compacto de la ETA: "45 s", "3 min", "1 h 5 min".
  static String _formatEta(Duration d) {
    if (d.inSeconds < 60) {
      final int s = d.inSeconds;
      return s <= 1 ? '1 s' : '$s s';
    }
    if (d.inMinutes < 60) {
      return '${d.inMinutes} min';
    }
    final int h = d.inHours;
    final int m = d.inMinutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
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
      DownloadEstado.done => (
          AppIcons.downloadDone,
          c.accent,
          _etiquetaDone(descarga),
        ),
      DownloadEstado.downloading => (
          AppIcons.downloading,
          c.accent,
          progreso != null
              ? 'Descargando ${(progreso! * 100).round()}%'
              : 'Descargando…',
        ),
      DownloadEstado.failed => (AppIcons.close, const Color(0xFFFF6B6B), 'Falló'),
      DownloadEstado.unavailable => (
          AppIcons.close,
          c.text3,
          'No disponible en el PC',
        ),
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

  /// Etiqueta del estado `done` enriquecida con karaoke y verificación de hash.
  static String _etiquetaDone(DescargaAudio d) {
    if (d.stemsEstado == DownloadEstado.done) {
      return 'Descargada · karaoke';
    }
    if (d.hashOk == false) {
      return 'Descargada · sin verificar';
    }
    return 'Descargada';
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
