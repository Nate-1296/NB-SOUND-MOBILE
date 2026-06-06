import 'package:flutter/material.dart';

import '../theme/nb_colors.dart';

/// Portada cuadrada: imagen (asset/red/archivo) o degradado de respaldo.
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
  });

  /// Fuente de imagen. La decide el llamador (AssetImage, NetworkImage,
  /// FileImage) para no acoplar el widget a la capa de datos.
  final ImageProvider? image;

  /// Degradado de respaldo cuando no hay imagen.
  final Gradient? gradient;

  final double size;
  final double radius;
  final bool shadow;

  /// Contenido superpuesto opcional (insignias, controles).
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final NbColors c = context.nb;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.bg3,
        gradient: image == null ? gradient : null,
        borderRadius: BorderRadius.circular(radius),
        image: image != null
            ? DecorationImage(image: image!, fit: BoxFit.cover)
            : null,
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
      child: overlay,
    );
  }
}

/// Mosaico 2×2 para playlists. Espejo de `Mosaic` del diseño.
class CoverMosaic extends StatelessWidget {
  const CoverMosaic({
    super.key,
    required this.images,
    required this.size,
    this.radius = 12,
  });

  final List<ImageProvider> images;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final List<ImageProvider> tiles = images.take(4).toList();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: GridView.count(
        crossAxisCount: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: <Widget>[
          for (final ImageProvider img in tiles)
            Image(image: img, fit: BoxFit.cover),
        ],
      ),
    );
  }
}
