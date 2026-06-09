import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/daos/sync_state_dao.dart';

/// Anclaje de playlists: las ancladas quedan **siempre arriba** dentro de su
/// sección ("Tus playlists" o "Del PC"), sin importar el orden/filtro aplicado.
/// Es estado propio del móvil, guardado como kv en `SyncEstado` (sin tabla nueva).
///
/// Cada anclada se representa con un **token tipado** para no confundir ids de
/// playlists locales con los del PC (espacios de id distintos): `L<id>` (local) y
/// `P<id>` (PC). El máximo de 4 es **por sección** y lo aplica la pantalla, que es
/// quien sabe a qué sección pertenece cada playlist en cada momento.

/// Clave kv de los tokens anclados (CSV).
const String kPlaylistsAncladas = 'playlists_ancladas';

/// Máximo de playlists ancladas por sección (Tus playlists / Del PC).
const int kMaxAncladasPorSeccion = 4;

String tokenLocal(int id) => 'L$id';
String tokenPc(int id) => 'P$id';

/// Parsea el CSV de tokens (ignora vacíos). Pura.
List<String> parseTokensAncladas(String? csv) {
  if (csv == null || csv.isEmpty) {
    return const <String>[];
  }
  return csv.split(',').where((String e) => e.isNotEmpty).toList();
}

String _encode(Iterable<String> tokens) => tokens.join(',');

/// Tokens anclados (reactivo), en su orden de anclaje.
final StreamProvider<List<String>> playlistsAncladasProvider =
    StreamProvider<List<String>>((Ref ref) {
  return ref
      .watch(syncStateDaoProvider)
      .watchValor(kPlaylistsAncladas)
      .map(parseTokensAncladas);
});

/// Mueve al frente las playlists ancladas (por token), preservando el orden
/// relativo de cada grupo. Pura y testeable.
List<T> conAncladasArriba<T>(
  List<T> base,
  Set<String> ancladas,
  String Function(T) tokenDe,
) {
  final List<T> arriba = <T>[];
  final List<T> resto = <T>[];
  for (final T x in base) {
    if (ancladas.contains(tokenDe(x))) {
      arriba.add(x);
    } else {
      resto.add(x);
    }
  }
  return <T>[...arriba, ...resto];
}

/// Decide si se puede anclar un token nuevo en una sección con [yaAncladas] del
/// mismo grupo: cabe si aún no hay [kMaxAncladasPorSeccion]. Pura.
bool puedeAnclar(int yaAncladasEnSeccion) =>
    yaAncladasEnSeccion < kMaxAncladasPorSeccion;

/// Controlador de anclaje: solo persiste (la regla de máximo por sección la
/// evalúa la pantalla, que conoce la composición de cada sección).
class PlaylistPinsController {
  PlaylistPinsController(this._dao);

  final SyncStateDao _dao;

  Future<void> _save(Iterable<String> tokens) =>
      _dao.setValor(kPlaylistsAncladas, _encode(tokens));

  /// Ancla [token] (idempotente).
  Future<void> anclar(List<String> actuales, String token) {
    if (actuales.contains(token)) {
      return Future<void>.value();
    }
    return _save(<String>[...actuales, token]);
  }

  /// Quita [token] de las ancladas.
  Future<void> desanclar(List<String> actuales, String token) =>
      _save(actuales.where((String x) => x != token));
}

final Provider<PlaylistPinsController> playlistPinsControllerProvider =
    Provider<PlaylistPinsController>(
  (Ref ref) => PlaylistPinsController(ref.watch(syncStateDaoProvider)),
);
