# Notas de integración real con el PC (Bloque 0)

Validación del contrato `docs/pc-contract.md` **contra el servidor real** de NB
Sound (mismo código `servicios/servidor_sync.py`, BD y certificado TLS reales del
usuario). Fecha: 2026-06-04.

## Cómo se validó

Se levantó `ServidorSync(host="0.0.0.0", tls=True)` desde el venv del proyecto
(`/home/nathan/Documentos/NB_Sound/nb_sound/.venv`) contra:

- BD real: `~/.local/share/nb_sound/biblioteca/nb_sound.sqlite3` (2231 pistas,
  1309 álbumes, 403 artistas, 51 playlists).
- Cert persistido: `~/.config/nb_sound/sync/sync_cert.pem` → huella **estable**
  `395f3acdfe92147efa1cd61712379e6ac9882f4d95b3c7bf1eea8e02ce38501d`.

Bind `0.0.0.0` para que el emulador Android lo alcance en `10.0.2.2:8731`
(verificado TCP_OK). El pinning del cliente es **por huella, no por host**, así
que reescribir el host del payload no rompe TLS.

## Resultados (endpoint por endpoint)

| Endpoint | Resultado real | Conformidad |
| --- | --- | --- |
| `payload_qr` | `{host, puerto:8731, token, version:1, tls:true, tls_fingerprint, servicio:"NB Sound"}` | ✓ exacto |
| `GET /ping` | `200 {ok, servicio, version_protocolo:1}` | ✓ |
| `POST /pair` | `200 {ok, device_token, dispositivo_id, nombre}` | ✓ |
| `GET /manifest?since=&limit=` | `200`; claves `albums, artistas, generado_en, has_more, next_since, perfil, pistas, playlists, protocolo, since, sync_version, sync_version_actual, tombstones`; paginación `has_more/next_since` correcta | ✓ |
| `GET /asset/cover/{id}` | `404 {error}` cuando el álbum no tiene `portada_ruta` (ver datos) | ✓ (degrada bien) |
| `GET /track/{id}/audio` (Range) | `206`, `Content-Range: bytes 0-1023/<total>`, `Accept-Ranges: bytes`, `X-NB-Sound-Hash: <hash>` | ✓ Range OK; **ver hash** |
| `GET /track/{id}/lyrics` | `200 {synced_lyrics: "[mm:ss.xx] …", plain_lyrics: "…"}`; `404 {error:"sin_lyrics"}` si no hay | ✓ |
| `GET /track/{id}/stems` (Range) | `206`, `content-type: audio/mpeg`, `Content-Range` (instrumental); `404 {error:"sin_stems"}` | ✓ |

**Perfil real** (del manifest):
```json
{"nombre": "Nathan",
 "foto": "/home/nathan/Música/cache/perfil/foto_perfil_...jpg",
 "estadisticas": {"total_pistas": 2231, "total_favoritas": 23}}
```
→ `foto` es una **ruta local del PC**, no un endpoint/URL: **no es descargable**
por el móvil. El perfil móvil usará `nombre` + `estadisticas`; avatar con inicial.

**Formato de letra (LRC synced)** — ejemplo real de la pista 2223:
```
[00:08.72] Enrique Iglesias
[00:10.92] One love, one love
[00:12.70] Gente de Zona
```
Líneas `[mm:ss.xx] texto`; puede haber líneas vacías. `plain_lyrics` es el mismo
texto sin marcas.

## Observaciones de DATOS del PC (no del contrato)

Estado actual de la biblioteca del usuario, relevante para lo que verá el móvil
tras una sync real:

- **Solo 41 de 2231 pistas tienen `sync_version > 0`** (`sync_version_actual=75`).
  El manifest filtra `sync_version > since`, así que una sync trae **solo esas 41
  pistas** (ids 2196–2260). Las 2190 restantes quedaron en `sync_version=0` al
  importar y **nunca se sincronizarán** hasta que el PC las re-versione.
- **0 álbumes tienen `portada_ruta`** → no hay portadas que servir; `cover_url`
  viaja en el manifest pero `/asset/cover/{id}` responde 404. El móvil debe
  degradar a respaldo (sin romper).
- **0 playlists con `sync_version > 0`** → el manifest no trae playlists del PC.

→ **Recomendación para el PC** (fuera del alcance móvil): re-indexar/re-taggear la
biblioteca para asignar `sync_version` a todas las pistas, generar portadas y
versionar playlists. Sin eso, la experiencia móvil con datos reales es limitada
(41 pistas, sin arte, sin playlists del PC).

## Pistas reales útiles para pruebas

- En manifest (sincronizables): ids **2196–2260** (41 pistas), todas con
  `ruta_archivo` (audio + Range OK).
- Con **letra**: 2223 (synced 3176 chars + plain).
- Con **karaoke listo** (stems): 2196 (LA FALDA), 2201 (LALA), 2221 (DEGENERE).

## Validación del CLIENTE sobre dispositivo real (emulador `nbsound`)

App Flutter (debug) instalada en el emulador, emparejada contra este servidor
(host reescrito `10.0.2.2`). La verificación se hizo con una entrada de
depuración temporal (`NB_DEBUG_QR`, *gated* por `kDebugMode`) que inyectaba el
payload del QR sin cámara; **esa entrada ya se retiró del código** una vez
cerrada la integración. Para re-verificar en emulador hay que reintroducirla
puntualmente o usar un dispositivo físico que escanee el QR real. Verificado
**funcionando**:

