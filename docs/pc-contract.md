# Contrato del PC (as-built) — fuente de verdad para el cliente móvil

> **Este documento describe el protocolo EXACTAMENTE como está implementado y
> probado en la app de escritorio** (`nb_sound`, release **v1.1.0**). Donde
> difiera de [`sync-protocol.md`](sync-protocol.md), [`remote-control.md`](remote-control.md)
> o [`local-data.md`](local-data.md) (que son de diseño), **manda este
> documento**. El objetivo es que el desarrollo móvil codifique contra la
> implementación real y no haya que rehacer cosas por desajustes.

Versión de protocolo: **`1`** (campo `version` / `version_protocolo`).
Implementación PC: `servicios/servidor_sync.py`, `servicios/sync_repositorio.py`,
`servicios/biblioteca.py`, `ui/modelos_qml.py::ModeloSincronizacion`.

Todos los cuerpos JSON usan UTF-8. Timestamps en **ISO-8601 UTC con sufijo `Z`
y milisegundos** (`YYYY-MM-DDTHH:MM:SS.fffZ`) — el orden lexicográfico = orden
cronológico (se usa así en el merge de favoritos).

---

## 1. Transporte, puerto y descubrimiento

- **HTTP REST + WebSocket** sobre `aiohttp`, en un hilo propio del PC.
- **Puerto**: el PC elige el primero libre del rango **8731–8799**. El puerto
  efectivo viaja en el QR y en el anuncio mDNS. No lo asumas fijo.
- **Bind**: a la IP de la subred LAN del PC (no `0.0.0.0` público).
- **mDNS / DNS-SD**: tipo de servicio **`_nbsound._tcp.local.`**, con
  propiedades TXT `version` y `servicio`. Úsalo para **reconectar** a un PC ya
  emparejado (el QR es el camino del primer emparejamiento).
- **TLS (activo)**: el servidor sirve **HTTPS + WSS** con un certificado
  **autofirmado** generado y **persistido** en el PC (huella estable entre
  reinicios). El QR incluye `tls: true` y `tls_fingerprint` (SHA-256 hex del
  certificado, 64 chars). El cliente debe usar **TOFU**: fijar esa huella al
  emparejar y, en cada conexión, **validar el certificado por huella** (no por
  CA ni hostname). Esquemas: **`https://`** y **`wss://`**.
  - Si por alguna razón `tls` viene `false` y `tls_fingerprint` vacío (PC sin
    `cryptography`), el cliente cae a `http://`/`ws://` plano (degradación). En
    la práctica el release oficial trae TLS activo.
  - dio (Flutter): usa un `SecurityContext`/`badCertificateCallback` que acepte
    el cert **solo si** su SHA-256 == la huella fijada. Igual para el WS.

---

## 2. Autenticación

- **Emparejamiento**: `POST /api/v1/pair` con el **token efímero** del QR (un
  solo uso, TTL 300 s). Devuelve un **`device_token`** persistente.
- **Resto de llamadas**: header **`Authorization: Bearer <device_token>`**
  (también se acepta `X-Device-Token: <device_token>`). Excepciones sin auth:
  `GET /api/v1/ping` y `POST /api/v1/pair`.
- **Revocación**: si el PC revoca el dispositivo, todas las llamadas
  autenticadas devuelven **401** → el cliente debe re-emparejar.
- El `device_token` viaja igual en el handshake del WebSocket (header
  `Authorization`).

---

## 3. Contenido del QR

`payload_qr()` → JSON que el PC codifica en el QR:

```jsonc
{
  "host": "192.168.1.40",
  "puerto": 8731,
  "token": "<token_efímero_un_solo_uso>",
  "version": 1,
  "tls": true,
  "tls_fingerprint": "9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08",
  "servicio": "NB Sound"
}
```

La base de URLs del cliente es `https://{host}:{puerto}` (y `wss://…` para el
WebSocket) cuando `tls == true`; `http://`/`ws://` si `tls == false`. Fija
`tls_fingerprint` (TOFU) y valida el certificado por esa huella.

