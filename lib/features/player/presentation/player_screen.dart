import 'dart:ui';

import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/db/database.dart';
import '../../../shared/theme/nb_colors.dart';
import '../../../shared/theme/nb_theme.dart';
import '../../../shared/util/responsive.dart';
import '../../../shared/widgets/app_icons.dart';
import '../../../shared/widgets/auto_fit_text.dart';
import '../../../shared/widgets/chip_pill.dart';
import '../../../shared/widgets/cover.dart';
import '../../karaoke/application/karaoke_providers.dart';
import '../../library/application/library_providers.dart';
import '../../library/presentation/widgets/pista_list.dart';
import '../../lyrics/application/lyrics_providers.dart';
import '../../lyrics/data/lyrics_models.dart';
import '../../offline/application/download_providers.dart';
import '../../offline/application/image_resolver.dart';
import '../../offline/data/download_repository.dart';
import '../../offline/presentation/download_actions.dart';
import '../../remote_control/presentation/destination_sheet.dart';
import '../../remote_control/presentation/remote_player_view.dart';
import '../../sync/application/conexion_provider.dart';
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

class _PlayerScreenState extends ConsumerState<PlayerScreen>
    with SingleTickerProviderStateMixin {
  _View _view = _View.portada;
  double? _seekDrag;

  /// En la vista Letra: oculta cabecera/controles para ver la letra a pantalla
  /// completa. Se entra con el pellizco (zoom) o manteniendo pulsada la letra;
  /// vuelve a false al cambiar de vista.
  bool _immersive = false;

  /// Punteros activos sobre la letra y la distancia de referencia del pellizco
  /// (gesto de 2 dedos). Se usan punteros crudos (`Listener`) para no competir en
  /// la arena de gestos con el scroll ni el cambio de vista. El pellizco SOLO
  /// entra/sale del modo inmersivo (NO agranda la letra): abrir los dedos entra a
  /// pantalla completa, cerrarlos sale — como el long-press, pero por gesto.
  final Map<int, Offset> _punteros = <int, Offset>{};
  double? _pinchBaseDist;

  void _pinchDown(PointerDownEvent e) {
    _punteros[e.pointer] = e.position;
    if (_punteros.length == 2) {
      _pinchBaseDist = _distPunteros();
    }
  }

  void _pinchMove(PointerMoveEvent e) {
    if (!_punteros.containsKey(e.pointer)) {
      return;
    }
    _punteros[e.pointer] = e.position;
    final double? base = _pinchBaseDist;
    if (_punteros.length != 2 ||
        base == null ||
        base <= 0 ||
        _view != _View.letra) {
      return;
    }
    final double ratio = _distPunteros() / base;
    // Abrir (>1.25) entra en pantalla completa; cerrar (<0.8) sale. Se re-ancla la
    // base tras cada cambio para no re-disparar dentro del mismo gesto.
    if (ratio >= 1.25 && !_immersive) {
      setState(() => _immersive = true);
      _pinchBaseDist = _distPunteros();
    } else if (ratio <= 0.8 && _immersive) {
      setState(() => _immersive = false);
      _pinchBaseDist = _distPunteros();
    }
  }

  void _pinchUp(PointerEvent e) {
    _punteros.remove(e.pointer);
    if (_punteros.length < 2) {
      _pinchBaseDist = null;
    }
  }

  double _distPunteros() {
    final List<Offset> p = _punteros.values.toList();
    return p.length < 2 ? 0 : (p[0] - p[1]).distance;
  }

  /// Desplazamiento vertical del gesto de cerrar (arrastrar hacia abajo): el
  /// reproductor sigue al dedo y solo se cierra si se suelta pasado el umbral;
  /// si no, vuelve a su sitio con animación (estilo Apple/Spotify).
  double _dragY = 0;
  double _dragDesde = 0;
  late final AnimationController _snap = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..addListener(() {
      setState(() => _dragY = _dragDesde * (1 - _snap.value));
    });

  /// Umbral (px) para cerrar al soltar; por debajo, vuelve arriba.
  static const double _umbralCierre = 120;

  @override
  void dispose() {
    _snap.dispose();
    super.dispose();
  }

  void _cerrar() => Navigator.of(context).maybePop();

  void _onVDragUpdate(DragUpdateDetails d) {
    if (_snap.isAnimating) {
      _snap.stop();
    }
    setState(() => _dragY = (_dragY + d.delta.dy).clamp(0.0, 10000.0));
  }

  void _onVDragEnd(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    if (_dragY > _umbralCierre || v > 700) {
      _cerrar();
      return;
    }
    // Vuelve arriba con animación.
    _dragDesde = _dragY;
    _snap.forward(from: 0);
  }

  /// Cambia entre vistas (Portada ↔ Letra ↔ Cola) al deslizar en horizontal,
  /// sin cambiar de canción. Avanza/retrocede una vista; no da la vuelta.
  void _cambiarVista(DragEndDetails d) {
    final double v = d.primaryVelocity ?? 0;
    if (v.abs() < 200) {
      return;
    }
    const List<_View> orden = _View.values;
    final int i = orden.indexOf(_view);
    final int next = (v < 0 ? i + 1 : i - 1).clamp(0, orden.length - 1);
    if (next != i) {
      setState(() {
        _view = orden[next];
        _immersive = false;
      });
    }
  }

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

    final ImageProvider? cover = ref
        .watch(coverResolverProvider)
        .imageFor(
          pista.coverPath,
          cacheWidth: coverCachePx(context, MediaQuery.sizeOf(context).width),
        );
    final Set<int> favoritas =
        ref.watch(favoritasIdsProvider).value ?? const <int>{};
    final bool esFav = favoritas.contains(pista.id);

    // Letra a pantalla completa: oculta cabecera, pestañas y controles.
    final bool immersive = _view == _View.letra && _immersive;

    return Scaffold(
      backgroundColor: c.bg,
      body: Stack(
        children: <Widget>[
          _Ambient(cover: cover),
          Transform.translate(
            offset: Offset(0, _dragY),
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: <Widget>[
                  if (!immersive) ...<Widget>[
                    _header(c, pista),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          for (final (_View v, String l) tab
                              in const <(_View, String)>[
                                (_View.portada, 'Portada'),
                                (_View.letra, 'Letra'),
                                (_View.cola, 'Cola'),
                              ]) ...<Widget>[
                            ChipPill(
                              label: tab.$2,
                              active: _view == tab.$1,
                              onTap: () => setState(() {
                                _view = tab.$1;
                                _immersive = false;
                              }),
                            ),
                            const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ),
                  ],
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      // Deslizar en horizontal cambia de vista (Portada/Letra/
                      // Cola), no de canción.
                      onHorizontalDragEnd: _cambiarVista,
                      child: _central(pista, cover, player),
                    ),
                  ),
                  if (!immersive) ...<Widget>[
                    _meta(c, pista, esFav),
                    _scrubber(c, player),
                    const SizedBox(height: 8),
                    _controls(c, player),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }

  /// Cierra el reproductor y navega a [ruta] (álbum/artista). Se captura el router
  /// antes del pop para no usar un `context` desmontado.
  void _irA(String ruta) {
    final GoRouter router = GoRouter.of(context);
    Navigator.of(context).maybePop();
    router.push(ruta);
  }

  Widget _header(NbColors c, Pista pista) {
    final Widget contexto = Column(
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
        AutoFitText(
          pista.albumTitulo ?? 'Tu biblioteca',
          textAlign: TextAlign.center,
          maxLines: 2,
          minFontSize: 10.5,
          style: TextStyle(
            fontFamily: NbFonts.ui,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.text,
          ),
        ),
      ],
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onVDragUpdate,
      onVerticalDragEnd: _onVDragEnd,
      child: Row(
        children: <Widget>[
          IconButton(
            onPressed: _cerrar,
            icon: Icon(AppIcons.chevronDown, color: c.text, size: 26),
          ),
          Expanded(
            // Tocar "Reproduciendo desde [álbum]" abre el álbum (como Spotify).
            child: pista.albumId == null
                ? contexto
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _irA('/album/${pista.albumId}'),
                    child: contexto,
                  ),
          ),
          // "Reproducir en Mi PC" solo tiene sentido con un PC conectado.
          if (ref.watch(conexionPcProvider) == ConexionEstado.conectado)
            IconButton(
              onPressed: () => mostrarSelectorDestino(context, ref),
              icon: Icon(AppIcons.cast, color: c.text, size: 22),
            ),
          IconButton(
            tooltip: 'Más opciones',
            onPressed: () =>
                mostrarMenuPista(context, ref, pista, ajustesReproductor: true),
            icon: Icon(AppIcons.moreV, color: c.text, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _central(
    Pista pista,
    ImageProvider? cover,
    PlayerState player,
  ) {
    switch (_view) {
      case _View.portada:
        // En tablet/Chromebook la portada es mayor (aprovecha el alto disponible),
        // acotada para no desbordar pantallas estrechas en vertical.
        final double lado = (320 * context.cardScale).clamp(
          280.0,
          MediaQuery.sizeOf(context).height * 0.46,
        );
        // Arrastra la portada hacia abajo para cerrar (sigue al dedo; se cierra al
        // soltar pasado el umbral, si no vuelve arriba).
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: _onVDragUpdate,
          onVerticalDragEnd: _onVDragEnd,
          child: Center(
            child: Cover(
              image: cover,
              size: lado,
              radius: 22,
              kind: CoverKind.track,
              coverSeed: pista.id,
              animatedPlaceholder: true,
            ),
          ),
        );
      case _View.letra:
        // Pellizca con dos dedos sobre la letra para agrandarla (y entrar en modo
        // inmersivo a pantalla completa); pellizca hacia dentro para reducir y
        // salir. Sustituye al antiguo botón de pantalla completa por un gesto, en
        // continuidad con el resto de la UI. Mantener pulsada la letra también
        // alterna el modo inmersivo; un toque sobre una línea salta a ese momento.
        // Listener (no GestureDetector) para no robar el scroll vertical ni el
        // deslizamiento horizontal entre vistas: solo lee punteros para el pinch.
        return Listener(
          onPointerDown: _pinchDown,
          onPointerMove: _pinchMove,
          onPointerUp: _pinchUp,
          onPointerCancel: _pinchUp,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => setState(() => _immersive = !_immersive),
            child: _Letra(pistaId: pista.id),
          ),
        );
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
              // Título completo sin recorte (auto-ajusta y, si hace falta, 2 líneas).
              AutoFitText(
                pista.titulo,
                maxLines: 2,
                minFontSize: 16,
                style: TextStyle(
                  fontFamily: NbFonts.display,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.12,
                  color: c.text,
                ),
              ),
              const SizedBox(height: 3),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: pista.artistaId == null
                    ? null
                    : () => _irA('/artist/${pista.artistaId}'),
                child: Text(
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
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // Acciones compactas (más pequeñas que el resto de la fila).
        _DownloadButton(pistaId: pista.id),
        _KaraokeIconButton(pistaId: pista.id),
        IconButton(
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: () =>
              ref.read(favoritesDaoProvider).setFavorita(pista.id, !esFav),
          icon: Icon(
            esFav ? AppIcons.heartFilled : AppIcons.heart,
            color: esFav ? c.accent : c.text2,
            size: 21,
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
  /// Alto de cada línea de letra. Se recalcula por build según el ancho de
  /// pantalla (en tablet/Chromebook la letra es mucho más grande, lo pidió el
  /// usuario); `_scrollTo` lo usa para centrar la línea activa.
  double _itemExtent = 58;
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
    final AsyncValue<Lyrics?> lyricsAsync = ref.watch(
      lyricsProvider(widget.pistaId),
    );
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
              if (lyrics.hasSynced) {
                return _synced(c, lyrics, pos);
              }
              // Solo se muestra la letra sincronizada (con auto-scroll). La letra
              // plana se descarga y conserva en disco, pero no se muestra: igual
              // que el PC, sin marcas de tiempo no hay experiencia de karaoke.
              return _message(
                c,
                '¡Lo sentimos! No encontramos la letra de esta canción.',
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _synced(NbColors c, Lyrics lyrics, Duration pos) {
    // Escala de letra por tamaño de pantalla (en grande, mucho mayor).
    final double escala = switch (context.bp) {
      Bp.compact => 1.0,
      Bp.medium => 1.5,
      Bp.expanded => 2.0,
    };
    _itemExtent = 58 * escala;
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
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Toca una línea para saltar a ese momento de la canción.
          onTap: () => ref
              .read(playerControllerProvider.notifier)
              .buscarPosicion(lyrics.synced[i].time),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              // AutoFitText: la línea (incluida la activa en negrita) siempre se ve
              // completa, ocupando más ancho y reduciéndose si hace falta, sin pasar
              // a recorte ni desaparecer.
              child: AutoFitText(
                lyrics.synced[i].text.isEmpty ? '♪' : lyrics.synced[i].text,
                textAlign: TextAlign.center,
                maxLines: 2,
                minFontSize: 13 * escala,
                style: TextStyle(
                  fontFamily: NbFonts.display,
                  fontSize: (isActive ? 20 : 16) * escala,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  height: 1.2,
                  color: isActive ? c.text : c.text3,
                ),
              ),
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
    final double target =
        (index * _itemExtent) - (viewport / 2) + (_itemExtent / 2);
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
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
    final bool karaoke = ref.watch(
      playerControllerProvider.select((PlayerState s) => s.karaoke),
    );
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
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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
          size: 20,
          color: karaoke ? c.accent : (enabled ? c.text2 : c.text3),
        ),
      ),
    );
  }
}

/// Vista de cola: la lista de reproducción actual. Con aleatorio apagado se puede
/// **reordenar** (arrastrar) y **quitar** pistas; con aleatorio activo se muestra
/// el orden barajado real (sin reordenar, pero sí saltar/quitar). Tocar una fila
/// salta a esa pista.
class _Cola extends ConsumerWidget {
  const _Cola({required this.player});
  final PlayerState player;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final NbColors c = context.nb;
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    final int px = coverCachePx(context, 40);
    final PlayerController ctrl = ref.read(playerControllerProvider.notifier);

    // Con aleatorio activo: orden efectivo, sin reordenar (just_audio no expone
    // reordenar la baraja). Se conserva saltar y quitar (mapeando al índice real).
    final Widget lista;
    if (player.shuffle) {
      final List<int> orden = ordenEfectivo(player.order, player.queue.length);
      lista = ListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        itemCount: orden.length,
        itemBuilder: (BuildContext context, int i) {
          final int origIdx = orden[i];
          return _colaTile(
            context,
            ctrl,
            resolver,
            px,
            pista: player.queue[origIdx],
            actual: origIdx == player.index,
            onTap: () => ctrl.irACola(origIdx),
            onRemove: () => ctrl.quitarDeCola(origIdx),
          );
        },
      );
    } else {
      // Sin aleatorio: orden natural, reordenable por arrastre.
      lista = ReorderableListView.builder(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        buildDefaultDragHandles: false,
        itemCount: player.queue.length,
        onReorderItem: ctrl.moverEnCola,
        itemBuilder: (BuildContext context, int i) {
          return _colaTile(
            context,
            ctrl,
            resolver,
            px,
            key: ValueKey<int>(i),
            pista: player.queue[i],
            actual: i == player.index,
            onTap: () => ctrl.irACola(i),
            onRemove: () => ctrl.quitarDeCola(i),
            dragIndex: i,
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 4, 0),
          child: Row(
            children: <Widget>[
              Text(
                'EN COLA',
                style: TextStyle(
                  fontFamily: NbFonts.ui,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: c.text3,
                ),
              ),
              const Spacer(),
              if (player.queue.length > 1)
                TextButton(
                  onPressed: ctrl.limpiarCola,
                  child: Text(
                    'Borrar cola',
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
        Expanded(child: lista),
      ],
    );
  }

  /// Fila de cola reutilizable. Si [dragIndex] no es null, muestra el asa de
  /// arrastre. La pista en curso no se puede quitar (se marca con el icono de
  /// volumen).
  Widget _colaTile(
    BuildContext context,
    PlayerController ctrl,
    CoverResolver resolver,
    int px, {
    Key? key,
    required Pista pista,
    required bool actual,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    int? dragIndex,
  }) {
    final NbColors c = context.nb;
    return ListTile(
      key: key,
      dense: true,
      onTap: onTap,
      leading: Cover(
        image: resolver.imageFor(pista.coverPath, cacheWidth: px),
        size: 40,
        radius: 8,
        shadow: false,
        kind: CoverKind.track,
        coverSeed: pista.id,
      ),
      title: Text(
        pista.titulo,
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
        pista.artistaNombre,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontFamily: NbFonts.ui, fontSize: 12, color: c.text2),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (actual)
            Icon(AppIcons.volume, color: c.accent, size: 18)
          else
            IconButton(
              tooltip: 'Quitar de la cola',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: Icon(AppIcons.close, size: 18, color: c.text3),
            ),
          if (dragIndex != null)
            ReorderableDragStartListener(
              index: dragIndex,
              child: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Icon(AppIcons.dragHandle, size: 20, color: c.text3),
              ),
            ),
        ],
      ),
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

    const BoxConstraints compact = BoxConstraints(minWidth: 40, minHeight: 40);
    if (estado == DownloadEstado.done) {
      return IconButton(
        tooltip: 'Descargada · quitar',
        visualDensity: VisualDensity.compact,
        constraints: compact,
        onPressed: () =>
            ref.read(downloadQueueProvider.notifier).eliminar(pistaId),
        icon: Icon(AppIcons.downloadDone, color: c.accent, size: 20),
      );
    }
    if (estado == DownloadEstado.downloading ||
        estado == DownloadEstado.pending) {
      return Padding(
        padding: const EdgeInsets.all(11),
        child: SizedBox(
          width: 18,
          height: 18,
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
      visualDensity: VisualDensity.compact,
      constraints: compact,
      // El audio se baja en streaming desde el PC: sin PC/conexión se avisa en
      // vez de encolar en silencio (criterio unificado con el resto de la app).
      onPressed: () => encolarConAviso(
        context,
        ref,
        () =>
            ref.read(downloadQueueProvider.notifier).encolarPista(pistaId),
      ),
      icon: Icon(AppIcons.download, color: c.text2, size: 20),
    );
  }
}
