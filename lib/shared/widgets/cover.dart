import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';
import 'cover_placeholder.dart';

export 'cover_placeholder.dart' show CoverKind, CoverTile, CoverImageTile, CoverFallbackTile;

/// Portada cuadrada: imagen (asset/red/archivo) o respaldo. Cuando no hay
/// imagen y se indica un [kind], dibuja un [CoverPlaceholder] tipado
/// (disco/persona/nota/lista) en vez de un cuadrado gris; si además se pasa un
/// [gradient] explícito, ese tiene prioridad (respaldo plano clásico).
/// Espejo del componente `Cover` del diseño.
class Cover extends StatelessWidget {
  const Cover({
    super.key,
    this.image,
    this.gradient,
    required this.size,
    this.radius = 12,
    this.shadow = true,
    this.overlay,
    this.kind,
    this.coverSeed,
    this.animatedPlaceholder = false,
  });

  /// Fuente de imagen. La decide el llamador (AssetImage, NetworkImage,
  /// FileImage) para no acoplar el widget a la capa de datos.
  final ImageProvider? image;

  /// Degradado de respaldo explícito cuando no hay imagen (tiene prioridad sobre
  /// el placeholder tipado).
  final Gradient? gradient;

  final double size;
  final double radius;
  final bool shadow;

  /// Contenido superpuesto opcional (insignias, controles). Si se provee, ocupa
  /// el lugar del placeholder tipado.
  final Widget? overlay;

  /// Tipo de contenido para el respaldo cuando no hay [image] ni [gradient].
  final CoverKind? kind;

  /// Semilla estable (id/título) para variar el degradado del placeholder.
  final Object? coverSeed;

  /// Anima el placeholder. Usar solo en placeholders únicos visibles
  /// (reproductor, mini-reproductor, héroes de detalle).
  final bool animatedPlaceholder;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final bool hasImage = image != null;
    // Respaldo a mostrar cuando NO hay imagen o cuando la imagen falla al cargar
    // (p. ej. un /asset/cover/{id} que el PC responde 404 porque el álbum no
    // tiene portada): se usa tanto en el caso sin imagen como en el errorBuilder,
    // así nunca queda un cuadrado gris vacío.
    final Widget? fallback = _fallback();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.bg3,
        gradient: hasImage ? null : gradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image(
              image: image!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // La imagen 404/rota cae al respaldo tipado en vez de quedar gris.
              errorBuilder: (BuildContext ctx, Object e, StackTrace? s) =>
                  fallback ?? const SizedBox.shrink(),
            )
          : fallback,
    );
  }

  /// Respaldo: overlay explícito > placeholder tipado (si hay [kind] y no hay
  /// [gradient]) > nada (deja ver el [gradient]/color de fondo).
  Widget? _fallback() {
    if (overlay != null) {
      return overlay;
    }
    if (kind != null && gradient == null) {
      return CoverPlaceholder(
        kind: kind!,
        seed: coverSeed,
        animated: animatedPlaceholder,
      );
    }
    return null;
  }
}

/// Avatar circular (artista): imagen o respaldo tipado (degradado de marca +
/// icono de persona). Unifica los círculos de artista de carruseles, filas y
/// héroes para que la foto faltante muestre siempre el mismo respaldo.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    super.key,
    this.image,
    this.size,
    this.seed,
    this.shadow = false,
    this.animated = false,
    this.iconSizeFactor = 0.4,
  });

  final ImageProvider? image;

  /// Lado del círculo; si es null, llena las restricciones del padre (p. ej.
  /// dentro de un `AspectRatio`/`Expanded`).
  final double? size;
  final Object? seed;
  final bool shadow;

  /// Anima el respaldo (respiración). Solo para héroes únicos.
  final bool animated;
  final double iconSizeFactor;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    final bool hasImage = image != null;
    final Widget respaldo = LayoutBuilder(
      builder: (BuildContext ctx, BoxConstraints cons) {
        final double dim = math.min(
          cons.maxWidth.isFinite ? cons.maxWidth : (size ?? 64),
          cons.maxHeight.isFinite ? cons.maxHeight : (size ?? 64),
        );
        final double iconSize = (dim * iconSizeFactor).clamp(14.0, 120.0);
        final Widget icon = Icon(
          iconForCoverKind(CoverKind.artist),
          size: iconSize,
          color: c.text3,
        );
        return Center(child: animated ? Breathing(child: icon) : icon);
      },
    );
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.bg3,
        shape: BoxShape.circle,
        gradient: coverPlaceholderGradient(c, seed),
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      // La foto 404/rota deja ver el respaldo (icono de persona), no un círculo gris.
      child: hasImage
          ? Image(
              image: image!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (BuildContext ctx, Object e, StackTrace? s) =>
                  respaldo,
            )
          : respaldo,
    );
  }
}

/// Mosaico 2×2 para playlists. Cada celda es una imagen real o un respaldo
/// tipado (pista sin carátula). Espejo de `Mosaic` del diseño.
class CoverMosaic extends StatelessWidget {
  const CoverMosaic({
    super.key,
    required this.tiles,
    required this.size,
    this.radius = 12,
    this.shadow = true,
  });

  final List<CoverTile> tiles;
  final double size;
  final double radius;

  /// Sombra de elevación. Se desactiva cuando el mosaico va como miniatura
  /// plana dentro de otra tarjeta (p. ej. los accesos rápidos del Inicio).
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final List<CoverTile> cells = tiles.take(4).toList();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow
            ? const <BoxShadow>[
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          for (final CoverTile tile in cells)
            switch (tile) {
              // La celda con imagen 404/rota cae al respaldo de pista (no queda
              // un hueco vacío en el mosaico).
              CoverImageTile(:final ImageProvider image) => Image(
                  image: image,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (BuildContext ctx, Object e, StackTrace? s) =>
                      const CoverPlaceholder(kind: CoverKind.track),
                ),
              CoverFallbackTile(:final CoverKind kind, :final Object? seed) =>
                CoverPlaceholder(kind: kind, seed: seed),
            },
        ],
      ),
    );
  }
}