---

## 4. Endpoints HTTP

| Método | Ruta | Auth | Propósito |
| --- | --- | --- | --- |
| GET | `/api/v1/ping` | no | Liveness + versión de protocolo |
| POST | `/api/v1/pair` | token QR | Handshake; emite `device_token` |
| GET | `/api/v1/manifest?since=<n>&limit=<m>` | sí | Delta de cambios (paginable) |
| GET | `/api/v1/seleccion` | sí | Lee la selección de sync de este device |
| POST | `/api/v1/seleccion` | sí | Define la selección (negociada desde el móvil) |
| GET | `/api/v1/track/{id}/audio` | sí | Audio (soporta `Range` → 206) |
| GET | `/api/v1/track/{id}/stems` | sí | Instrumental de karaoke (opt-in) |
| GET | `/api/v1/track/{id}/lyrics` | sí | Letras (JSON synced/plain) |
| GET | `/api/v1/asset/{tipo}/{id}` | sí | Imagen: `tipo` = `cover`\|`album`\|`artist` |
| POST | `/api/v1/history` | sí | Sube historial + favoritos (merge) |
| GET (WS) | `/api/v1/control` | sí | Estado + comandos del reproductor |

### 4.1 `GET /api/v1/ping`
```jsonc
200 → { "ok": true, "servicio": "NB Sound", "version_protocolo": 1 }
```
Es público (sin auth). **Heartbeat de presencia**: si el cliente envía igualmente
su `Authorization: Bearer <device_token>`, el PC actualiza la `ultima_conexion` del
dispositivo y lo muestra **"conectado ahora"** en su pantalla de Sincronización
(presencia real, no solo "última conexión"), aunque el dispositivo no esté en
Connect (sin WS abierto). El móvil lo envía cada ~25 s mientras está en primer plano.

### 4.2 `POST /api/v1/pair`
Request:
```jsonc
{ "token": "<token_del_QR>", "nombre_dispositivo": "Pixel 8", "plataforma": "android" }
```
- `nombre_dispositivo` es el campo canónico (se acepta `nombre` como alias).
- `plataforma` ∈ `android | ios | ipados | tablet | desconocida` (otro valor → `desconocida`).

Respuestas:
```jsonc
200 → { "ok": true, "device_token": "<persistente>", "dispositivo_id": 3, "nombre": "Pixel 8" }
401 → { "error": "token_invalido_o_expirado" }
```
Tras un `pair` con éxito el token efímero **rota** (un solo uso): para vincular
otro dispositivo el PC genera un QR nuevo.

### 4.3 `GET /api/v1/manifest?since=<n>&limit=<m>`
`since` = última `sync_version` aplicada por el cliente (entero, 0 la primera
vez). `limit` (opcional) = máximo de entidades **combinadas** por página.

```jsonc
200 → {
  "protocolo": 1,
  "since": 0,
  "sync_version_actual": 42,     // HIGH-WATER MARK global del PC
  "sync_version": 42,            // alias de compatibilidad (mismo valor)
  "next_since": 20,              // cursor para la SIGUIENTE página
  "has_more": true,             // quedan más páginas
  "generado_en": "2026-05-30T15:00:00.000Z",
  "pistas":   [ { ...Pista } ],
  "albums":   [ { ...Album } ],
  "artistas": [ { ...Artista } ],
  "playlists":[ { ...Playlist } ],
  "tombstones":[ { "entidad": "pista", "entidad_id": 7, "sync_version": 41 } ],
  "perfil":   { ...Perfil }
}
```

Solo viajan entidades con `sync_version > since`. **Aplica cada página en una
transacción.**

**Paginación (recomendado para bibliotecas grandes):** envía `limit`. El
servidor devuelve hasta `limit` entidades (ordenadas por `sync_version`) y un
cursor `next_since`. Bucle del cliente:

