# Rediseño estilo Spotify — registro por fases

Reescritura amplia de la app (estética y funcionalidad más "Spotify"), pedida en
12 áreas y entregada **por fases**. Cada fase deja `flutter analyze` limpio + tests
verdes + APK de release, para validar en dispositivo antes de seguir.

**Última actualización:** 2026-06-09. Fases 1–3 code-complete. Fase 4 pendiente.

> **Estado de verificación (importante, no sobre-vender):** todo lo de las Fases
> 1–3 está **code-complete y validado por análisis estático + tests unitarios +
> build de release**, pero **NO verificado visualmente en dispositivo/Chromebook**
> (el emulador es inestable en sesiones automatizadas; el usuario valida en su
> Chromebook). **No hay commit** (no se ha pedido). Tests: **125 verdes**. APKs
> firmados en `dist/` (universal + arm64-v8a + armeabi-v7a).

## Decisiones tomadas con el usuario

- Orden de entrega: **F1 Fundamentos+Reproductor → F2 Inicio+Búsqueda → F3
  Biblioteca+Playlists → F4 Ajustes**.
- Ecualizador (F4): **Android primero**; iOS después. Motivo: en `just_audio` los
  efectos `AndroidEqualizer`/`AndroidLoudnessEnhancer`/`setSkipSilenceEnabled` solo
  existen en Android; iOS requeriría AVAudioEngine no expuesto por la librería.
- Sin cambios de esquema Drift en F1–F3 (todo el estado nuevo es kv en `SyncEstado`).

---

## Fase 1 — Fundamentos + Reproductor ✅ (code-complete)

### Qué se hizo
- **Responsive** (`lib/shared/util/responsive.dart`, reescrito): breakpoints `Bp`
  (compact <600 / medium / expanded ≥1024), `gridColumns` (+6 columnas ≥1280),
  `contentMaxWidthFor`, `uiScaleFor`, extensión `context.{bp,isWide,contentMaxWidth,
  uiScale}` y widget `MaxWidth` (centra y acota el contenido de una columna en
  pantallas anchas; en teléfono es passthrough). Aplicado a búsqueda, inicio y los 4
  detalles.
- **Títulos/subtítulos más grandes**: subidos en `TopBar`/`SectionHead`/`SubHeader`
  (escalados por `uiScale`). Nuevo `shared/widgets/section_label.dart` (`SectionLabel`)
  que unifica los rótulos de sección (APARIENCIA, DISPOSITIVO, TUS PLAYLISTS, DEL PC),
  antes a 11px sueltos.
- **Mini-reproductor**: botón **anterior** añadido. Nuevo
  `shared/widgets/mini_player_bar.dart` (`MiniPlayerBar`, cableado a `nowPlaying`/
  `playbackActions`). Ahora aparece también en los detalles (álbum/artista/playlist)
  vía un `ShellRoute` en `app_router.dart`.
- **Estado global de aleatorio/repetir persistido**: claves kv `kAleatorio`/
  `kRepeticion`; restaurado en `main.dart` (override `initialShuffleProvider`/
  `initialRepeatProvider`), aplicado en `PlayerController.build`, persistido en cada
  toggle. **Cola en orden aleatorio real**: el handler expone `effectiveOrderStream`
  (`just_audio.effectiveIndices`); `PlayerState.order` + helper puro `ordenEfectivo`.
- **Reproductor UI**: botones descargar/karaoke/me-gusta más pequeños (20px, compact);
  nuevo `shared/widgets/auto_fit_text.dart` (`AutoFitText`) para título/álbum/letra;
  **letra a pantalla completa** (toca la letra → oculta cabecera/controles).
- **Estado de conexión real**: `features/sync/application/conexion_provider.dart`
  (`ConexionEstado{sinEnlace,desconectado,conectado}`, `conexionEstadoDe` puro,
  `pcAlcanzableProvider` que sondea `/ping`, `conexionPcProvider`). El reproductor
  **oculta "Mi PC"** salvo `conectado`.
- **Notificación con portada**: `localCoverFor`/`setCurrentArt` en el handler +
  `DownloadRepository.ensureCover` + `PlayerController._ensureArtwork` (al cambiar de
  pista).

### Cambios/tradeoffs hechos para conseguirlo
- **Mini-reproductor: se quitó el texto de tiempo** (`positionLabel`/`durationLabel`)
  para que cupieran 3 controles (anterior/play/siguiente) compactos. Las props se
  eliminaron del widget `MiniPlayer` y del call-site de `AppShell`. (Más "Spotify": el
  mini ya no muestra `m:ss / m:ss`.)
