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
