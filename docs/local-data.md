# Datos locales — NB Sound Mobile

La app móvil mantiene su **propia base de datos local** (Drift/SQLite). Es
**fuente de verdad** de su historial de reproducción y favoritos locales, y
una **réplica de solo lectura** de la metadata enriquecida que envía el PC.

> **As-built:** implementado en `lib/data/db/` (esquema en `tables.dart`, DAOs en
> `daos/`, seed dev en `seed/dev_seed.dart`). Verificado en emulador. Detalle de
> estado en [`app-state.md`](app-state.md).

## Principios

- **Offline-first**: la app funciona sin el PC usando solo esta BD + el audio
  descargado.
- **Dirección de autoridad** (ver reglas de merge en
  [`sync-protocol.md`](sync-protocol.md)):
  - metadata (pista/álbum/artista/playlist) → **PC manda**, local es réplica.
  - historial y favoritos → **celular manda**.
- **No replica el pipeline ni el análisis**: la app no importa ni analiza
  audio; solo consume lo que el PC ya catalogó.

## Esquema local (Drift)

Espejo reducido del esquema del PC, más tablas propias del móvil.

### Réplica de catálogo (read-only, viene del PC)

```text
artistas        (id, nombre, imagen_path?, sync_version)
albums          (id, titulo, artista_id, tipo, anio, cover_path?, sync_version)
pistas          (id, titulo, artista_nombre, album_titulo, album_id,
                 artista_id, duracion_seg, anio, genero, isrc, hash_sha256,
                 cover_path?, lyrics_path?, bpm?, energy?, key?, sync_version)
playlists       (id, nombre, tipo, auto_key?, sync_version)
playlist_pistas (playlist_id, pista_id, posicion)
```

> `*_path` apuntan a archivos en el almacenamiento de la app (portada, lyrics,
> audio) cuando se han descargado; si no, se resuelven por streaming desde el
> PC. `id` conserva el id del PC para correlacionar en cada sync.

### Música local del teléfono ("dos bibliotecas en una")

`pistas`/`albums`/`artistas` ganan una columna **`origen`** (`pc` | `local`,
schema v6). La música local del propio teléfono (escaneada de **MediaStore**)
vive en **estas mismas tablas** —para fluir por toda la UI (biblioteca, buscar,
playlists locales, favoritos, cola, reproductor)— pero con **`origen='local'`** e
**ids negativos**. El espejo del PC usa ids **positivos**; como el sync es
**delta + tombstones por ids del PC**, jamás toca las filas locales. El signo del
id (`id < 0`) es además la guarda de **aislamiento del Connect**.

- **Origen de datos**: `MethodChannel` nativo `com.nbsound/local_media`
  (`MainActivity.kt`) consulta MediaStore (`IS_MUSIC` + duración ≥ 30 s → ignora
  notas de voz/sonidos de apps); permiso `READ_MEDIA_AUDIO` (Android 13+) /
  `READ_EXTERNAL_STORAGE` (≤12) vía `permission_handler`. No pide carpeta.
- **Reproducción**: `audioPath` = content-URI de MediaStore; just_audio la
  reproduce (`AudioSource.uri`).
- **Carátula embebida**: tras el escaneo, un pase en segundo plano
  (`rellenarCaratulas`) prueba cada pista vía el canal nativo `artwork` y fija
  `coverPath` a `localart://<mediaId>` (si hay) o `''` (si no, para no reprobar).
  `CoverResolver` resuelve `localart://` con `LocalArtworkImage` (carga `loadThumbnail`
  bajo demanda); mientras tanto se ve el placeholder tipado. Tri-estado de
  `coverPath`: `null` (sin probar) · `''` (probado, sin carátula) · `localart://`.
- **Pistas flotantes**: si MediaStore no aporta álbum/artista, `album_id`/
  `artista_id` quedan null (no se agrupan).
- **Gestión** (pantalla `/musica-local`, estilo Descargas): revisar manual o
  automático (pref `musica_local_auto`); **ocultar por pista** (no la borra del
  teléfono; se recuerda en `local_media_ocultas` y el escaneo la salta) y
  **ocultar todas** (flag `musica_local_oculta`: quita todas las filas locales →
  desaparecen de la UI/funcionamiento sin tocar ninguna query; revelar = re-indexa);
  **buscador difuso** (tolerante a typos/símbolos, núcleo `fuzzy.dart`).
- **Dedupe** (la del PC prima): al terminar un escaneo o un sync, se eliminan las
  locales que dupliquen una sincronizada por **título+artista+álbum normalizados +
  duración ±10 s** (`local_dedupe.dart`), remapando sus playlists/favoritos a la
  del PC. Núcleo puro en `features/local_media/application/`.
- **Aislamiento Connect**: una pista local nunca sube al PC (`historial`/
  `favoritos` `noSubidos()` filtran `pista_id > 0`) ni se manda como comando
  remoto (`playback.dart`/menú de pista filtran `id < 0`).

### Datos propios del móvil (fuente de verdad local)

```text
historial_local   (id, pista_id, reproducido_en, completada, subido)
favoritos_local   (pista_id, es_favorita, actualizado_en, subido)
descargas_audio   (pista_id, estado, bytes, total_bytes, hash_ok,
                   actualizado_en)   -- pending|downloading|done|failed
```

### Estado de sincronización y emparejamiento

```text
sync_estado       (clave, valor)   -- p.ej. ultima_sync_version
pc_emparejado     (host?, device_token, tls_fingerprint, nombre_pc,
                   ultima_conexion)  -- credenciales del PC (seguras)
```

- `device_token` y `tls_fingerprint` se guardan con **almacenamiento seguro**
  (`flutter_secure_storage` — añadir a `pubspec.yaml` cuando se implemente
  esta capa; no se versiona como dependencia hasta el BLOQUE de sync).

## Migraciones

Drift gestiona migraciones por número de esquema (`schemaVersion`). Las
migraciones del móvil son independientes de las del PC; lo que viaja es el
**payload del protocolo**, no el DDL. Si el PC añade campos al manifest, el
cliente los mapea de forma tolerante (campos desconocidos se ignoran).

## Aplicación de un manifest delta (transacción)

```text
recibir manifest(since)
└─ en una transacción Drift:
   ├─ upsert artistas/albums/pistas/playlists (por id; PC gana)
   ├─ aplicar tombstones (DELETE local de lo borrado en PC)
   └─ sync_estado.ultima_sync_version = manifest.sync_version_actual
subir cambios locales no subidos:
   ├─ historial_local where subido=0  → POST /history  → marcar subido=1
   └─ favoritos_local where subido=0  → POST /history  → marcar subido=1
```

La transacción garantiza que un corte no deje el catálogo a medias; la subida
de historial/favoritos es idempotente (marcado `subido`).

## Almacenamiento de archivos

- **Audio offline**: `path_provider` → directorio de la app; nombre por
  `pista_id`; integridad validada con `hash_sha256` (crypto) al terminar.
- **Portadas/lyrics**: cache en disco con el `id` como clave; se redescargan
  si el PC reporta un `sync_version` mayor.
- **Limpieza**: el usuario puede liberar espacio borrando descargas; la
  metadata permanece (la pista vuelve a modo streaming).

## Seguridad

- Credenciales del PC (`device_token`, fingerprint) en almacenamiento seguro,
  nunca en la BD en claro.
- La BD local no guarda secretos del PC (claves de API, `.env`): esos nunca
  viajan (ver “Qué NO viaja” en `../../nb_sound/docs/mobile-ecosystem.md`).