- **"Mi PC" ahora exige PC alcanzable**, no solo emparejado. Efecto colateral: desde
  el reproductor local, con el PC desconectado, **no se puede abrir la hoja de
  destino** (el botón cast se oculta). Es lo pedido ("no debería aparecer Mi PC sin
  enlace"), pero conviene recordarlo.
- **Título/álbum del reproductor ya no usan clamp de 1 línea**: `AutoFitText` reduce
  la fuente hasta un piso y, si hace falta, envuelve a 2 líneas. La línea de letra
  activa subió su `itemExtent` 50→58 y usa `AutoFitText` (puede ocupar 2 líneas).
- **Modo inmersivo de letra**: se introduce el estado `_immersive`; se **resetea al
  cambiar de pestaña** (Portada/Cola) para no quedar atrapado.
- **Notificación**: para mostrar carátula en streaming se **materializa** (descarga
  ligera) la portada del álbum a `covers/{albumId}.img` la primera vez que suena la
  pista (la auth de `/api` no llega al sistema, así que solo sirve un archivo local).
  Efecto secundario **positivo**: también acelera las portadas in-app (quedan
  cacheadas). Coste: una petición pequeña por pista la primera vez.
- **Router**: los 4 detalles pasaron de `GoRoute` directos en root a un `ShellRoute`
  (`_DetailWithMiniPlayer`) que pone `Column[Expanded(detalle), MiniPlayerBar]`. Para
  no dejar hueco doble, cuando hay pista sonando **se pone a 0 el `padding.bottom` del
  `MediaQuery`** del detalle (cede el inset del sistema a la barra). Detalle envuelto
  además en `MaxWidth` (se centra en pantallas anchas).
- Se **borraron** las clases privadas `_Section` (profile) y `_Header` (playlists),
  reemplazadas por `SectionLabel`.

### Completo
Responsive base, títulos grandes, mini con anterior + presente en detalles, aleatorio/
repetir global persistido, cola en orden real, botones pequeños, título/álbum sin
clamp, letra a pantalla completa, ocultar "Mi PC" sin conexión, notificación con
portada. Tests: `orden_efectivo_test`, `conexion_estado_test`, `responsive_test`.

### Faltante / no abordado en F1
- Verificación visual en dispositivo (mini sin tapar la última pista, letra inmersiva,
  notificación con portada real, "Mi PC" oculto).
- La notificación podría mejorarse aún más (acciones, estilo) — se dejó funcional.
- Responsive no auditado pantalla por pantalla en `sync`/`descargas`/`profile` (se
  tocarán en F4).

---

## Fase 2 — Inicio dinámico + Búsqueda difusa ✅ (code-complete)

### Qué se hizo
- **Búsqueda difusa** (en memoria, tolerante a typos/acentos): núcleo puro
  `lib/core/search/fuzzy.dart` (`normalizar`, `distanciaAcotada` = Levenshtein con
  banda, `puntuarTexto` con ranking, `maxDistPara`). Providers en
  `search_providers.dart`: índices normalizados (recalculados solo al cambiar el
  catálogo) y `resultadosBusquedaProvider` (`ResultadosBusqueda{artistas,albums,
  pistas}`). `buscar_screen.dart` reescrita: debounce 90ms, resultados en **artistas
  (círculos) + álbumes + canciones**. Nuevo widget `ArtistCircle`.
- **Inicio dinámico** (`inicio_screen.dart` reescrito): secciones condicionales que
  reflejan gustos + selecciones — Vuelve a tu música, Escuchas a menudo, Tus
  favoritas, Artistas para ti (círculos), Novedades, Explora (cuadrícula), Clásicos,
  Tus playlists. Helpers `_TrackRail`/`_AlbumRail`/`_ArtistRail`/`_AlbumGrid`/
  `_PlaylistRail`.
- **DAO** (`history_dao.dart`, sin codegen): `watchMasEscuchadas`,
  `watchConteoPorArtista`. Providers: `masEscuchadasProvider`, `topArtistasProvider`,
  `novedadesAlbumsProvider`, `clasicosAlbumsProvider`.

### Cambios/tradeoffs
- **Se ELIMINÓ el `resultadosBusquedaProvider` viejo** (StreamProvider con SQL `LIKE`)
  de `library_providers.dart`; la búsqueda pasó a ser **en memoria** (Provider). El
  método `CatalogDao.buscarPistas` (SQL) **quedó sin uso** (se dejó en el DAO; candidato
  a borrar). Motivo: el SQL no tolera errores; el scoring en memoria sí, y se mantiene
  rápido normalizando una sola vez en los índices.
- **La búsqueda ahora tiene debounce de 90ms** (antes era instantánea). Imperceptible y
  evita recalcular en cada pulsación.
- **Inicio envuelto en `MaxWidth`**: en pantallas anchas el `TopBar` y todo el inicio
  se centran (cambio visual menor respecto al ancho completo anterior).
- `topArtistasProvider`: si **no hay historial** (teléfono nuevo) cae a una muestra del
  catálogo para que la sección no quede vacía.

### Completo
Búsqueda difusa multi-tipo con ranking, inicio largo y dinámico. Tests: `fuzzy_test`
(12) + caso de agregados en `dao_test`.

### Faltante / no abordado en F2
- Verificación visual (rapidez real con catálogo grande, look de las secciones).
- No se añadieron secciones "por género/mood" ni "tops globales" (el catálogo no trae
  esa señal de forma fiable); se priorizó historial/favoritos/año.

---

## Fase 3 — Biblioteca + Playlists ✅ (code-complete)

### Qué se hizo
- **Portadas de playlist sin repetición + carga optimizada**: puro
  `playlist_covers.dart::portadasDistintas` (≤4 coverPaths distintos, salta
  repetidas/vacías; todas iguales ⇒ 1 sola). Aplicado en tarjetas y detalles; ahora se
  resuelven **solo ≤4 imágenes** (antes todas las pistas) → menos decodificación.
- **Añadir canciones desde el detalle de playlist local**: hoja
  `agregarPistasAPlaylist` (buscador difuso + recomendaciones; filas con `+`/`✓`) y
  botón "Añadir" en `local_playlist_detail_screen.dart`.
- **Buscadores + orden por sección con estado guardado**: núcleo
  `library_filters.dart` (enums de orden + `.etiqueta`; Notifiers de orden
  **persistidos** por sección; queries transitorias; conteos de catálogo; providers
  `albumesFiltrados`/`artistasFiltrados`/`pistasFiltradas`; helpers
  `filtrarOrdenarPlaylists{Locales,Pc}`). UI: `library_filter_bar.dart`
  (`LibraryFilterBar` + `mostrarOrdenSheet` con "Limpiar filtros"). `biblioteca_screen`
  y `playlists_screen` reescritos.

### Cambios/tradeoffs
- **Índices de búsqueda hechos públicos** (`pistaIndexProvider`/`albumIndexProvider`/
  `artistaIndexProvider` en `search_providers.dart`) para reutilizarlos en los filtros
  de biblioteca y en la hoja "añadir canciones" (evita re-normalizar).
- **Se quitó el icono de búsqueda del `TopBar` de Biblioteca**: ahora **cada sección
  tiene su propio buscador** (la pestaña global "Buscar" sigue intacta).
- Umbral de coincidencia de los buscadores de biblioteca **0.45** (más estricto que la
  búsqueda principal 0.3): "da lo que buscas o algo muy similar", tolera 1 typo, no
  subsecuencias laxas. Pedido explícito ("no recomendaciones").
- El **orden** se persiste por sección (kv `orden_albumes`/`orden_artistas`/
  `orden_pistas`/`orden_playlists`); el **texto de búsqueda NO** se persiste
  (transitorio). "Limpiar filtros" resetea el **orden** a su defecto; el texto se limpia
  con la "X" del buscador (dos limpiezas independientes, por diseño).
- Clases Notifier de orden hechas públicas (`OrdenAlbumesNotifier`, etc.) para evitar el
  lint `library_private_types_in_public_api`.
- Conteo de pistas por playlist del PC: nueva query `catalog_dao.watchConteosPlaylists`
  (sin codegen, tabla ya declarada).

### Completo
Dedup de portadas + optimización, añadir canciones, buscadores+orden por sección con
estado guardado y limpiar, orden de playlists. Tests: `playlist_covers_test` (5),
`library_filters_test` (7).

### Faltante / no abordado en F3
- Verificación visual.
- No se persiste el **texto** de búsqueda (decisión: transitorio).
- Las recomendaciones de "añadir canciones" son heurísticas (recientes+favoritas+más
  escuchadas+catálogo); no hay recomendador real.

---

## Fase 4 — Ajustes / General / Perfil ⏳ (PENDIENTE, otra sesión)

Alcance pedido (resumen del plan en `~/.claude/plans/refactored-gathering-meerkat.md`):
- **Reestructurar**: la vista actual "Perfil" pasa a ser **General**; nuevo botón
  **Configuración** (como Sincronizar/Descargas) que contiene **Ecualizador** y
  **Temas**. El **Perfil** real se abre al tocar la imagen de perfil dentro de General
  (ahí estadísticas).
- **63 temas** con lista expandible (mostrar 9, "mostrar más" de 9 en 9, "mostrar
  menos"). **Requiere portar las 63 paletas** del escritorio
  `nb_sound/ui/modelos_qml.py::_TEMAS` al móvil: hoy `NbThemeId` (enum) y `NbPalettes`
  en `lib/shared/theme/nb_theme.dart` solo tienen **6**. Mantener el mismo **orden** del
  archivo del PC. Ojo: el grid de chips de tema en la pantalla itera
  `NbThemeId.values` — con 63 hay que paginar.
- **Ecualizador** estilo Spotify (**Android primero**): presets + bandas que al tocar
  pasan a "Personalizado", **normalizador de volumen** y **omitir silencio entre
  pistas**. En `just_audio`: `AudioPipeline` con `AndroidEqualizer` +
  `AndroidLoudnessEnhancer`, y `player.setSkipSilenceEnabled(true)`. **Hay que crear el
  `AudioPlayer` con `AudioPipeline`** (en `nb_audio_handler.dart`) — hoy se instancia sin
  pipeline. El PC expone presets/bandas en `modelos_qml.py` (`eq_presets_nombres`,
  `eq_bandas_hz`, `eq_preamp`, `normalizar_volumen`) como referencia de UX/valores.
- **Estado de conexión real en General**: **reutilizar `conexionPcProvider`** (ya
  creado en F1): Sin enlace / Desconectado / Conectado (no mostrar el nombre del
  teléfono). 
- **Más estadísticas**: además de pistas/favoritas, sumar **GB ocupados**
  (`OfflineStore.calcularEspacio`, ya existe) y **nº de pistas con karaoke**
  (`downloads_dao`/stems), estilo Descargas.
- **Descargas**: clarificar el slider "Descargar todo" (no se entiende si es automático
  o manual) y añadir un **buscador resiliente a errores** (reusar `fuzzy.dart`) para
  encontrar/borrar pistas y playlists sin salir de la pantalla.
- **Responsive/títulos** de `profile`/`descargas`/`sync`: ya hay `SectionLabel`,
  `MaxWidth`, `SubHeader` grandes y `conexionPcProvider` listos para reutilizar.

### Piezas ya disponibles para F4 (no rehacer)
- `conexionPcProvider` (estado de conexión real) — `features/sync/application/conexion_provider.dart`.
- `OfflineStore.calcularEspacio()` (GB por categoría) — `features/offline/data/offline_store.dart`.
- `SectionLabel`, `MaxWidth`, `LibraryFilterBar`, `fuzzy.dart` (buscador resiliente).
- Persistencia kv: patrón `ThemeController`/`_OrdenNotifier` (leer en build async +
  guardar en `SyncEstado`). El tema ya persiste (`kTemaPrefKey`).

---

## Mapa de archivos del rediseño (F1–F3)

- **Compartidos nuevos:** `shared/util/responsive.dart` (reescrito),
  `shared/widgets/{section_label,auto_fit_text,mini_player_bar}.dart`,
  `core/search/fuzzy.dart`.
- **Reproductor:** `features/player/presentation/player_screen.dart`,
  `features/player/application/{player_controller,nb_audio_handler}.dart`.
- **Conexión:** `features/sync/application/conexion_provider.dart`,
  `remote_control/presentation/destination_sheet.dart`.
- **Búsqueda/Inicio:** `features/library/application/{search_providers,
  library_providers}.dart`, `presentation/screens/{buscar,inicio}_screen.dart`,
  `presentation/widgets/library_cards.dart` (`ArtistCircle`).
- **Biblioteca/Playlists:** `features/library/application/{library_filters,
  playlist_covers}.dart`, `presentation/widgets/{library_filter_bar,playlist_dialogs,
  library_cards}.dart`, `presentation/screens/{biblioteca,playlists,
  local_playlist_detail,playlist_detail}_screen.dart`.
- **Datos:** `data/db/daos/{history_dao,catalog_dao,sync_state_dao}.dart` (queries y
  claves kv nuevas; sin cambio de esquema).
- **Arranque/shell:** `main.dart`, `app/app_shell.dart`, `core/router/app_router.dart`.

## Validación (F1–F3)

- `flutter analyze`: limpio.
- `flutter test`: **125 verdes** (incluye los nuevos de cada fase).
- Build: `flutter build apk --release` (universal 82.4 MB) y `--split-per-abi`
  (arm64 30.7 MB, v7a 26.6 MB), firmados con la keystore release; copiados a `dist/`.
- **Sin** verificación visual en dispositivo. **Sin** commit.
