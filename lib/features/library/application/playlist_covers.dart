import 'dart:math' as math;

import '../../../data/db/database.dart';

/// Selecciona hasta [max] portadas **distintas** de las pistas de una playlist,
/// en orden, para componer su mosaico/portada. Salta portadas repetidas (p. ej.
/// varias pistas del mismo álbum comparten carátula) y pistas sin portada,
/// mirando la siguiente hasta reunir [max] distintas. Si no hay [max] distintas,
/// devuelve las que haya (el llamador decide: mosaico 2×2 si hay ≥4, o portada
/// única si hay menos — incluido el caso "todas iguales", que da 1 sola).
///
/// Función pura (testeable): trabaja sobre `coverPath` (la ruta/URL de carátula
/// que comparte cada álbum), no decodifica imágenes. Además optimiza la carga:
/// el llamador resuelve solo estas ≤[max] imágenes, no las de todas las pistas.
List<String> portadasDistintas(List<Pista> pistas, {int max = 4}) {
  final List<String> out = <String>[];
  final Set<String> vistas = <String>{};
  for (final Pista p in pistas) {
    final String? cp = p.coverPath;
    if (cp == null || cp.isEmpty) {
      continue;
    }
    if (vistas.add(cp)) {
      out.add(cp);
      if (out.length >= max) {
        break;
      }
    }
  }
  return out;
}

/// Compone los **slots** de portada de una playlist (hasta [max], en orden) para
/// el mosaico/portada, reflejando las pistas sin carátula:
/// - prioriza carátulas reales **distintas** (salta repetidas);
/// - si faltan para llenar [max] y la playlist tiene pistas sin carátula,
///   rellena con slots de respaldo (`null`), de modo que una pista sin portada
///   "queda como si fuera esa la portada" (placeholder tipado en el mosaico);
/// - si **ninguna** pista aporta carátula real, devuelve la lista vacía: el
///   llamador muestra un único placeholder de playlist (más limpio que un
///   mosaico de respaldos idénticos).
///
/// Cada elemento es la `coverPath` de una carátula real, o `null` (respaldo).
/// Función pura (testeable): no decodifica imágenes.
List<String?> slotsPortadaPlaylist(List<Pista> pistas, {int max = 4}) {
  final List<String> reales = portadasDistintas(pistas, max: max);
  if (reales.isEmpty) {
    return const <String?>[];
  }
  if (reales.length >= max) {
    return List<String?>.from(reales);
  }
  final int sinCover = pistas
      .where((Pista p) => p.coverPath == null || p.coverPath!.isEmpty)
      .length;
  final int respaldos = math.min(max - reales.length, sinCover);
  return <String?>[
    ...reales,
    for (int i = 0; i < respaldos; i++) null,
  ];
}
