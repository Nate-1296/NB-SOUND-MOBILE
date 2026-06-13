import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/db/database.dart';
import '../../../../shared/widgets/cover.dart';
import '../../../offline/application/image_resolver.dart';
import '../../application/playlist_cover_prefetch.dart';
import '../../application/playlist_covers.dart';

/// Portada de una playlist a partir de sus [pistas]: decide entre mosaico 2×2,
/// portada única o placeholder de playlist, reflejando las pistas sin carátula
/// como respaldos tipados dentro del mosaico. Centraliza la lógica que antes
/// duplicaban tarjetas/filas/detalles/inicio.
///
/// Resuelve solo las ≤4 imágenes necesarias (vía [slotsPortadaPlaylist]) y las
/// materializa a disco (prefetch) para aperturas posteriores instantáneas.
class PlaylistArt extends ConsumerWidget {
  const PlaylistArt({
    super.key,
    required this.pistas,
    required this.size,
    this.radius = 14,
    this.shadow = true,
    this.seed,
    this.cacheSize,
  });

  final List<Pista> pistas;

  /// Lado de la portada (puede ser `double.infinity` dentro de un `AspectRatio`).
  final double size;
  final double radius;
  final bool shadow;

  /// Semilla del placeholder de playlist (id de la playlist).
  final Object? seed;

  /// Tamaño lógico para calcular los píxeles de caché cuando [size] no es finito.
  final double? cacheSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CoverResolver resolver = ref.watch(coverResolverProvider);
    // Materializa a disco las portadas distintas para que la próxima apertura
    // sea instantánea (no bloquea: encola en segundo plano).
    ref.read(playlistCoverPrefetcherProvider).asegurarParaPistas(pistas);

    final double logico = cacheSize ?? (size.isFinite ? size : 220);
    final int px = coverCachePx(context, logico);
    final List<String?> slots = slotsPortadaPlaylist(pistas);

    if (slots.isEmpty) {
      return Cover(
        size: size,
        radius: radius,
        shadow: shadow,
        kind: CoverKind.playlist,
        coverSeed: seed,
      );
    }

    final List<CoverTile> tiles = <CoverTile>[];
    for (final String? path in slots) {
      final ImageProvider? img =
          path == null ? null : resolver.imageFor(path, cacheWidth: px);
      tiles.add(img != null
          ? CoverImageTile(img)
          : const CoverFallbackTile(kind: CoverKind.track));
    }

    if (tiles.length >= 4) {
      return CoverMosaic(
        tiles: tiles,
        size: size,
        radius: radius,
        shadow: shadow,
      );
    }

    // 1–3 slots: portada única representativa (la primera imagen real; si la
    // primera no resolvió, un respaldo de pista).
    final CoverTile first = tiles.first;
    if (first is CoverImageTile) {
      return Cover(
        image: first.image,
        size: size,
        radius: radius,
        shadow: shadow,
      );
    }
    return Cover(
      size: size,
      radius: radius,
      shadow: shadow,
      kind: CoverKind.track,
      coverSeed: seed,
    );
  }
}
