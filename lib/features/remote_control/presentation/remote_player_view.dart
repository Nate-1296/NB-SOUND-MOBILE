import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/duration_format.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/cover.dart';
import '../../offline/application/image_resolver.dart';
import '../application/remote_controller.dart';
import '../data/remote_dtos.dart';
import 'destination_sheet.dart';

/// Reproductor en modo "Mi PC": refleja el estado del PC y envía comandos.
class RemotePlayerView extends ConsumerWidget {
  const RemotePlayerView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final RemoteState s = ref.watch(remoteControllerProvider);
    final RemoteController ctrl = ref.read(remoteControllerProvider.notifier);
    final RemotePistaDto? p = s.pista;
    // En sesión de DJ Privado el PC tiene el control global: el móvil solo informa,
    // los comandos quedan bloqueados hasta que la sesión termine.
    final bool dj = s.estado.djActivo;
    final ImageProvider? cover = ref.watch(coverResolverProvider).imageFor(
          p?.coverUrl,
          cacheWidth: coverCachePx(context, 300),
        );

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: <Widget>[
              _header(context, ref, c, s),
              if (dj) _djBanner(c),
              const Spacer(),
              Cover(
                image: cover,
                size: 300,
                radius: 22,
                overlay: cover == null
                    ? Center(
                        child: Icon(AppIcons.cast, size: 64, color: c.text3),
                      )
                    : null,
              ),
              const Spacer(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          p?.titulo.isNotEmpty == true
                              ? p!.titulo
                              : 'Nada sonando en el PC',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NbFonts.display,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          p?.artista ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: NbFonts.ui,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Los controles de transporte se bloquean durante DJ Privado.
              IgnorePointer(
                ignoring: dj,
                child: Opacity(
                  opacity: dj ? 0.4 : 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _scrubber(context, c, s, ctrl),
                      const SizedBox(height: 4),
                      _controls(c, s, ctrl),
                      const SizedBox(height: 8),
                      _volumen(c, s, ctrl),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Builder(
                    builder: (BuildContext context) {
                      // Habilitado solo si el PC tiene una pista con instrumental
                      // listo. Sin karaoke ⇒ botón atenuado y no cliqueable (el
                      // PC ignoraría el toggle de todas formas).
                      final bool karaokeOk =
                          p != null && s.estado.karaokeDisponible;
                      final Color karaokeColor = !karaokeOk
                          ? c.text3
                          : (s.estado.karaokeActivo ? c.accent : c.text2);
                      return IgnorePointer(
                        ignoring: dj,
                        child: Opacity(
                          opacity: dj ? 0.4 : 1,
                          child: TextButton.icon(
                            onPressed:
                                karaokeOk ? ctrl.alternarKaraoke : null,
                            icon: Icon(
                              AppIcons.mic,
                              size: 18,
                              color: karaokeColor,
                            ),
                            label: Text(
                              'Karaoke',
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontWeight: FontWeight.w600,
                                color: karaokeColor,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  TextButton.icon(
                    onPressed: () {
                      ctrl.pedirCola();
                      _mostrarCola(context, ref, dj);
                    },
                    icon: Icon(AppIcons.queue, size: 18, color: c.text2),
                    label: Text(
                      'Cola del PC',
                      style: TextStyle(
                        fontFamily: NbFonts.ui,
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    WidgetRef ref,
    NbColors c,
    RemoteState s,
  ) {
    final String estadoConn = switch (s.connection) {
      RemoteConnection.connected => 'MI PC',
      RemoteConnection.connecting => 'CONECTANDO…',
      RemoteConnection.error => 'SIN CONEXIÓN',
      RemoteConnection.disconnected => 'DESCONECTADO',
    };
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: Icon(AppIcons.chevronDown, color: c.text, size: 26),
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              Text(
                'REPRODUCIENDO EN',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: c.text3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                estadoConn,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: s.conectado ? c.accent : c.text2,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => mostrarSelectorDestino(context, ref),
          icon: Icon(AppIcons.cast, color: c.accent, size: 24),
        ),
      ],
    );
  }

  Widget _djBanner(NbColors c) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: <Widget>[
          Icon(AppIcons.mic, size: 18, color: c.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'DJ Privado en sesión — el PC tiene el control. Volverá al terminar '
              'la sesión.',
              style: TextStyle(
                fontFamily: NbFonts.ui,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrubber(
    BuildContext context,
    NbColors c,
    RemoteState s,
    RemoteController ctrl,
  ) {
    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: c.accent,
            inactiveTrackColor: c.line2,
            thumbColor: c.accent,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: s.progress,
            onChanged: (_) {},
            onChangeEnd: ctrl.buscarProgreso,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(formatClock(s.estado.posicionSeg), style: _t(c)),
              Text(formatClock(s.estado.pista?.duracionSeg ?? 0), style: _t(c)),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _t(NbColors c) => TextStyle(
        fontFamily: NbFonts.ui,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: c.text3,
      );

  Widget _controls(NbColors c, RemoteState s, RemoteController ctrl) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          onPressed: () => ctrl.setAleatorio(!s.estado.aleatorio),
          icon: Icon(
            AppIcons.shuffle,
            color: s.estado.aleatorio ? c.accent : c.text2,
            size: 22,
          ),
        ),
        IconButton(
          onPressed: ctrl.anterior,
          icon: Icon(AppIcons.prev, color: c.text, size: 32),
        ),
        GestureDetector(
          onTap: ctrl.playPause,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: c.accent,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(color: c.ambient, blurRadius: 30, spreadRadius: 2),
              ],
            ),
            child: Icon(
              s.estado.reproduciendo ? AppIcons.pause : AppIcons.play,
              color: c.ink,
              size: 34,
            ),
          ),
        ),
        IconButton(
          onPressed: ctrl.siguiente,
          icon: Icon(AppIcons.next, color: c.text, size: 32),
        ),
        IconButton(
          onPressed: ctrl.cicloRepeticion,
          icon: Icon(
            s.estado.modoRepeticion == ModoRepeticionPc.uno
                ? AppIcons.repeatOne
                : AppIcons.repeat,
            color: s.estado.modoRepeticion == ModoRepeticionPc.ninguno
                ? c.text2
                : c.accent,
            size: 22,
          ),
        ),
      ],
    );
  }

  Widget _volumen(NbColors c, RemoteState s, RemoteController ctrl) {
    return Row(
      children: <Widget>[
        Icon(AppIcons.volume, size: 18, color: c.text2),
        Expanded(
          child: Slider(
            value: (s.estado.volumen / 100).clamp(0.0, 1.0),
            activeColor: c.accent,
            inactiveColor: c.line2,
            onChanged: (_) {},
            onChangeEnd: (double v) => ctrl.setVolumen((v * 100).round()),
          ),
        ),
        Text('${s.estado.volumen}', style: _t(c)),
      ],
    );
  }

  void _mostrarCola(BuildContext context, WidgetRef ref, bool dj) {
    final NbColors c = context.nb;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.bg2,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        return Consumer(
          builder: (BuildContext ctx, WidgetRef r, _) {
            final RemoteState s = r.watch(remoteControllerProvider);
            final RemoteController ctrl =
                r.read(remoteControllerProvider.notifier);
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // Cabecera: "Cola del PC" + vaciar (bloqueado en DJ).
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            'Cola del PC',
                            style: TextStyle(
                              fontFamily: NbFonts.display,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                        if (s.cola.length > 1 && !dj)
                          TextButton.icon(
                            onPressed: ctrl.vaciarCola,
                            icon: Icon(AppIcons.trash, size: 16, color: c.text2),
                            label: Text(
                              'Vaciar',
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontWeight: FontWeight.w600,
                                color: c.text2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (s.cola.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Cola vacía o no disponible.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: NbFonts.ui, color: c.text3),
                      ),
                    )
                  else
                    Flexible(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        buildDefaultDragHandles: !dj,
                        itemCount: s.cola.length,
                        // `onReorderItem` ya entrega el índice destino ajustado.
                        onReorderItem: (int oldIndex, int newIndex) {
                          if (!dj && newIndex != oldIndex) {
                            ctrl.moverEnCola(oldIndex, newIndex);
                          }
                        },
                        itemBuilder: (BuildContext ctx, int i) {
                          final RemotePistaDto it = s.cola[i];
                          final bool actual = i == s.estado.indiceCola;
                          return ListTile(
                            key: ValueKey<int>(
                                it.id != 0 ? it.id : i.hashCode ^ it.titulo.hashCode),
                            dense: true,
                            onTap: dj ? null : () => ctrl.reproducirIndice(i),
                            title: Text(
                              it.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                fontWeight: FontWeight.w600,
                                color: actual ? c.accent : c.text,
                              ),
                            ),
                            subtitle: Text(
                              it.artista,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: NbFonts.ui,
                                color: c.text2,
                              ),
                            ),
                            // No se quita la pista en curso (igual que en local).
                            trailing: (actual || dj)
                                ? null
                                : IconButton(
                                    icon: Icon(AppIcons.close,
                                        size: 18, color: c.text3),
                                    onPressed: () => ctrl.quitarDeCola(i),
                                  ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