- **Emparejamiento + TLS pinning por huella** (`POST /pair` sobre HTTPS,
  validación del cert autofirmado por SHA-256) → `device_token` guardado. ✓
- **Sync de manifest** (`GET /manifest` paginado, TLS pinned, aplicado en
  transacción Drift): "✓ 68 entidades · 7 borrados". Las 41 pistas reales (ids
  2196–2260) entran al catálogo y son buscables; favoritos reconciliados. ✓
- **Subida de historial** (`POST /history`): "subido 11 de historial" (subió el
  historial local al PC real). ✓
- **Control remoto WSS** (`wss /control` con `customClient` pinned por huella):
  refleja el frame `estado` del PC (pista/posición/volumen/estado) en la vista
  "Reproduciendo en MI PC". ✓

→ Los flujos del Bloque B (pair/sync/history/WS) quedan **validados contra el PC
real** y suben a A. Token persiste: reiniciar el servidor no exige re-emparejar.

## Hallazgo crítico — `hash_sha256` no es un sha256 de archivo completo

La descarga offline **falla la validación de integridad** contra esta biblioteca
real. Diagnóstico (causa raíz):

1. **Semántica del hash**: el PC calcula `hash_sha256` con
   `core/validator.py::_calcular_hash_combinado` = **SHA256 de los primeros 512KB
   + los últimos 512KB** del archivo (dedupe), NO del archivo completo. El móvil
   (`download_repository.dart`) valida con SHA256 del **archivo completo** → para
   archivos >1MB **nunca coinciden**. El contrato (§4.5) describe mal esto como
   "el sha256 del archivo".
2. **Datos obsoletos**: peor aún, el `hash_sha256` almacenado tampoco coincide
   con el head+tail recalculado sobre los archivos actuales (p.ej. 2221:
   guardado `8d37…`, head+tail actual `a372…`, archivo completo `4a05…`). Los
   archivos se re-procesaron/re-taggearon tras hashear (5/5 muestras stale).

**Decisiones** (se aplican en el Bloque 2):

- Móvil: replicar el algoritmo **head+tail (512KB+512KB, chunk 8KB)** para alinear
  con la definición real del PC; documentarlo en `pc-contract.md` como contrato.
- Móvil: un mismatch de hash **no debe borrar** el archivo descargado (TLS ya da
  integridad de transporte y el tamaño se valida por Range); marcar
  `hashOk=false` ("descargado, no verificado") en vez de fallar y borrar.
- **Streaming no se ve afectado** (just_audio no valida hash) → la reproducción
  sin descargar funciona aunque el hash esté stale.
- Recomendación PC (fuera de alcance móvil): re-hashear la biblioteca para que la
  verificación de descargas pase limpia.

## Streaming / letra / descarga en dispositivo (Bloques 1–3) — VERIFICADO

Verificado en el emulador contra el PC real (pista 2223 "Bailando", 41 sincronizadas):

- **Streaming sin descargar** ✅: reproduce `/api/v1/track/{id}/audio` por HTTPS con
  pinning, sin descargar (avanzó 0:07→2:57).
- **Letra** ✅: `/lyrics` con LRC sincronizado, línea activa resaltada + auto-scroll;
  cacheada en `lyrics/{id}.json` (cache-first la 2ª vez).
- **Descarga en caliente** ✅: archivo íntegro (9.828.276 bytes) reensamblado por
  Range; conservado pese al hash stale (`hashOk=false`, no se borra).

**Dos fixes no triviales que reveló el dispositivo** (sin ellos, el streaming no
funciona en Android):

1. **Cleartext a loopback** (`android/app/src/main/res/xml/network_security_config.xml`):
   just_audio reproduce fuentes con cabeceras a través de un **proxy HTTP local**
   (ExoPlayer → `http://127.0.0.1:<port>`); Android bloquea cleartext a localhost
   por defecto (`Cleartext HTTP traffic to 127.0.0.1 not permitted`). Se habilita
   cleartext **solo** para `127.0.0.1`/`localhost` (el tráfico al PC sigue HTTPS).
2. **Pinning con huella en vivo** (`core/network/pinned_http_overrides.dart`):
   Flutter crea **un único `HttpClient` compartido** para `NetworkImage` la primera
   vez, que puede ocurrir antes de resolver el emparejamiento. El callback de pinning
   debe fijarse **siempre** y leer la huella **en cada validación** (no capturarla en
   la creación), o las portadas/streaming fallan con `CERTIFICATE_VERIFY_FAILED`.

> **Revocación de dispositivo**: durante las pruebas el dispositivo apareció
> `revocado=1` en la BD del PC (→ 401 en todo). No hay revocación automática en el
> código del PC (solo la acción manual de la GUI); el cliente debe **re-emparejar**
> ante un 401 (contrato §2). Pendiente afinar ese manejo en el móvil (Bloque 10).

## Conformidad y pendientes

- El servidor del PC **cumple el contrato** en endpoints/formatos; el único
  desajuste real es la **semántica de `hash_sha256`** (arriba) y el estado de
  datos (hashes stale, sin portadas, pocas pistas versionadas).
- Pendiente: validar streaming/letra/karaoke sobre el dispositivo real **una vez
  implementados** (Bloques 1–4), contra este mismo servidor.