```text
since = ultima_sync_version_local
loop:
  m = GET /manifest?since=since&limit=500
  aplicar m (upserts + tombstones) en transacción
  if m.has_more: since = m.next_since        # seguir paginando
  else:          ultima_sync_version = m.sync_version_actual; break
```

Sin `limit` el PC devuelve **todo** el delta de una vez (`has_more=false`,
`next_since=sync_version_actual`). En ese caso guarda
`ultima_sync_version = sync_version_actual` al aplicar. Reanudable: si una
página falla, reintenta con el mismo `since` (idempotente por id).

#### Pista
```jsonc
{
  "id": 123,
  "titulo": "One More Time",
  "artista_nombre": "Daft Punk",
  "album_titulo": "Discovery",
  "album_id": 10,
  "artista_id": 5,
  "track_number": 1,
  "duracion_seg": 320.4,
  "anio": 2001,
  "genero": "House",
  "isrc": "GBDUW0000059",
  "mb_recording_id": "....",
  "favorita": false,
  "favorita_actualizada_en": "2026-05-30T10:00:00.000Z",  // o null
  "hash_sha256": "ab12...",     // valida el audio descargado
  "sync_version": 40,
  "bpm": 123.0,                 // audio features básicas (planas, pueden ser null)
  "energy": 0.82,
  "key": "F#",
  "audio_url": "/api/v1/track/123/audio",
  "cover_url": "/api/v1/asset/cover/10",   // null si la pista no tiene álbum
  "lyrics_url": "/api/v1/track/123/lyrics"
}
```
> Las `*_url` son **relativas**; antepón `http://{host}:{puerto}`.

#### Album
```jsonc
{ "id": 10, "titulo": "Discovery", "artista_id": 5, "tipo": "Album",
  "anio": 2001, "sync_version": 39, "cover_url": "/api/v1/asset/cover/10" }
```

#### Artista
```jsonc
{ "id": 5, "nombre": "Daft Punk", "sync_version": 38,
  "imagen_url": "/api/v1/asset/artist/5" }
```

#### Playlist
```jsonc
{ "id": 2, "nombre": "Favoritas", "tipo": "manual", "auto_key": null,
  "sync_version": 37, "pista_ids": [123, 124, 130] }   // orden = posición
```
Solo se incluyen playlists con `visible = 1`. En v1 son **read-only** para el móvil.

#### Perfil
```jsonc
{ "nombre": "Jonathan", "foto": "<ruta o vacío>",
  "estadisticas": { "total_pistas": 1200, "total_favoritas": 80 } }
```

#### Tombstone
```jsonc
{ "entidad": "pista|album|artista|playlist", "entidad_id": 7, "sync_version": 41 }
```
Aplica el borrado local de la entidad indicada. Los tombstones **siempre**
viajan (incluso con selección `nada`), para propagar borrados.

### 4.4 Selección por dispositivo (qué se sincroniza) — negociable desde el móvil
El PC persiste una `selección` por dispositivo y **filtra el manifest** según
ella. El **móvil la negocia** con los endpoints de selección (también se puede
ajustar desde la UI del PC). Esquema:
```jsonc
{ "modo": "todo" }                                   // default: todo
{ "modo": "nada" }                                   // solo tombstones + versión
{ "modo": "artistas", "artista_ids": [5, 9] }        // pistas/álbumes/artistas de esos ids; sin playlists
{ "modo": "playlists", "playlist_ids": [2, 4] }      // esas playlists + sus pistas (+ álbumes/artistas referenciados)
```

**`GET /api/v1/seleccion`**
```jsonc
200 → { "seleccion": { "modo": "todo" } }   // la actual del device (default todo)
```

**`POST /api/v1/seleccion`** (cuerpo = la selección, con o sin envoltorio `seleccion`)
```jsonc
// request
{ "seleccion": { "modo": "artistas", "artista_ids": [5, 9] } }
// 200
{ "ok": true, "seleccion": { "modo": "artistas", "artista_ids": [5, 9] } }
// 400 → { "error": "modo_invalido" }   (modo ∉ {todo,nada,artistas,playlists})
```
Tras un `POST /seleccion`, las siguientes llamadas a `/manifest` ya vienen
filtradas. Flujo móvil típico: el usuario elige qué sincronizar en la UI del
teléfono → `POST /seleccion` → el cliente reinicia el delta con `since=0` si
amplió el alcance (para traer lo que antes filtraba). Los **stems** son opt-in
aparte (se piden por su endpoint; nunca viajan en el manifest).

