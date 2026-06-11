import 'package:drift/drift.dart';

import '../database.dart';
import '../tables.dart';

part 'sync_state_dao.g.dart';

/// Estado de sincronización (pares clave/valor). Clave canónica:
/// `ultima_sync_version` (high-water mark del último manifest aplicado).
@DriftAccessor(tables: <Type>[SyncEstado])
class SyncStateDao extends DatabaseAccessor<AppDatabase>
    with _$SyncStateDaoMixin {
  SyncStateDao(super.db);

  static const String kUltimaSyncVersion = 'ultima_sync_version';

  /// Perfil del PC (JSON: nombre + estadísticas), guardado en cada sync.
  static const String kPerfil = 'perfil';

  /// Preferencia "Descargar todo": si es `'1'`, tras cada sync se encola el
  /// catálogo completo para mantener un espejo offline.
  static const String kDescargarTodo = 'descargar_todo';

  /// Marca de tiempo (ISO-8601) de la última sincronización con éxito.
  static const String kUltimaSync = 'ultima_sync';

  /// Modo aleatorio del reproductor (estado global, `'1'`/`'0'`).
  static const String kAleatorio = 'aleatorio';

  /// Modo de repetición del reproductor (estado global: `off`/`one`/`all`).
  static const String kRepeticion = 'repeticion';

  /// Sesión del reproductor persistida (JSON: ids de la cola + índice + posición
  /// en ms), para restaurar "lo que sonaba" al reabrir la app, como Spotify.
  static const String kSesion = 'sesion_repro';

  /// Búsquedas recientes (JSON: lista de textos, recientes primero).
  static const String kBusquedasRecientes = 'busquedas_recientes';

  /// Resultados recientes de búsqueda (JSON: lista de items reales —
  /// pista/álbum/artista/playlist— recientes primero), estilo Spotify.
  static const String kBusquedasRecientesItems = 'busquedas_recientes_items';

  /// Nombre del usuario fijado a mano. Si está presente NO se sobrescribe con el
  /// nombre del PC al sincronizar (decisión del usuario).
  static const String kNombreUsuario = 'nombre_usuario';

  /// Ruta local de la foto de perfil elegida por el usuario.
  static const String kFotoPerfil = 'foto_perfil';

  /// Clave del ícono de app activo (uno de los 63 temas, o `''` por defecto).
  static const String kIconoApp = 'icono_app';

  /// Modos de visualización persistidos de la biblioteca/playlists
  /// (`lista`/`grid_pequena`/`grid_mediana`), uno por sección.
  static const String kVistaAlbumes = 'vista_albumes';
  static const String kVistaArtistas = 'vista_artistas';
  static const String kVistaPistas = 'vista_pistas';
  static const String kVistaPlaylists = 'vista_playlists';

  Stream<String?> watchValor(String clave) =>
      (select(syncEstado)..where((t) => t.clave.equals(clave)))
          .watchSingleOrNull()
          .map((SyncEstadoEntry? row) => row?.valor);

  Future<String?> getValor(String clave) async {
    final SyncEstadoEntry? row =
        await (select(syncEstado)..where((t) => t.clave.equals(clave)))
            .getSingleOrNull();
    return row?.valor;
  }

  Future<void> setValor(String clave, String valor) =>
      into(syncEstado).insertOnConflictUpdate(
        SyncEstadoCompanion.insert(clave: clave, valor: valor),
      );

  Future<int> getUltimaSyncVersion() async =>
      int.tryParse(await getValor(kUltimaSyncVersion) ?? '') ?? 0;

  Future<void> setUltimaSyncVersion(int version) =>
      setValor(kUltimaSyncVersion, '$version');
}
