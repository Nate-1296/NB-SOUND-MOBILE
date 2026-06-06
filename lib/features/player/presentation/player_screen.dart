import 'dart:ui';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/db/database.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/util/media_source.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/chip_pill.dart';
import '../../../shared/widgets/cover.dart';
import '../../karaoke/application/karaoke_providers.dart';
import '../../library/application/library_providers.dart';
import '../../lyrics/application/lyrics_providers.dart';
import '../../lyrics/data/lyrics_models.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/data/download_repository.dart';
import '../../remote_control/presentation/destination_sheet.dart';
import '../../remote_control/presentation/remote_player_view.dart';
import '../../sync/application/remote_media_provider.dart';
import '../application/playback.dart';
import '../application/player_controller.dart';

enum _View { portada, letra, cola }

/// Reproductor a pantalla completa con vistas Portada / Letra / Cola.
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  _View _view = _View.portada;
  double? _seekDrag;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;

    // En modo "Mi PC" el reproductor controla al PC (misma entrada, otra fuente).
    if (ref.watch(playbackTargetProvider) == PlaybackTarget.remote) {
      return const RemotePlayerView();
    }

    final PlayerState player = ref.watch(playerControllerProvider);
    final Pista? pista = player.current;

    if (pista == null) {
      return Scaffold(
        backgroundColor: c.bg,
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Nada en reproducción'),
          ),
        ),
      );
    }

    final ImageProvider? cover =
        coverImage(pista.coverPath, ref.watch(remoteMediaProvider));
    final Set<int> favoritas =
        ref.watch(favoritasIdsProvider).value ?? const <int>{};
    final bool esFav = favoritas.contains(pista.id);

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          _Ambient(cover: cover),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: <Widget>[
                  _header(c, pista),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        for (final (_View v, String l) tab in const <(
                          _View,
                          String
                        )>[
                          (_View.portada, 'Portada'),
                          (_View.letra, 'Letra'),
                          (_View.cola, 'Cola'),
                        ]) ...<Widget>[
                          ChipPill(
                            label: tab.$2,
                            active: _view == tab.$1,
                            onTap: () => setState(() => _view = tab.$1),
                          ),
                          const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ),
                  Expanded(child: _central(c, pista, cover, player)),
                  _meta(c, pista, esFav),
                  _scrubber(c, player),
                  const SizedBox(height: 8),
                  _controls(c, player),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(NbColors c, Pista pista) {
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
                'REPRODUCIENDO DESDE',
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
                pista.albumTitulo ?? 'Tu biblioteca',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: c.text,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => mostrarSelectorDestino(context, ref),
          icon: Icon(AppIcons.cast, color: c.text, size: 22),
        ),
      ],
    );
  }

  Widget _central(
    NbColors c,
    Pista pista,
    ImageProvider? cover,
    PlayerState player,
  ) {
    switch (_view) {
      case _View.portada:
        return Center(
          child: Cover(image: cover, size: 320, radius: 22),
        );
      case _View.letra:
        return _Letra(pistaId: pista.id);
      case _View.cola:
        return _Cola(player: player);
    }
  }

  Widget _meta(NbColors c, Pista pista, bool esFav) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                pista.titulo,
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
                pista.artistaNombre,
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
        _DownloadButton(pistaId: pista.id),
        _KaraokeIconButton(pistaId: pista.id),
        IconButton(
          onPressed: () =>
              ref.read(favoritesDaoProvider).setFavorita(pista.id, !esFav),
          icon: Icon(
            esFav ? AppIcons.heartFilled : AppIcons.heart,
            color: esFav ? c.accent : c.text2,
            size: 26,
          ),
        ),
      ],
    );
  }

  Widget _scrubber(NbColors c, PlayerState player) {
    final double value = _seekDrag ?? player.progress;
    return Column(
      children: <Widget>[
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            activeTrackColor: c.accent,
            inactiveTrackColor: c.line2,
            thumbColor: c.accent,
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.clamp(0.0, 1.0),
            onChanged: (double v) => setState(() => _seekDrag = v),
            onChangeEnd: (double v) {
              ref.read(playerControllerProvider.notifier).buscar(v);
              setState(() => _seekDrag = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                formatClock(player.position.inSeconds),
                style: _timeStyle(c),
              ),
              Text(
                formatClock(player.duration.inSeconds),
                style: _timeStyle(c),
              ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle _timeStyle(NbColors c) => TextStyle(
        fontFamily: NbFonts.ui,
        fontSize: 11.5,
        fontWeight: FontWeight.w500,
        color: c.text3,
      );

  Widget _controls(NbColors c, PlayerState player) {
    final PlayerController ctrl = ref.read(playerControllerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        IconButton(
          onPressed: ctrl.alternarAleatorio,
          icon: Icon(
            AppIcons.shuffle,
            color: player.shuffle ? c.accent : c.text2,
            size: 22,
          ),
        ),
        IconButton(
          onPressed: ctrl.anterior,
          icon: Icon(AppIcons.prev, color: c.text, size: 32),
        ),
        Semantics(
          button: true,
          label: player.playing ? 'Pausar' : 'Reproducir',
          child: GestureDetector(
            onTap: ctrl.alternarReproduccion,
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
                player.playing ? AppIcons.pause : AppIcons.play,
                color: c.ink,
                size: 34,
              ),
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
            player.repeat == RepeatMode.one
                ? AppIcons.repeatOne
                : AppIcons.repeat,
            color: player.repeat == RepeatMode.off ? c.text2 : c.accent,
            size: 22,
          ),
        ),
      ],
    );
  }
}

/// Fondo ambiente con blur de la portada.
class _Ambient extends StatelessWidget {
  const _Ambient({required this.cover});
  final ImageProvider? cover;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    if (cover == null) {
      return Positioned.fill(child: ColoredBox(color: c.bg));
    }
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image(image: cover!, fit: BoxFit.cover),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    c.bg.withValues(alpha: 0.55),
                    c.bg.withValues(alpha: 0.85),
                    c.bg,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vista de letra: consume `/lyrics` (cache-first) y muestra la letra
/// sincronizada con la línea activa resaltada y auto-scroll; cae a texto plano,
/// y a estados claros cuando no hay letra o no hay PC. Incluye el toggle Karaoke.
class _Letra extends ConsumerStatefulWidget {
  const _Letra({required this.pistaId});

  final int pistaId;

  @override
  ConsumerState<_Letra> createState() => _LetraState();
}

class _LetraState extends ConsumerState<_Letra> {
  static const double _itemExtent = 50;
  final ScrollController _scroll = ScrollController();
  int _lastActive = -1;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final AsyncValue<Lyrics?> lyricsAsync =
        ref.watch(lyricsProvider(widget.pistaId));
    final Duration pos = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.position),
    );

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: lyricsAsync.when(
            loading: () =>
                Center(child: CircularProgressIndicator(color: c.accent)),
            error: (Object _, StackTrace _) =>
                _message(c, 'No se pudo cargar la letra.'),
            data: (Lyrics? lyrics) {
              if (lyrics == null) {
                return _message(
                  c,
                  'Conéctate a tu PC para ver la letra de esta pista.',
                );
              }
              if (lyrics.isEmpty) {
                return _message(c, 'Esta pista no tiene letra.');
              }
              if (lyrics.hasSynced) {
                return _synced(c, lyrics, pos);
              }
              return _plain(c, lyrics.plain);
            },
          ),
        ),
      ],
    );
  }

  Widget _synced(NbColors c, Lyrics lyrics, Duration pos) {
    final int active = lyrics.activeIndex(pos);
    if (active != _lastActive) {
      _lastActive = active;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(active));
    }
    return ListView.builder(
      controller: _scroll,
      itemExtent: _itemExtent,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      itemCount: lyrics.synced.length,
      itemBuilder: (BuildContext context, int i) {
        final bool isActive = i == active;
        return Center(
          child: Text(
            lyrics.synced[i].text.isEmpty ? '♪' : lyrics.synced[i].text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.display,
              fontSize: isActive ? 19 : 16,
              fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
              height: 1.25,
              color: isActive ? c.text : c.text3,
            ),
          ),
        );
      },
    );
  }

  void _scrollTo(int index) {
    if (index < 0 || !_scroll.hasClients) {
      return;
    }
    final double viewport = _scroll.position.viewportDimension;
    final double target = (index * _itemExtent) - (viewport / 2) + (_itemExtent / 2);
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Widget _plain(NbColors c, String plain) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Text(
        plain,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: NbFonts.ui,
          fontSize: 15.5,
          fontWeight: FontWeight.w500,
          height: 1.7,
          color: c.text2,
        ),
      ),
    );
  }

  Widget _message(NbColors c, String text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: NbFonts.display,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.5,
            color: c.text2,
          ),
        ),
      ),
    );
  }

}

