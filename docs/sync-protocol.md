# Cliente del protocolo de sincronización

> **Contrato as-built (fuente de verdad): [`pc-contract.md`](pc-contract.md).**
> Ese documento refleja el protocolo EXACTO ya implementado y probado en la app
> de escritorio (v1.1.0). Si algo aquí difiere, manda `pc-contract.md`.

Lado **móvil** del protocolo. La especificación canónica (endpoints, schema
del payload, reglas de merge, seguridad) la define el PC en
`../../nb_sound/docs/mobile-ecosystem.md`. Este documento describe cómo el
cliente Flutter lo consume.

> **As-built:** emparejamiento en `lib/features/sync/data/{pairing_repository,
> qr_payload,discovery_service}.dart` (Bloque 2); sync delta + subida en
> `sync_repository.dart` (Bloque 3); pinning TLS en `lib/core/network/`.
> **Testeado contra simulaciones, aún no contra el PC real** — ver
> [`app-state.md`](app-state.md).

## Transporte

- **HTTP (dio)** para handshake, manifest delta y descargas.
- **WebSocket (web_socket_channel)** para control remoto (ver
  [`remote-control.md`](remote-control.md)).
- **mDNS (nsd)** para redescubrir el PC ya emparejado (`_nbsound._tcp`).

Todas las llamadas HTTP llevan `Authorization: Bearer <device_token>` (excepto
`/pair`, que usa el token efímero del QR). Un interceptor de dio inyecta el
token y maneja 401 (token revocado → volver a emparejar).

## Emparejamiento

1. Escanear QR (`mobile_scanner`) → `{host, puerto, token, tls_fingerprint, version}`.
2. Fijar el `tls_fingerprint` (TOFU) en el cliente HTTP.
3. `POST /api/v1/pair` con `{token, nombre_dispositivo, plataforma}`.
4. Guardar el `device_token` devuelto + el fingerprint en almacenamiento
   seguro (ver [`local-data.md`](local-data.md)).

## Sincronización delta

```text
estado local: ultima_sync_version (entero, persistido)
GET /api/v1/manifest?since=<ultima_sync_version>
  → { sync_version_actual, pistas[], albums[], artistas[], playlists[],
      perfil, tombstones[] }
aplicar en una transacción Drift:
  - upsert de entidades recibidas (PC gana en metadata)
  - aplicar tombstones (borrar local lo eliminado en PC)
  - guardar ultima_sync_version = sync_version_actual
subir cambios locales:
  POST /api/v1/history  → { historial[], favoritos[] (con timestamp) }
```

- **Reanudable**: si la sync se corta, se reintenta con el mismo `since=`; la
  aplicación es idempotente (upsert por id).
- **Atómica por lote**: el manifest se aplica en una transacción; si falla, no
  se avanza `ultima_sync_version`.

## Reglas de merge (cliente)

| Dato | Quién gana | Cómo lo aplica el cliente |
| --- | --- | --- |
| Metadata (título, artista, álbum, portada, lyrics, features) | **PC** | upsert read-only; no se editan localmente |
| Historial de reproducción | **Celular** | se acumula local y se sube (append) |
| Favoritos | **Última escritura** | compara `favorita_actualizada_en`; sube el más nuevo, acepta el del PC si es posterior |
| Playlists manuales | **PC** | read-only en v1 (edición desde PC) |

## Descarga de audio y assets (offline)

```text
GET /api/v1/track/{id}/audio   (Header: Range: bytes=<offset>-)
  → 206 Partial Content
guardar incrementalmente; al completar, validar crypto.sha256 == hash_sha256
GET /api/v1/asset/{tipo}/{id}  (ETag para cache)
GET /api/v1/track/{id}/stems   (opt-in; estado de transferencia reanudable)
```

- La descarga usa `Range` para **reanudar** tras cortes; el `hash_sha256`
  (campo del manifest) valida integridad.
- El estado de cada descarga se persiste local (cola de transferencias).

## Versión de protocolo

El cliente envía/lee `version`. Si el PC anuncia una versión mayor
incompatible, la app pide actualizar. Cambios aditivos (campos nuevos) se
ignoran con tolerancia (json_serializable con `includeIfNull`/desconocidos
ignorados).

## Errores y degradación

- Sin PC en la red → modo local puro (no error; banner informativo).
- 401 → token revocado → flujo de re-emparejamiento.
- Timeout/corte → reintento con backoff; las descargas reanudan por Range.