> **Selección de sync vs. descarga offline son dos capas distintas.** La
> selección decide qué **metadata** entra al catálogo del móvil; qué **audio**
> se descarga para offline es una segunda elección del móvil (cola de
> descargas por pista/álbum/playlist), que solo consume `/track/{id}/audio`.

### 4.5 `GET /api/v1/track/{id}/audio` — descarga con Range
- Sin `Range`: `200` con el archivo completo.
- Con `Range: bytes=<inicio>-<fin?>`: **`206 Partial Content`** (reanudable).
- Header de respuesta **`X-NB-Sound-Hash: <sha256>`** (igual que `hash_sha256`
  del manifest). Al completar, valida el sha256 del archivo reensamblado.
- `404 { "error": "no_encontrado" }` si la pista o el archivo no existen.

### 4.6 `GET /api/v1/asset/{tipo}/{id}`
- `tipo` = `cover` o `album` → portada del álbum `{id}`.
- `tipo` = `artist` → imagen del artista `{id}`.
- Respuesta: el archivo de imagen (con cabeceras de caché de `aiohttp`
  FileResponse: `Last-Modified` / `If-Modified-Since`). `404` si no hay imagen.

### 4.7 `GET /api/v1/track/{id}/lyrics`
```jsonc
200 → { "synced_lyrics": "[00:01.00] ...", "plain_lyrics": "..." }  // alguno puede ir vacío
404 → { "error": "sin_lyrics" }
```
`synced_lyrics` es LRC con marcas de tiempo (si existe); `plain_lyrics` es texto.

### 4.8 `GET /api/v1/track/{id}/stems` (opt-in)
- `200` con el archivo instrumental si la pista tiene karaoke generado.
- `404 { "error": "sin_stems" }` si no. Soporta `Range` (reanudable).
- El PC registra el estado de transferencia por dispositivo/pista
  (`pending|in_progress|done|failed`).

### 4.9 `POST /api/v1/history` — subir historial y favoritos
Request:
```jsonc
{
  "historial": [
    { "pista_id": 123, "reproducido_en": "2026-05-30T10:00:00.000Z",
      "duracion_seg": 200.0, "completada": true }    // duracion_seg/completada opcionales
  ],
  "favoritos": [
    { "pista_id": 123, "favorita": true, "actualizada_en": "2026-05-30T10:00:00.000Z" }
  ]
}
```
Response:
```jsonc
200 → { "ok": true, "historial_insertado": 1, "favoritos_aplicados": 1, "favoritos_ignorados": 0 }
```
**Merge de favoritos (last-write-wins)**: el favorito del móvil gana solo si su
`actualizada_en` es **estrictamente más reciente** que el
`favorita_actualizada_en` del PC. Sin timestamp remoto, no se pisa el PC
(cuenta como `ignorado`). El historial se inserta siempre (append).

---

## 5. WebSocket `/api/v1/control` (control remoto, Spotify Connect)

Conexión: `ws://{host}:{puerto}/api/v1/control` con header
`Authorization: Bearer <device_token>`. Mensajes JSON con campo `tipo`.

