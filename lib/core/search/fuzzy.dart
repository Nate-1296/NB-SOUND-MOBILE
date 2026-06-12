/// Búsqueda difusa en memoria, tolerante a errores ortográficos y acentos.
/// Pensada para correr rápido sobre miles de ítems por pulsación: normaliza una
/// vez (en los índices), aplica comprobaciones baratas primero (igualdad/prefijo/
/// subcadena) y solo recurre a distancia de edición acotada como respaldo.
library;

/// Mapa de diacríticos comunes (suficiente para metadatos de música en
/// español/inglés/portugués/francés). Evita una dependencia externa.
const Map<String, String> _diacriticos = <String, String>{
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y', 'ß': 's', 'æ': 'a', 'œ': 'o',
};

/// Apóstrofes/comillas simples que NO separan palabras: se eliminan sin dejar
/// espacio, de modo que "Ain't" y "aint" normalizan igual ("aint"). Antes el
/// apóstrofe se colapsaba a espacio ("ain t") y la búsqueda no perdonaba ese
/// símbolo (buscar "aint" no encontraba "Ain't").
const Set<int> _apostrofes = <int>{
  0x27, // '  apóstrofe recto
  0x2019, // ’  comilla simple derecha (la que ponen muchos editores)
  0x2018, // ‘  comilla simple izquierda
  0x02BC, // ʼ  letra modificadora apóstrofe
  0x00B4, // ´  acento agudo suelto
  0x0060, // `  acento grave
};

/// Normaliza un texto para comparar: minúsculas, sin diacríticos, los apóstrofes
/// se eliminan (no separan palabras) y todo lo demás no alfanumérico se colapsa a
/// un único espacio (recortado).
String normalizar(String s) {
  final String lower = s.toLowerCase();
  final StringBuffer sb = StringBuffer();
  bool ultimoEspacio = true; // evita espacios iniciales
  for (final int rune in lower.runes) {
    if (_apostrofes.contains(rune)) {
      continue; // no separa palabras: "ain't" → "aint"
    }
    final String ch = String.fromCharCode(rune);
    final String base = _diacriticos[ch] ?? ch;
    final bool alfaNum = base.length == 1 &&
        ((base.codeUnitAt(0) >= 97 && base.codeUnitAt(0) <= 122) ||
            (base.codeUnitAt(0) >= 48 && base.codeUnitAt(0) <= 57));
    if (alfaNum) {
      sb.write(base);
      ultimoEspacio = false;
    } else if (!ultimoEspacio) {
      sb.write(' ');
      ultimoEspacio = true;
    }
  }
  final String out = sb.toString();
  return out.endsWith(' ') ? out.substring(0, out.length - 1) : out;
}

/// Tokens (palabras) de un texto ya normalizado.
List<String> tokenizar(String norm) =>
    norm.isEmpty ? const <String>[] : norm.split(' ');

/// Distancia de edición (Levenshtein) **acotada**: devuelve la distancia si es
/// ≤ [maxDist], o `-1` en cuanto se garantiza que la supera (corte temprano por
/// banda). Coste ~O(n·maxDist).
int distanciaAcotada(String a, String b, int maxDist) {
  if ((a.length - b.length).abs() > maxDist) {
    return -1;
  }
  if (a == b) {
    return 0;
  }
  if (a.isEmpty) {
    return b.length <= maxDist ? b.length : -1;
  }
  if (b.isEmpty) {
    return a.length <= maxDist ? a.length : -1;
  }
  List<int> prev = List<int>.generate(b.length + 1, (int i) => i);
  List<int> cur = List<int>.filled(b.length + 1, 0);
  for (int i = 1; i <= a.length; i++) {
    cur[0] = i;
    int mejorFila = cur[0];
    final int desde = (i - maxDist) > 1 ? (i - maxDist) : 1;
    final int hasta = (i + maxDist) < b.length ? (i + maxDist) : b.length;
    // Fuera de la banda: valores que no pueden mejorar el resultado.
    if (desde > 1) {
      cur[desde - 1] = maxDist + 1;
    }
    for (int j = desde; j <= hasta; j++) {
      final int coste = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      int v = prev[j - 1] + coste;
      final int borrar = prev[j] + 1;
      final int insertar = cur[j - 1] + 1;
      if (borrar < v) {
        v = borrar;
      }
      if (insertar < v) {
        v = insertar;
      }
      cur[j] = v;
      if (v < mejorFila) {
        mejorFila = v;
      }
    }
    if (mejorFila > maxDist) {
      return -1;
    }
    final List<int> tmp = prev;
    prev = cur;
    cur = tmp;
  }
  final int d = prev[b.length];
  return d <= maxDist ? d : -1;
}

