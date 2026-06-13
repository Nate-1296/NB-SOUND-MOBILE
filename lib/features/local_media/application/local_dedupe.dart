import '../../../core/search/fuzzy.dart';

/// Datos mínimos de una pista para deduplicar música local contra el catálogo
/// sincronizado del PC. Pensado para alimentarse desde filas `Pista`.
class PistaDedupe {
  const PistaDedupe({
    required this.id,
    required this.titulo,
    required this.artista,
    required this.album,
    required this.duracionSeg,
  });

  final int id;
  final String titulo;
  final String artista;
  final String? album;
  final double duracionSeg;
}

/// Clave normalizada de identidad de una pista (título + artista + álbum), para
/// agrupar candidatos a duplicado en O(n). La duración se compara aparte (con
/// tolerancia), por eso no entra en la clave.
String claveDedupe(PistaDedupe p) =>
    '${normalizar(p.titulo)}|${normalizar(p.artista)}|${normalizar(p.album ?? '')}';

/// Decide qué pistas **locales** son duplicados de una sincronizada del PC y,
/// por tanto, deben eliminarse (la sincronizada prima: trae todos los datos).
///
/// Regla (la del PC): misma identidad por transitividad —mismo título, mismo
/// artista, mismo álbum (normalizados, tolerante a acentos/puntuación)— y
/// **duración similar** (±[toleranciaSeg]). Devuelve los ids locales a quitar.
///
/// Función pura y testeable: no toca la BD. El llamado elimina esas filas (y
/// remapea sus referencias de playlist/favoritos a la sincronizada).
Map<int, int> mapaDuplicadosLocales(
  List<PistaDedupe> locales,
  List<PistaDedupe> sincronizadas, {
  double toleranciaSeg = 10,
}) {
  if (locales.isEmpty || sincronizadas.isEmpty) {
    return const <int, int>{};
  }
  // Índice de sincronizadas por clave de identidad → lista de candidatas.
  final Map<String, List<PistaDedupe>> porClave = <String, List<PistaDedupe>>{};
  for (final PistaDedupe s in sincronizadas) {
    porClave.putIfAbsent(claveDedupe(s), () => <PistaDedupe>[]).add(s);
  }

  // local.id → sincronizada.id con la que se solapa (la más cercana en duración).
  final Map<int, int> out = <int, int>{};
  for (final PistaDedupe l in locales) {
    final List<PistaDedupe>? candidatas = porClave[claveDedupe(l)];
    if (candidatas == null) {
      continue;
    }
    int? mejorId;
    double mejorDelta = double.infinity;
    for (final PistaDedupe s in candidatas) {
      final double delta = (s.duracionSeg - l.duracionSeg).abs();
      if (delta <= toleranciaSeg && delta < mejorDelta) {
        mejorDelta = delta;
        mejorId = s.id;
      }
    }
    if (mejorId != null) {
      out[l.id] = mejorId;
    }
  }
  return out;
}