### 5.1 Estado que publica el PC (push → móvil)
Al conectar recibes un primer frame de estado, y luego uno por cada cambio del
reproductor del PC. **Esquema plano**:
```jsonc
{
  "tipo": "estado",
  "reproduciendo": true,
  "pista": {                       // null si no hay pista activa
    "id": 123,
    "titulo": "One More Time",
    "artista": "Daft Punk",
    "album": "Discovery",
    "duracion_seg": 320.4,
    "cover_url": "/api/v1/asset/cover/10"   // relativa; null si sin álbum
  },
  "posicion_seg": 42.3,
  "volumen": 80,
  "modo_repeticion": "ninguno",    // "ninguno" | "uno" | "todo" (enum ModoRepeticion del PC)
  "aleatorio": false,
  "karaoke_activo": false,
  "karaoke_disponible": false,     // la pista en curso tiene instrumental listo
  "indice_cola": 4,
  "dj_activo": false               // true si hay sesión DJ Privado (el PC tiene el
                                   // control global; el móvil bloquea sus comandos)
}
```
> **`modo_repeticion`** usa el vocabulario AS-BUILT del enum `ModoRepeticion` del PC
> (`servicios/reproductor.py`): `ninguno` | `uno` | `todo`. El PC valida el comando
> `repeat` contra estos valores y **descarta** los desconocidos, así que el móvil
> debe enviarlos y compararlos tal cual (no `una`/`todas`).
> `karaoke_disponible` es **aditivo**: si el PC no lo envía (versión vieja) el móvil
> asume `true` (botón usable como antes; el PC ignora el toggle si no hay stems).
> Cuando es `false` (sin pista o sin instrumental listo) el móvil deshabilita el
> botón de karaoke. Se refresca con `karaokeCambiado` (cableado a un push de estado).
> `dj_activo` es **aditivo**: si el PC no lo envía (versión vieja) el móvil asume
> `false`. Cuando es `true`, el cliente muestra "DJ Privado en sesión" y deshabilita
> los controles hasta que la sesión termine (el PC vuelve a responder a comandos).

### 5.2 Comandos que envía el móvil (móvil → PC)
**Esquema canónico**: `{ "tipo": "comando", "accion": "<accion>", ...args }`.
(Por compatibilidad también se acepta `comando` en vez de `accion`.)

| `accion` | Args | Efecto en el PC |
| --- | --- | --- |
| `play_pause` | — | alterna reproducir/pausar |
| `next` | — | siguiente |
| `prev` | — | anterior |
| `stop` | — | detener |
| `seek` | `{ "posicion_seg": 90.0 }` | salta a la posición |
| `set_volume` | `{ "volumen": 70 }` | volumen 0–100 |
| `play_index` | `{ "indice": 3 }` | reproduce el ítem N de la cola |
| `repeat` | `{ "modo": "ninguno|uno|todo" }` | modo de repetición (valores del enum del PC; otros se descartan) |
| `shuffle` | `{ "activo": true }` | aleatorio on/off |
| `queue` | — | el PC responde con un frame `cola` (ver 5.4) |
| `karaoke` | — | alterna el instrumental (karaoke) de la pista en curso |
| `set_queue` | `{ "ids": [3,1,2], "indice": 1, "posicion_seg": 0 }` | **cola espejada**: reemplaza la cola del PC por esas pistas (ids de biblioteca) y reproduce el índice dado. `posicion_seg` es **opcional** (> 0): tras cargar la cola, el PC salta a esa posición — se usa en el handoff con cola completa (al pasar el control del móvil al PC) para conservar dónde iba la pista |
| `move_queue` | `{ "desde": 0, "hasta": 2 }` | reordena un ítem de la cola del PC |
| `remove_queue` | `{ "indice": 1 }` | quita el ítem N de la cola del PC |
| `clear_queue` | — | vacía la cola del PC manteniendo la pista en curso |
| `reproducir_pista` | `{ "pista_id": 7, "posicion_seg": 0 }` | handoff: reproduce esa pista en el PC (saltando a la posición) |
| `encolar_pista` | `{ "pista_id": 7 }` | encola esa pista en el PC (añade al final) |

Por cada comando el PC responde un **ack**:
```jsonc
{ "tipo": "ack", "accion": "play_pause", "resultado": { "ok": true, "encolado": true } }
```
> `encolado: true` significa que el comando se entregó al reproductor (se
> ejecuta en el hilo de Qt del PC). El **estado autoritativo** llega después en
> un frame `estado`; aplica optimismo y corrige con ese frame.

