# Auditoría de paridad con Spotify — checklist por fases

Inventario **completo** del comportamiento de la app contrastado con
Spotify/Apple Music/Tidal/Deezer, con estado de implementación. Se actualiza a
medida que se completa cada punto.

**Excluido por decisión del usuario:** descargas/offline, modelo de biblioteca
local del PC, letra plana (solo sincronizada), y todo lo de conexión/sync/pairing
con el escritorio. El **Connect/control remoto** SÍ está en alcance (feature de
usuario estilo Spotify Connect).

**Objetivo de calidad:** multiplataforma pulida (Android, iOS, tablets Android,
iPad, Chromebooks), mínima fricción, responsive de primer nivel y rendimiento de
primer nivel. Cada fase: `flutter analyze` limpio + tests verdes + APK arm64. La
validación física la hace el usuario.

Severidad: 🔴 grave · 🟡 medio · ⚪ menor. Estado: ✅ hecho · ⏳ en curso · ☐ pendiente.

> Última actualización: 2026-06-10. Base: Fase 5 (bloque 🔴 inicial) ya hecha.

## Reproductor, cola y sesión

| ID | Mejora | Sev. | Estado |
|----|--------|------|--------|
| P1 | Enrutar play a local/PC con Connect (fachada) | 🔴 | ✅ (F5) |
| P2 | Cola manipulable: añadir, reproducir a continuación, reordenar, quitar | 🔴 | ✅ (F5) |
| P3 | Navegación desde el reproductor (álbum/artista) + botón ⋮ | 🔴 | ✅ (F5) |
| P4 | Acceso a Connect fuera del reproductor (mini-player + General) | 🔴 | ✅ (F5) |
| P5 | **Persistencia de sesión** (cola + índice + posición) al cerrar/abrir | 🔴 | ✅ (F6) |
| P6 | Autoplay/"radio" al terminar la cola | 🔴 | ✅ (F8) |
| P7 | Cerrar el reproductor con swipe-down | 🟡 | ✅ (F7) |
| P8 | Tocar línea de letra = seek a ese punto | 🟡 | ✅ (F7) |
| P9 | Gestos del mini-player (deslizar cambia / arriba abre) | 🟡 | ✅ (F9) |
| P10 | Encabezado "En cola" en la vista de cola | ⚪ | ✅ (F7) |
| P11 | Borrar cola + añadir álbum/playlist entera a la cola | ⚪ | ✅ (F10) |
| P12 | Sleep timer | ⚪ | ✅ (F10) |
| P13 | Acción de favorito en la notificación/lockscreen | 🟡 | ✅ (F10) |
| P14 | Velocidad de reproducción | ⚪ | ✅ (F10) |

## Búsqueda e Inicio

| ID | Mejora | Sev. | Estado |
|----|--------|------|--------|
| S1 | Playlists en los resultados de búsqueda | 🔴 | ✅ (F9) |
| S2 | Búsquedas recientes (guardar/borrar) | 🟡 | ✅ (F9) |
| S3 | Estado "Explorar" (recientes + artistas/álbumes) cuando vacío | 🟡 | ✅ (F9) |
| S4 | Tocar canción en resultados continúa con la lista | 🟡 | ✅ (F9) |
| S5 | Chips de filtro por tipo en resultados | ⚪ | ✅ (F10) |
| S6 | Tarjeta "Mejor resultado" destacada | ⚪ | ✅ (F10) |
| H1 | Saludo por hora en Inicio | 🟡 | ✅ (F9) |
| H2 | Rejilla de accesos rápidos (Tus me gusta + playlists) | 🟡 | ✅ (F9) |

## Biblioteca, álbum, artista, playlists

| ID | Mejora | Sev. | Estado |
|----|--------|------|--------|
| A1 | Botón Reproducir/Aleatorio en la página de artista | 🔴 | ✅ (F7) |
| A2 | "Populares" del artista por reproducciones (no alfabético) | 🟡 | ✅ (F7) |
| A3 | Artista enlazado en la cabecera del álbum | 🟡 | ✅ (F7) |
| L1 | "Tus me gusta" como colección navegable de primera clase | 🟡 | ✅ (F9) |
| L2 | Tocar canción en pestaña Pistas continúa la lista | 🟡 | ✅ (F7) |
| PL1 | Menú ⋮ en filas de playlist local (con "quitar") | 🟡 | ✅ (F7) |
| PL2 | Botón Aleatorio en playlists (PC y local) | 🟡 | ✅ (F7) |
| PL3 | Editar descripción de playlist local | ⚪ | ✅ (F10) |
| PL4 | Permitir pistas duplicadas en playlist local | ⚪ | ✅ (decisión: no, por PK) |

## Ajustes, perfil, sistema, transversal

| ID | Mejora | Sev. | Estado |
|----|--------|------|--------|
| G1 | Avatar de perfil real en el TopBar | 🟡 | ✅ (F10) |
| G2 | Guardar presets de ecualizador con nombre | ⚪ | ✅ (F10) |
| G3 | Limpiar código muerto (`ThemeController.cycle`, `CatalogDao.buscarPistas`) | ⚪ | ✅ (F10) |
| X1 | Gestos en filas (deslizar para encolar a la cola) | ⚪ | ✅ (F10) |

## Optimización y multiplataforma (transversal, continuo)

