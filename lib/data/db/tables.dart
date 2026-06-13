import 'package:drift/drift.dart';

// Esquema local de NB Sound Mobile (ver docs/local-data.md).
//
// Réplica de catálogo (read-only, viene del PC): artistas, albums, pistas,
// playlists, playlist_pistas. El `id` conserva el id del PC para correlacionar
// en cada sync. Datos propios del móvil (fuente de verdad local): historial,
// favoritos, descargas. Estado: sync_estado, pc_emparejado.

/// Artistas (espejo del PC `origen='pc'`, o música local del teléfono
/// `origen='local'` con id negativo).
@DataClassName('Artista')
class Artistas extends Table {
  IntColumn get id => integer()();
  TextColumn get nombre => text()();

  /// Ruta local de la imagen si se descargó (asset/file); si no, se resuelve
  /// por URL desde el PC.
  TextColumn get imagenPath => text().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  /// `pc` (espejo sincronizado) | `local` (música del teléfono). El sync solo
  /// toca filas `pc`; las `local` (id < 0) son invisibles al PC/Connect.
  TextColumn get origen => text().withDefault(const Constant('pc'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Álbumes (espejo del PC `origen='pc'`, o local `origen='local'` con id < 0).
@DataClassName('Album')
class Albums extends Table {
  IntColumn get id => integer()();
  TextColumn get titulo => text()();
  IntColumn get artistaId => integer().nullable()();
  TextColumn get tipo => text().withDefault(const Constant('Album'))();
  IntColumn get anio => integer().nullable()();
  TextColumn get coverPath => text().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  /// `pc` | `local`. Ver [Artistas.origen].
  TextColumn get origen => text().withDefault(const Constant('pc'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Pistas (réplica del PC). Campos planos espejo del manifest (pc-contract §4.3).
@DataClassName('Pista')
class Pistas extends Table {
  IntColumn get id => integer()();
  TextColumn get titulo => text()();
  TextColumn get artistaNombre => text()();
  TextColumn get albumTitulo => text().nullable()();
  IntColumn get albumId => integer().nullable()();
  IntColumn get artistaId => integer().nullable()();
  IntColumn get trackNumber => integer().nullable()();
  RealColumn get duracionSeg => real().withDefault(const Constant(0))();
  IntColumn get anio => integer().nullable()();
  TextColumn get genero => text().nullable()();
  TextColumn get isrc => text().nullable()();

  /// Valida el audio descargado (igual que `X-NB-Sound-Hash`).
  TextColumn get hashSha256 => text().nullable()();

  // Audio features básicas (pueden ser null).
  RealColumn get bpm => real().nullable()();
  RealColumn get energy => real().nullable()();

  /// Tonalidad musical (`key` en el manifest; renombrado para evitar choques).
  TextColumn get keyMusical => text().nullable()();

  /// Rutas locales (asset/file) cuando se han descargado. En música local,
  /// `audioPath` es la content-URI de MediaStore (`content://…`) y `coverPath`
  /// el esquema `localart://<mediaStoreId>` (ver local_ids.dart).
  TextColumn get coverPath => text().nullable()();
  TextColumn get lyricsPath => text().nullable()();
  TextColumn get audioPath => text().nullable()();

  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  /// `pc` (espejo sincronizado) | `local` (música del teléfono, id < 0). El sync
  /// solo toca filas `pc`; las locales jamás se relacionan con el PC/Connect.
  TextColumn get origen => text().withDefault(const Constant('pc'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Playlists (réplica del PC; read-only en v1).
@DataClassName('Playlist')
class Playlists extends Table {
  IntColumn get id => integer()();
  TextColumn get nombre => text()();
  TextColumn get tipo => text().withDefault(const Constant('manual'))();
  TextColumn get autoKey => text().nullable()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// Pistas de cada playlist, con orden de posición.
@DataClassName('PlaylistPista')
class PlaylistPistas extends Table {
  IntColumn get playlistId => integer()();
  IntColumn get pistaId => integer()();
  IntColumn get posicion => integer()();

  @override
  Set<Column<Object>> get primaryKey =>
      <Column<Object>>{playlistId, pistaId};
}

/// Playlists LOCALES del teléfono (fuente de verdad del móvil; editables). Viven
/// aparte del catálogo del PC para no chocar con sus ids ni con el sync. El
/// contrato v1 no permite escribir playlists en el PC, así que estas no se suben.
@DataClassName('PlaylistLocal')
class PlaylistsLocales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get nombre => text()();
  TextColumn get descripcion => text().nullable()();
  DateTimeColumn get creadoEn => dateTime()();
  DateTimeColumn get actualizadoEn => dateTime()();
}

/// Pistas de cada playlist local (referencian `pistas.id` del catálogo), con
/// orden de posición.
@DataClassName('PlaylistLocalPista')
class PlaylistLocalPistas extends Table {
  IntColumn get playlistId => integer()();
  IntColumn get pistaId => integer()();
  IntColumn get posicion => integer()();

  @override
  Set<Column<Object>> get primaryKey =>
      <Column<Object>>{playlistId, pistaId};
}

/// Playlists del PC que el usuario decidió **guardar/seguir** en el móvil. Es
/// estado propio del teléfono (no se sincroniza al PC): vive aparte del catálogo
/// para no chocar con el sync. Una playlist guardada aparece en "Tus playlists",
/// se mantiene al día por el sync del catálogo y su contenido se descarga para
/// tenerla viva offline. `playlistId` referencia `playlists.id` (réplica del PC).
@DataClassName('PlaylistGuardada')
class PlaylistsGuardadas extends Table {
  IntColumn get playlistId => integer()();
  DateTimeColumn get guardadaEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{playlistId};
}

/// Historial de reproducción (fuente de verdad local; append + subida).
@DataClassName('HistorialEntry')
class HistorialLocal extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get pistaId => integer()();
  DateTimeColumn get reproducidoEn => dateTime()();
  RealColumn get duracionSeg => real().nullable()();
  BoolColumn get completada => boolean().withDefault(const Constant(false))();
  BoolColumn get subido => boolean().withDefault(const Constant(false))();
}

/// Favoritos locales (fuente de verdad local; last-write-wins por timestamp).
@DataClassName('FavoritoEntry')
class FavoritosLocal extends Table {
  IntColumn get pistaId => integer()();
  BoolColumn get esFavorita => boolean().withDefault(const Constant(true))();
  DateTimeColumn get actualizadoEn => dateTime()();
  BoolColumn get subido => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{pistaId};
}

/// Estado de descarga **completa** de una pista (audio + extras offline). El
/// `estado`/`bytes`/`hashOk` refieren al audio (recurso principal); la letra y el
/// instrumental de karaoke llevan su propio estado por recurso. La portada y la
/// foto del artista se trackean aparte en [AssetsDescargados] (se comparten entre
/// pistas del mismo álbum/artista).
///
/// Estados por recurso: `none` (no intentado) · `pending`/`downloading` (en curso)
/// · `done` (descargado) · `unavailable` (el PC respondió 404: no existe, NO se
/// reintenta) · `failed` (error transitorio: se reintenta).
@DataClassName('DescargaAudio')
class DescargasAudio extends Table {
  IntColumn get pistaId => integer()();

  // Audio (recurso principal).
  TextColumn get estado => text().withDefault(const Constant('pending'))();
  IntColumn get bytes => integer().withDefault(const Constant(0))();
  IntColumn get totalBytes => integer().nullable()();
  BoolColumn get hashOk => boolean().nullable()();

  // Letra (`lyrics/{id}.json`). Sin bytes: es un JSON pequeño de una sola pasada.
  TextColumn get lyricsEstado => text().withDefault(const Constant('none'))();

  // Instrumental de karaoke (`stems/{id}.audio`), reanudable como el audio.
  TextColumn get stemsEstado => text().withDefault(const Constant('none'))();
  IntColumn get stemsBytes => integer().withDefault(const Constant(0))();
  IntColumn get stemsTotalBytes => integer().nullable()();

  DateTimeColumn get actualizadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{pistaId};
}

/// Imágenes descargadas para uso offline, deduplicadas por entidad: una portada
/// de álbum (`cover`) la comparten todas sus pistas, y una foto de artista
/// (`artist`) todas las suyas. El archivo vive en disco (`covers/{id}.img` /
/// `artists/{id}.img`); aquí solo se guarda el estado para resolver UI y descargas.
@DataClassName('AssetDescargado')
class AssetsDescargados extends Table {
  /// `cover` (refId = albumId) | `artist` (refId = artistaId).
  TextColumn get tipo => text()();
  IntColumn get refId => integer()();

  /// `done` | `unavailable` (404) | `failed` (error transitorio).
  TextColumn get estado => text()();
  DateTimeColumn get actualizadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{tipo, refId};
}

/// Pistas de **música local** que el usuario decidió **ocultar** (quitar de la
/// app sin borrarlas del teléfono). Se identifican por su id de MediaStore; el
/// escaneo las salta, así no se re-añaden. Guardamos título/artista para poder
/// listarlas en "Ocultas" y permitir revelarlas. No confundir con el flag global
/// "ocultar toda la música local" (clave kv en [SyncEstado]).
@DataClassName('LocalOcultaRow')
class LocalMediaOcultas extends Table {
  /// `_ID` de MediaStore (positivo).
  IntColumn get mediaId => integer()();
  TextColumn get titulo => text()();
  TextColumn get artista => text().nullable()();
  DateTimeColumn get ocultadoEn => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{mediaId};
}

/// Pares clave/valor de estado de sync (p.ej. ultima_sync_version).
@DataClassName('SyncEstadoEntry')
class SyncEstado extends Table {
  TextColumn get clave => text()();
  TextColumn get valor => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{clave};
}

/// Datos no sensibles del PC emparejado (el device_token/fingerprint van a
/// almacenamiento seguro, no aquí).
@DataClassName('PcEmparejadoRow')
class PcEmparejado extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  TextColumn get host => text().nullable()();
  TextColumn get nombrePc => text().nullable()();
  DateTimeColumn get ultimaConexion => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