### 5.3 Errores WS
```jsonc
{ "tipo": "error", "detalle": "json_invalido" }
```

### 5.4 Frame de cola (respuesta a `queue` y **push automático**)
```jsonc
{ "tipo": "cola",
  "items": [ { "id": 123, "titulo": "...", "artista": "...", "album": "...", "duracion_seg": 320.4 } ],
  "indice": 4 }
```
El PC publica este frame **ante cada cambio de la cola** (no solo cuando el móvil
envía `queue`), por broadcast a todos los clientes WS, para que la **cola espejada**
del móvil se mantenga en vivo. Al conectar, el cliente envía un `queue` para poblarla
de inmediato.

---

## 6. Semántica de `sync_version` y tombstones (lado PC)

- Contador **global monotónico** (`sync_estado.sync_version_actual`). Cada
  cambio de una entidad sincronizable le asigna la siguiente versión global.
- El PC incrementa `sync_version` al: indexar/actualizar pistas, crear
  álbumes/artistas, y marcar favoritos (`toggle_favorita` además sella
  `favorita_actualizada_en`).
- Los **borrados** generan un `tombstone` (id + tipo + versión); no se detectan
  por `sync_version` de la fila (ya no existe).
- El móvil **no inventa** `sync_version`: la trata como opaca/creciente y solo
  guarda el `sync_version_actual` del último manifest aplicado.

---

## 7. Reglas de autoridad (merge)

| Dato | Quién manda | Nota |
| --- | --- | --- |
| Metadata (título, artista, álbum, portada, lyrics, features, playlists) | **PC** | read-only en el móvil |
| Historial de reproducción | **Móvil** | append vía `POST /history` |
| Favoritos | **Última escritura** | por `actualizada_en` / `favorita_actualizada_en` |

---

## 8. Backup (informativo, no afecta al móvil)

El PC puede exportar/restaurar un `.nbsound-backup` (ZIP: `db.sqlite3` +
`assets/` + `manifest.json` con checksums). Es independiente del protocolo de
sync; el móvil no lo consume.

---

## 9. Estado de implementación y notas para el móvil

**Implementado y probado en el PC (v1.1.0) — sin faltantes del lado PC:**
todos los endpoints de la sección 4, el WS de la sección 5 (estado plano +
acciones + cola), **TLS/HTTPS+WSS con huella TOFU** (sección 1/3), **selección
negociable desde el móvil** (4.4), **paginación del manifest** (4.3), lyrics
(4.7) e imagen de artista (4.8 `artist`). El PC **no tiene trabajo pendiente**
para soportar el cliente móvil.

**Lo único que podría cambiar** es lo que el propio desarrollo Flutter pida
durante la integración (p. ej. ajustar nombres de campos, añadir un campo
nuevo, o afinar tamaños de página). Esos cambios son **aditivos y
retrocompatibles** por diseño.

**Notas de implementación:**
- **`queue` consulta**: el PC publica el frame `cola` por broadcast a los
  clientes WS conectados (no es una respuesta dirigida a un solo socket).
- **TLS sin CA**: el certificado es autofirmado y persistido; la confianza es
  por **huella** (TOFU), no por cadena de CA ni hostname. El cliente debe
  validar comparando el SHA-256 del cert presentado contra el fijado del QR.
- **Degradación**: si el PC no tuviera `cryptography`, `tls=false` y se habla
  plano; el release oficial sí incluye TLS.

**Tolerancia a cambios**: el PC puede añadir campos nuevos sin romper el
contrato; el cliente debe **ignorar campos desconocidos** (json_serializable
con campos opcionales). Un salto incompatible se reflejaría en `version` /
`version_protocolo` (hoy `1`).

---

← [architecture.md](architecture.md) · [sync-protocol.md](sync-protocol.md) ·
[remote-control.md](remote-control.md) · [local-data.md](local-data.md) ·
PC: `../../nb_sound/docs/mobile-ecosystem.md`