/// Máxima distancia tolerada según el largo de la consulta (más permisivo cuanto
/// más larga). Consultas muy cortas no toleran typos (evita falsos positivos).
int maxDistPara(int largoQuery) {
  if (largoQuery <= 3) {
    return largoQuery <= 2 ? 0 : 1;
  }
  if (largoQuery <= 6) {
    return 2;
  }
  return 3;
}

/// Puntúa cuánto coincide [queryNorm] con un objetivo (ya normalizado y
/// tokenizado). Devuelve un valor en (0, 1] de más a menos coincidencia, o `0`
/// si no hay coincidencia. Orden de fuerza: exacto > prefijo > subcadena >
/// token-exacto/prefijo/subcadena > typo (distancia) > subsecuencia.
double puntuarTexto(String queryNorm, String objetivoNorm, List<String> tokens) {
  if (queryNorm.isEmpty || objetivoNorm.isEmpty) {
    return 0;
  }
  // Coincidencia sobre el texto completo.
  if (objetivoNorm == queryNorm) {
    return 1.0;
  }
  if (objetivoNorm.startsWith(queryNorm)) {
    return 0.92 + 0.06 * _ratioLargo(queryNorm, objetivoNorm);
  }
  final int idx = objetivoNorm.indexOf(queryNorm);
  if (idx >= 0) {
    // Antes la subcadena cuanto más al principio y más cubra el objetivo.
    final double posBonus = 1.0 - (idx / objetivoNorm.length);
    return 0.78 + 0.06 * posBonus;
  }

  // Coincidencia por token (palabra).
  double mejor = 0;
  final int qLen = queryNorm.length;
  final int maxDist = maxDistPara(qLen);
  for (final String token in tokens) {
    if (token == queryNorm) {
      mejor = mejor < 0.9 ? 0.9 : mejor;
      continue;
    }
    if (token.startsWith(queryNorm)) {
      final double s = 0.74 + 0.04 * _ratioLargo(queryNorm, token);
      mejor = mejor < s ? s : mejor;
      continue;
    }
    if (token.contains(queryNorm)) {
      mejor = mejor < 0.66 ? 0.66 : mejor;
      continue;
    }
    if (maxDist > 0) {
      final int d = distanciaAcotada(queryNorm, token, maxDist);
      if (d >= 0) {
        final double s = 0.62 - 0.10 * d;
        mejor = mejor < s ? s : mejor;
      }
    }
  }
  if (mejor > 0) {
    return mejor;
  }

  // Respaldo: subsecuencia (los caracteres de la query aparecen en orden).
  if (_esSubsecuencia(queryNorm, objetivoNorm)) {
    return 0.35;
  }
  return 0;
}

double _ratioLargo(String query, String objetivo) =>
    objetivo.isEmpty ? 0 : query.length / objetivo.length;

/// True si [q] es subsecuencia de [s] (caracteres en orden, no necesariamente
/// contiguos). Barato y útil para consultas multipalabra abreviadas.
bool _esSubsecuencia(String q, String s) {
  int j = 0;
  for (int i = 0; i < s.length && j < q.length; i++) {
    if (s.codeUnitAt(i) == q.codeUnitAt(j)) {
      j++;
    }
  }
  return j == q.length;
}
