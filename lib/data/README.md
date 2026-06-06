# data/

Capa de datos compartida entre features:

- `db/` — esquema Drift (tablas locales: pistas, álbumes, artistas,
  playlists, historial, favoritos, estado de sync). Ver `../../docs/local-data.md`.
- `models/` — DTOs del protocolo de sync (freezed + json_serializable),
  espejo del payload definido por el PC en `../nb_sound/docs/mobile-ecosystem.md`.
- `sources/` — fuentes de datos: `local` (Drift) y `remote` (dio/WS).
- `repositories/` — repositorios que combinan local+remoto y aplican las
  reglas de merge (PC gana en metadata; celular gana en historial/favoritos).
