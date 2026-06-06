# features/

Organización feature-first. Cada feature es autocontenida con su capa de
presentación (widgets/pantallas + providers) y su lógica de aplicación,
apoyándose en `data/` y `core/`.

- `library/` — navegación del catálogo: artistas, álbumes, pistas, búsqueda y
  detalle. Datos sincronizados desde el PC (read-only en metadata).
- `player/` — reproductor local (just_audio + audio_service): cola, controles,
  reproducción en background y desde pantalla de bloqueo.
- `sync/` — descubrimiento del PC (escaneo de QR + mDNS), handshake/pairing,
  y sincronización delta (manifest `since`). Ver `../../docs/sync-protocol.md`.
- `remote_control/` — cuando el PC está conectado: control bidireccional del
  reproductor del PC por WebSocket. Ver `../../docs/remote-control.md`.
- `offline/` — selección, descarga (con reanudación por Range) y gestión del
  audio almacenado para escucha sin conexión.