/// Botón de karaoke (solo icono) para la fila de acciones del reproductor.
/// Atenuado/inhabilitado si la pista no tiene stems; acento cuando está activo.
class _KaraokeIconButton extends ConsumerWidget {
  const _KaraokeIconButton({required this.pistaId});

  final int pistaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final bool karaoke = ref
        .watch(playerControllerProvider.select((PlayerState s) => s.karaoke));
    final bool disponible =
        ref.watch(stemsDisponibleProvider(pistaId)).value ?? false;
    // Si ya está activo, siempre se puede apagar aunque el chequeo varíe.
    final bool enabled = disponible || karaoke;

    return Semantics(
      button: true,
      enabled: enabled,
      toggled: karaoke,
      label: 'Karaoke',
      child: IconButton(
        tooltip: 'Karaoke',
        onPressed: enabled
            ? () async {
                final bool ok = await ref
                    .read(playerControllerProvider.notifier)
                    .toggleKaraoke();
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Esta pista no tiene karaoke.'),
                    ),
                  );
                }
              }
            : null,
        icon: Icon(
          AppIcons.mic,
          size: 24,
          color: karaoke ? c.accent : (enabled ? c.text2 : c.text3),
        ),
      ),
    );
  }
}

/// Vista de cola: "a continuación" tras la pista en curso.
class _Cola extends ConsumerWidget {
  const _Cola({required this.player});
  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final RemoteMedia? remote = ref.watch(remoteMediaProvider);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: player.queue.length,
      itemBuilder: (BuildContext context, int i) {
        final Pista p = player.queue[i];
        final bool actual = i == player.index;
        return ListTile(
          dense: true,
          onTap: () =>
              ref.read(playerControllerProvider.notifier).irACola(i),
          leading: Cover(
            image: coverImage(p.coverPath, remote),
            size: 40,
            radius: 8,
            shadow: false,
          ),
          title: Text(
            p.titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: actual ? c.accent : c.text,
            ),
          ),
          subtitle: Text(
            p.artistaNombre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: NbFonts.ui,
              fontSize: 12,
              color: c.text2,
            ),
          ),
          trailing: actual
              ? Icon(AppIcons.volume, color: c.accent, size: 18)
              : null,
        );
      },
    );
  }
}

/// Botón de descarga en caliente del reproductor: permite guardar la pista que
/// suena en streaming. Refleja el estado (descargando/descargada) y solo aparece
/// cuando hay un PC emparejado o la pista ya está descarga (gestionable).
class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({required this.pistaId});

  final int pistaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final DescargaAudio? d = ref.watch(descargaEstadoProvider(pistaId)).value;
    final String? estado = d?.estado;

    if (estado == DownloadEstado.done) {
      return IconButton(
        tooltip: 'Descargada · quitar',
        onPressed: () =>
            ref.read(downloadQueueProvider.notifier).eliminar(pistaId),
        icon: Icon(AppIcons.downloadDone, color: c.accent, size: 24),
      );
    }
    if (estado == DownloadEstado.downloading ||
        estado == DownloadEstado.pending) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
        ),
      );
    }
    // Sin descarga: solo ofrecer descargar si hay PC emparejado.
    if (ref.watch(remoteMediaProvider) == null) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Descargar',
      onPressed: () =>
          ref.read(downloadQueueProvider.notifier).encolarPista(pistaId),
      icon: Icon(AppIcons.download, color: c.text2, size: 24),
    );
  }
}