| ID | Mejora | Estado |
|----|--------|--------|
| O1 | Rendimiento: const, rebuilds mínimos, listas lazy, decodificación de imágenes acotada | ✅ |
| O2 | Responsive de primer nivel (teléfono/tablet/iPad/Chromebook/landscape) | ✅ |
| O3 | iOS/iPad: código cross-platform listo (EQ con guard Android; resto portable). Falta macOS para compilar/validar | ⏳ |
| O4 | Arranque y memoria: providers `select`, evitar trabajo en build, dispose correcto | ✅ |

---

## Registro por fases

### Fase 6 — Persistencia de sesión del reproductor ✅
Guarda la cola (ids), el índice y la posición en kv (`SyncStateDao.kSesion`,
JSON) y los restaura al abrir la app **en pausa** (como Spotify). Se guarda al
cambiar de pista/cola y al pasar a segundo plano; shuffle/repeat ya persistían.
Resolución de ids en una sola consulta (`CatalogDao.getPistasPorIds`).

### Fase 7 — Reproductor, álbum, artista, playlists ✅
- **Artista (A1, A2):** botón Reproducir/Aleatorio en la cabecera; pistas
  ordenadas por **popularidad** (`pistasPorPopularidad` + `conteoPorPistaProvider`
  / `HistoryDao.watchConteoPorPista`), sección "Populares".
- **Álbum (A3):** nombre del artista enlazado a su página.
- **Playlists (PL1, PL2):** botón Aleatorio en playlist del PC y local; filas de
  playlist local con menú ⋮ (`mostrarMenuPista` con acción "Quitar de la playlist"
  vía `accionRemover`).
- **Biblioteca (L2):** tocar una canción en la pestaña Pistas reproduce la lista.
- **Reproductor (P7, P8, P11, P10-parcial):** cerrar con swipe-down (portada y
  cabecera); tocar una línea de letra salta a ese momento (`buscarPosicion`);
  modo inmersivo de letra movido a mantener-pulsado; vista Cola con encabezado
  "En cola" y "Borrar cola" (`limpiarCola`).

### Fase 8 — Autoplay ✅
Al acabar la cola sin repetición, se extiende con "radio" local
(`generarAutoplay` puro: mismo artista → género → resto; `_quizaAutoplay` /
`_extenderAutoplay` en el controller). Tests `autoplay_test`.

### Fase 9 — Búsqueda + Inicio ✅
- **Búsqueda (S1–S4):** playlists en resultados (`PlaylistBusq` /
  `playlistIndexProvider`, `ordenarSecciones` con 4 secciones); búsquedas
  recientes persistidas (`busquedasRecientesProvider`, kv `kBusquedasRecientes`)
  con borrar individual/total; estado vacío con recientes + "Explora tu
  biblioteca" (artistas + álbumes); tocar una canción reproduce la lista de
  resultados.
- **Inicio (H1, H2):** saludo por hora (`saludoPorHora`); rejilla de accesos
  rápidos (`_QuickPicks`: "Tus me gusta" + tus playlists); "Tus favoritas" con
  enlace "Ver todas".
- **"Tus me gusta" (L1):** `FavoritasScreen` (`/favoritas`, en el grupo de detalle
  con mini-player) con Reproducir/Aleatorio + lista de favoritas.
- Tests: `saludo_test`, `search_orden_test` ampliado.

### Fase 10 — Cierre: ajustes, perfil, sistema y optimización ✅
Completa **todos** los puntos restantes del checklist.
- **G3:** eliminados `ThemeController.cycle` y `CatalogDao.buscarPistas` (código
  muerto).
- **P14 + P12:** velocidad de reproducción (`setSpeed`/`PlayerState.velocidad`) y
  sleep timer (`sleep_timer.dart`), accesibles desde el menú ⋮ del reproductor
  (`mostrarMenuPista(ajustesReproductor: true)`).
- **G1:** avatar de perfil real en el TopBar (`inicialPerfilProvider`,
  `TopBar.avatarInicial`).
- **S5 + S6:** chips de filtro por tipo en la búsqueda + tarjeta "Mejor resultado".
- **P11:** "Borrar cola" (`limpiarCola`) y "Añadir a la cola" de una colección
  entera (`encolarColeccion` en controller + fachada; `mostrarMenuColeccion` en el
  ⋮ de álbum/playlist).
- **X1:** deslizar una fila de pista a la derecha la añade a la cola (`Dismissible`
  en `TrackRow`).
- **P13:** botón de favorito en la notificación/lockscreen (`MediaControl.custom` +
  drawables `ic_fav`/`ic_fav_filled`; `customAction('favorito')`; refresco al
  cambiar de pista o favoritos).
- **PL3:** descripción de playlist local (schema Drift **v5** aditivo:
  `PlaylistsLocales.descripcion`; `editarDetallesPlaylist`).
- **G2:** presets de ecualizador guardados por nombre (kv `eq_custom`;
  `guardarPreset`/`aplicarPresetGuardado`/`borrarPresetGuardado`).
- **PL4 (decisión):** las playlists locales **no** permiten pistas duplicadas (la
  PK `(playlistId, pistaId)` lo garantiza), como la mayoría de apps de biblioteca.
  Soportar duplicados exigiría rehacer la tabla con `rowid` y el reordenado por
  fila; se evita por robustez. Reabrir como tarea propia si se desea.
- **O1/O2/O4:** el código ya estaba en estándar alto (analyze limpio, `dart fix`
  sin cambios, listas lazy `*.builder`, `ResizeImage`/`cacheWidth`, providers con
  `select`, full-width responsive con `gridColumns`/`cardScale`/`countFor`).
- **O3 (iOS/iPad):** código portable; el ecualizador degrada con aviso fuera de
  Android. Falta un macOS para compilar/validar iOS (fuera de este entorno).
