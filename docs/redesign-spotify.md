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

---

## Fase 4 — Ajustes / General / Configuración / Perfil ✅ (code-complete 2026-06-09)

> Validado por `flutter analyze` limpio + **148 tests** verdes + **APK release
> firmado** (arm64 30.8 MB, v7a 26.8 MB, universal 82.7 MB; keystore propia
> SHA-256 `00:59:0F:10:…:3B:F7:2D`, `dist/` refrescada). **Sin commit** (no
> pedido). Verificación visual en dispositivo pendiente.

### Qué se hizo
- **Reestructura Perfil → General + Configuración + Perfil(stats)**: la antigua
  pantalla `/profile` es ahora **General** (`general_screen.dart`): tarjeta de
  perfil (toca → `/perfil`), **estado de conexión real** (reusa `conexionPcProvider`:
  Sin enlace/Desconectado/Conectado, sin nombre del teléfono) y accesos a
  Configuración/Sincronizar/Descargas. Nueva **Configuración**
  (`configuracion_screen.dart`, `/configuracion`): tile Ecualizador + selector de
  Temas. Nuevo **Perfil** (`perfil_screen.dart`, `/perfil`) con estadísticas:
  pistas, favoritas, **GB ocupados** (`espacioOfflineProvider`/`OfflineStore`),
  **nº con karaoke** (`resumenDescargas.stemsDone`). Router: `/profile`→General,
  + `/perfil`, `/configuracion`, `/ecualizador`. Se borró `profile_screen.dart`.
- **63 temas data-driven** (`nb_theme.dart` reescrito): se eliminó el `enum
  NbThemeId` + `NbPalettes` (6 temas) por `NbThemeDef{key,label,brightness,colors}`
  + `final List<NbThemeDef> kNbThemes` con las **63 paletas portadas del escritorio**
  (`modelos_qml.py::_TEMAS`, mismo orden; generado por script). Brillo derivado de la
  luminancia del fondo. `NbTheme.build(String key)`, `nbThemeByKey`,
  `nbThemeKeyFromStored` (acepta las claves antiguas camelCase de los 6 originales →
  migración transparente). `ThemeController` ahora guarda **String key**; `main.dart`
  y `nb_sound_app.dart` migrados. Selector en Configuración: lista **expandible 9 en
  9** (Mostrar más/menos, "N de 63").
- **Ecualizador Android** (`features/equalizer/`): el handler crea el `AudioPlayer`
  con `AudioPipeline(androidAudioEffects:[AndroidEqualizer, AndroidLoudnessEnhancer])`
  **solo en Android** (iOS/preview = no soportado). `EqualizerController` (persistido
  en kv `eq_*`, **vivo desde la raíz** vía `ref.listen` en `NbSoundApp` para aplicar
  al arrancar): activar/desactivar, **presets** (Plano/Graves/Agudos/Voz/Rock/Pop/
  Electrónica → remuestreados a las bandas reales del dispositivo; tocar una banda
  pasa a "Personalizado"), **normalizador de volumen** (`AndroidLoudnessEnhancer`,
  boost moderado), **omitir silencios** (`player.setSkipSilenceEnabled`). Pantalla
  `ecualizador_screen.dart` (sliders verticales por banda con frecuencia, presets,
  toggles).
- **Descargas**: copy del slider clarificado ("Descargar todo automáticamente" +
  estado activado/desactivado explicado) y **buscador resiliente** (difuso, reusa
  `fuzzy.dart`) que filtra pistas descargadas y playlists guardadas sin salir.

### Cambios/tradeoffs
- **`NbThemeId`/`NbPalettes` ELIMINADOS** → cualquier código que los use debe pasar a
  `kNbThemes`/`nbThemeByKey`. La persistencia del tema pasó de `id.name` (camelCase) a
  la **clave snake_case** del PC; `nbThemeKeyFromStored` migra los 6 valores antiguos.
- **Ecualizador**: las bandas reales del dispositivo solo están disponibles **tras
  empezar a reproducir** (just_audio expone `AndroidEqualizer.parameters` al activarse
  el reproductor en la plataforma); mientras tanto la pantalla muestra "Reproduce una
  canción…". El normalizador es un boost fijo del `LoudnessEnhancer` (target en dB,
  valor moderado), **no** una normalización perceptual completa. iOS queda fuera (la
  librería no expone efectos ahí).
- **`AudioPipeline` se crea al construir el `AudioPlayer`** (no se puede añadir
  después): el handler instancia los efectos en su constructor.

### Faltante / no abordado en F4
- Verificación visual en dispositivo (General/Perfil/Configuración, ecualizador real,
  los 63 temas, descargas).
- Ecualizador iOS.
- El normalizador podría evolucionar a normalización por ReplayGain si el PC expone esa
  señal (hoy boost fijo).

---

## Lote de correcciones de F1–F3 (2026-06-09, junto con F4)

Ajustes pedidos sobre las fases anteriores (todo `analyze` limpio + tests):

- **Responsive de pantallas grandes (reorientado)**: el usuario pidió **full-width**
  (no centrado con huecos laterales) y **más cosas/más grandes** en tablet/Chromebook/
  landscape. `responsive.dart`: `contentMaxWidthFor` ahora **siempre infinito**
  (`MaxWidth` queda passthrough; se quitó de Inicio/Playlists), `gridColumns` hasta **7**
  (≥1600), `uiScaleFor` hasta 1.22, nuevos `cardScaleFor` (tarjetas hasta ×1.6) y
  `scaledCount`/`countFor` (más ítems por carril). Aplicado a Inicio (más carriles/
  rejilla, tarjetas mayores), Búsqueda (círculos/álbumes mayores) y **letra del
  reproductor "muchísimo más grande"** (×1.5 medium, ×2.0 expanded) + portada del
  reproductor mayor.
- **Inicio**: "Tus favoritas" **sin el número**; carril "Tus playlists" **acotado**
  (como los demás); **rotación dinámica por sesión** (`sessionSeedProvider` +
  `rotarVentana`): novedades/clásicos/artistas/explora muestran otra porción del pool en
  cada apertura, aunque no entren canciones nuevas.
- **Búsqueda estilo Spotify**: las **secciones se ordenan por mejor coincidencia**
  (`ordenarSecciones`; "Bad Bu" ⇒ artistas primero; título exacto ⇒ canciones primero)
  y la **lista de canciones se acotó** (40 → 8) para no tener que bajar tanto.
- **Biblioteca**: los bottom sheets (orden/añadir/menú) ahora se presentan con
  `useRootNavigator: true` → quedan **encima del mini-reproductor** (ya no los tapa); el
  botón **"Seleccionar"** de Pistas se **oculta si todo está descargado** y reaparece
  solo cuando algo queda incompleto (reactivo).
- **Playlists**: **prefetch a disco** de las ≤4 portadas del mosaico
  (`PlaylistCoverPrefetcher`) para que en aperturas siguientes salgan instantáneas;
  **anclar** (long-press → hoja) con **máximo 4 por sección** (Tus playlists / Del PC,
  no 4 en total), tokens tipados `L<id>`/`P<id>` en kv (`playlist_pins.dart`), ancladas
  **siempre arriba** con distintivo de pin.
- **Reproductor**: el botón de descarga, si el PC **no está conectado**
  (`conexionPcProvider`), **avisa** ("No se ha podido descargar. Comprueba la
  sincronización…") en vez de encolar en silencio.
- **Aleatorio (fix real)**: `alternarAleatorio` ahora llama a `NbAudioHandler.reshuffle()`
  (`just_audio.shuffle()`) **al activar**, generando una **baraja nueva cada vez**
  (antes just_audio reutilizaba el mismo orden → parecía una segunda cola fija).

### Tests añadidos (148 totales, +23)
`search_orden_test` (orden de secciones), `rotacion_test` (`rotarVentana`),
`playlist_pins_test` (tokens/`conAncladasArriba`/máximo), `equalizer_test`
(`gananciasDePreset`), y `widget_test` actualizado a los 63 temas + migración de claves.

---

## Fase 5 — Paridad Spotify · bloque crítico (🔴) ✅ (code-complete 2026-06-10)

> Tras una auditoría de comportamiento contra Spotify/Apple/Tidal/Deezer, se
> cierran los cuatro defectos que más rompían el modelo "tipo Spotify". `flutter
> analyze` limpio + **158 tests** (+10) + APK arm64 40.3 MB. Sin cambios de
> esquema Drift, **sin tocar el escritorio**. Verificación visual en dispositivo
> pendiente. Plan: `~/.claude/plans/tender-floating-hartmanis.md`.

### Qué se hizo
- **5A · Fachada de reproducción unificada + enrutado Connect.** Nuevos métodos en
  `PlaybackActions` ([playback.dart](../lib/features/player/application/playback.dart)):
  `reproducirColeccion`, `reproducirColeccionAleatorio`, `reproducirPistaUnica`.
  Deciden destino: en local cargan la cola en el teléfono; con Connect activo la
  mandan al PC con `reproducir_pista(actual)` + `encolar_pista(resto)` (función
  pura `planColeccionRemota`, encola `index+1..fin`). **Migrados todos los
  call-sites** que llamaban directo a `playerController.reproducir` (álbum,
  playlist, playlist local, inicio, filas de pista, menú "Reproducir"). Arregla el
  bug de que, en "Mi PC", Reproducir sonaba en el teléfono.
- **5B · Cola manipulable.** Handler
  ([nb_audio_handler.dart](../lib/features/player/application/nb_audio_handler.dart)):
  `addToQueueEnd`/`insertAt`/`removeFromQueue`/`moveInQueue` sobre la API de
  just_audio 0.10.5 (`addAudioSource`/`insertAudioSource`/`removeAudioSourceAt`/
  `moveAudioSource`), manteniendo `queue` de audio_service en sync. Controlador
  ([player_controller.dart](../lib/features/player/application/player_controller.dart)):
  `addToQueue`/`reproducirACont`/`quitarDeCola`/`moverEnCola` (resuelven la fuente
  + ajustan `state.queue`/`index` con las puras `indiceTrasMover`/`indiceTrasQuitar`;
  si la cola está vacía, arrancan la pista). Menú de pista: "Reproducir a
  continuación" + "Añadir a la cola" (local). Vista Cola del reproductor: ahora
  **reordenable** (arrastre `onReorderItem`) sin aleatorio, y **quitar** pistas
  (× por fila, salvo la actual).
- **5C · Reproductor: navegación + menú "⋮".** "REPRODUCIENDO DESDE [álbum]" →
  abre el álbum; nombre del artista → abre el artista (ambos cierran el player
  primero, `_irA` captura el router antes del pop). Nuevo botón **⋮** en la
  cabecera que abre el menú de pista, ampliado con "Ir al álbum" / "Ir al artista".
- **5D · Acceso a Connect fuera del reproductor.** Prop `onCast` en el mini-player
  ([mini_player.dart](../lib/shared/widgets/mini_player.dart)); `MiniPlayerBar` lo
  muestra cuando `conexionPcProvider == conectado`. Nuevo tile "Reproducir en…" en
  General ([general_screen.dart](../lib/features/profile/presentation/general_screen.dart));
  "Sincronizar con PC" pasa a usar el icono `sync`.

### Cambios/tradeoffs y caveats
- **Routing Connect = solo móvil** (decisión del usuario): no se añadió comando al
  PC. El orden/estado final de la cola del PC depende de cómo trate su cola al
  recibir `reproducir_pista`; **validar contra el PC real**.
- **"Reproducir a continuación" con aleatorio activo** inserta en la secuencia
  subyacente en `index+1`, no en el orden barajado efectivo (v1).
- **Reordenar la cola solo sin aleatorio** (just_audio no expone reordenar la
  baraja); con aleatorio activo se ve el orden efectivo y solo se permite saltar/
  quitar (mapeando al índice real).
- **"Play next" no existe en remoto** (sin comando PC): en remoto solo "añadir a
  la cola del PC".
- **Navegar desde el reproductor cierra el reproductor** (no apila el detalle
  sobre el player).

### Tests añadidos (158 totales, +10)
`cola_test`: `planColeccionRemota` (enrutado/encolado), `indiceTrasMover`,
`indiceTrasQuitar`.

### Faltante / no abordado (siguiente fase 🟡)
Cerrar reproductor con swipe-down; tocar línea de letra = seek; transferencia de
vuelta PC→móvil; playlists en búsqueda + búsquedas recientes; "Tus me gusta" como
colección; menú ⋮ en playlist local + aleatorio en playlists; autoplay/radio +
sleep timer; separación "A continuación" vs "Siguiente desde contexto".

---

## Tanda de ajustes "afinado fino" (2026-06-11)

Lote de 17 ajustes pedidos sobre la app ya en paridad. `analyze` limpio, 170
tests, build release OK. Resumen por área:

- **Inicio**: accesos rápidos con **portada real** (primera pista con portada de
  la playlist; placeholder si ninguna) — `_QuickTile` resuelve la carátula.
  Saludo con nombre: "Buenas noches, Nombre" si hay nombre (usa
  `nombrePerfilProvider`).
- **Bottom sheets** (menú ⋮ de pista, filtros de orden, velocidad, temporizador,
  vista): nuevo helper `shared/widgets/sheet.dart::mostrarHojaMenu`
  (`isScrollControlled` + `SafeArea` + `SingleChildScrollView` + tope 88% alto):
  ya **no se cortan** por abajo aunque tengan muchas opciones (afecta también al
  ⋮ del reproductor).
- **Detalles (álbum/artista/playlist/local)**: la fila de acciones pasó a `Wrap`
  (nunca desborda) y el botón aleatorio es ahora `ShuffleCollectionButton`
  (estado coherente: acento si el aleatorio global está activo, + feedback en
  snackbar). "Reproducir en…" añadido al ⋮ del reproductor.
- **Modos de visualización** (`library_filters.dart::LibraryViewMode`
  lista/grid pequeña/mediana, persistidos por sección): botón junto a los
  filtros (`mostrarVistaSheet`). Álbumes/Pistas: lista (tiles) ↔ cuadrícula;
  Artistas: lista ↔ cuadrícula **circular**; Playlists: lista ↔ cuadrícula.
  Celdas de cuadrícula a prueba de desbordes (`_CoverGridCell` con
  Expanded+AspectRatio).
- **Portadas de playlist**: prefetch **al arrancar** (y tras el primer sync) de
  todas las playlists vía `PlaylistCoverPrefetcher.prefetchPlaylists` (en
  `NbSoundApp`), para que salgan instantáneas la primera vez.
- **Buscar — historial real** (estilo Spotify): se guarda el **ítem** abierto
  (pista/álbum/artista/playlist), no el texto (`recientes_busqueda.dart`,
  `ItemBusqueda`, kv `busquedas_recientes_items`). Tocar un reciente reproduce la
  pista sola o navega a la colección. Hooks `onOpen` en cards/tiles/`pistaRow`.
- **Reproductor**: cerrar con **arrastre vertical interactivo** (sigue al dedo,
  cierra pasado el umbral o vuelve con animación); **deslizar en horizontal**
  cambia de vista (Portada↔Letra↔Cola), no de canción; botón de **pantalla
  completa** de la letra (además del long-press).
- **Ajustes**: Configuración con tiles **Temas** (`/temas`, los 63 a la vista) e
  **Ícono de la app** (`/icono-app`). El tile "Sincronizar con PC" en General
  refleja el **estado de conexión** (color + etiqueta).
- **Ícono de la app conmutable de verdad** (Android): 63 PNG copiados a
  `assets/app_icons/` (preview) y `res/drawable-nodpi/ic_app_*` (lanzador);
  `tool/gen_icon_aliases.py` genera 1 alias por defecto + 63 `activity-alias`
  (MainActivity ya **no** lleva el LAUNCHER; nunca se deshabilita). MethodChannel
  `com.nbsound/app_icon` en `MainActivity.kt` conmuta habilitando el alias
  elegido y deshabilitando el anterior (DONT_KILL_APP). `AppIconController`
  persiste la elección (kv `icono_app`).
- **Perfil**: más stats (álbumes, artistas, playlists, reproducciones, además de
  pistas/favoritas/GB/karaoke), **nombre editable persistente** (no se
  sobreescribe con el del PC: `PerfilUsuario`/`perfilUsuarioProvider`, kv
  `nombre_usuario`) y **foto de perfil** (image_picker → copia a documentos, kv
  `foto_perfil`; se muestra en TopBars/General/Perfil).
- **Navegación**: los chevron de retroceso usan `context.pop()` de go_router (con
  fallback a Inicio) en vez de `Navigator.maybePop` del navegador anidado, que no
  devolvía al llegar a un detalle directo desde una pestaña.

Dependencia nueva: `image_picker ^1.1.2`. Schema Drift sin cambios (todo kv).

### Búsqueda cruzada en Biblioteca (2026-06-11, adicional)

Cada sección del buscador de Biblioteca sigue mostrando **solo su tipo**, pero se
encuentra por **referencias cruzadas** (`library_filters.dart`):
- **Álbumes**: por título, por **artista** (sus álbumes) y por **pista** (el álbum
  que la contiene). Índice `_AlbumCruz`.
- **Artistas**: por nombre, por **álbum** (su artista) y por **pista** (su artista).
  Índice `_ArtistaCruz`.
- **Pistas**: ya lo cubría `PistaBusq` (puntúa por título, artista ×0.85 y álbum
  ×0.75).

Núcleo puro y testeado `puntuarCampos(q, campos)`: máximo ponderado entre los
campos (directo ×1.0, cruzados ×0.9/×0.85, así el match directo ordena primero).
Los índices cruzados se recalculan solo al cambiar el catálogo. 174 tests.

### Placeholders de carátula/foto faltante por tipo (2026-06-13)

Antes, una pista/álbum sin carátula quedaba como un cuadrado gris plano (`Cover`
con `image:null`), el artista como círculo con icono de persona y la playlist con
un icono de nota suelto. Ahora **cualquier** contenido sin imagen muestra un
respaldo tipado y reconocible en **todas** las vistas (inicio, buscar, biblioteca,
playlists, detalles, reproductor, mini-reproductor, cola, diálogos).

Piezas (`shared/widgets/`):
- **`cover_placeholder.dart`** (núcleo): `enum CoverKind {album, artist, track,
  playlist}`; `iconForCoverKind` (disco / persona / nota / lista); función pura
  **`coverPlaceholderGradient(c, seed)`** — degradado de marca **determinista por
  semilla** (id/título) que se deriva de los colores del tema activo (armónico con
  los 63 temas, sin colores que choquen) para que los respaldos no se vean
  idénticos; `CoverPlaceholder` (estático o animado); `Breathing` (respiración
  con un único `AnimationController`); `EqualizerBars` (barras de ecualizador
  animadas para pistas); y el sealed **`CoverTile`** (`CoverImageTile` /
  `CoverFallbackTile`) para mosaicos mixtos.
- **`cover.dart`**: `Cover` gana `kind`/`coverSeed`/`animatedPlaceholder` (pinta el
  placeholder tipado cuando no hay imagen ni gradiente explícito); `CoverMosaic`
  pasa a recibir `List<CoverTile>` (celdas imagen o respaldo); nuevo **`ArtistAvatar`**
  (círculo imagen-o-respaldo) que unifica los círculos de artista (carruseles,
  filas, héroes).
- **`features/library/.../playlist_art.dart`** + `playlist_covers.dart::
  slotsPortadaPlaylist` (puro, testeado): compone la portada de una playlist
  reflejando las pistas **sin carátula** como respaldos dentro del mosaico ("si no
  hay carátula en una o varias, queda como si fuera esa la portada"); si **ninguna**
  pista aporta carátula → un único placeholder de playlist. `PlaylistArt` centraliza
  la decisión mosaico/única/placeholder + prefetch a disco (DRY: antes la duplicaban
  tarjetas, filas, los dos detalles y el inicio).

**Decisión de rendimiento (clave):** el placeholder es **estático por defecto**
(cero `AnimationController`) en listas, rejillas y mosaicos — donde pueden aparecer
muchos a la vez — y solo **animado** en placeholders **únicos** visibles: portada
del reproductor y mini-reproductor (barras de ecualizador) y héroes de detalle
álbum/artista/playlist (respiración). Sin assets externos (sin Lottie → sin inflar
el APK ni riesgo de jank). Así "la animación solo si no se vuelve pesado".

Excepciones deliberadas (no son cuadrados grises, son afford­ances): el icono cast
del `remote_player_view` (señala "suena en tu PC") y el icono de nota del selector
"añadir a playlist" (acción rápida; renderizar el mosaico por fila exigiría
consultar las pistas de cada playlist en una hoja transitoria). Tests nuevos:
`slotsPortadaPlaylist` (6 casos) + `cover_placeholder_test` (icono/gradiente).

### Música local del teléfono + Hotkeys (2026-06-13)

**Música local ("dos bibliotecas en una").** Detalle de datos en
`docs/local-data.md` §Música local. Resumen de feature:
- Detecta la música del teléfono vía **MediaStore** (MethodChannel nativo
  `com.nbsound/local_media` en `MainActivity.kt`; `permission_handler` para el
  permiso). No pide carpeta; ignora notas de voz/audios de apps (`IS_MUSIC` +
  duración ≥30 s). Se integra en las **mismas tablas** del catálogo con
  `origen='local'` e **ids negativos** → fluye por toda la UI; el sync (ids del
  PC) nunca la toca y `id<0` la aísla del Connect.
- **Carátula embebida** lazy (`localart://` + `LocalArtworkImage`), placeholder
  tipado entretanto.
- **Dedupe** contra lo sincronizado (la del PC prima): título+artista+álbum
  normalizados + duración ±10 s; remapea playlists/favoritos a la del PC.
- **Aislamiento Connect**: historial/favoritos no suben ids locales; handoff,
  enrutado remoto y menú de pista excluyen `id<0`.
- **Pantalla de gestión** `/musica-local` (en Configuración): revisar manual o
  automático, ocultar por pista / ocultar todas (sin borrar del teléfono) +
  revelar, y **buscador difuso**.

**Hotkeys de teclado** (`lib/app/player_hotkeys.dart`, en el `builder` de
`MaterialApp.router`): Espacio/Play-Pause = play/pausa; →/← = ±10 s; Ctrl+→/← y
Anterior/Siguiente = pista; enrutan por `PlaybackActions` (local o PC según
destino). Captura Espacio en cualquier vista → arregla el "marco verde" inútil
del Chromebook; los campos de texto consumen sus teclas antes (no disparan los
atajos al escribir). `PlaybackActions.seekRelativo` nuevo.

---

## Connect bidireccional real + propagación PC→móvil + arreglos de build (2026-06-13)

Cierra los 2 grandes pendientes (analyze limpio, **237 tests**, APKs release
firmados). Todo lo de abajo es **as-built**, no aspiracional.

### Connect bidireccional (PC ↔ móvil)
- **DJ Privado**: el frame `estado` ahora trae `dj_activo` (lado PC); el reproductor
  remoto (`remote_player_view`) muestra "DJ Privado en sesión" y **bloquea** los
  controles mientras dura. Al cerrar la sesión, vuelve el control.
- **Karaoke remoto**: comando WS `karaoke` (toggle) + botón en el reproductor remoto;
  refleja `karaoke_activo`.
- **Cola espejada**: comando `set_queue {ids, indice}` reemplaza la cola entera del PC
  en UNA difusión (antes se mandaba pista a pista). `reproducirColeccion` en remoto usa
  `planSetQueueRemota` (filtra locales, reubica el índice). Reordenar/quitar/vaciar la
  cola del PC desde el móvil: `move_queue`/`remove_queue`/`clear_queue` + UI reordenable
  en la hoja "Cola del PC". El PC **empuja `cola` en cada cambio** (no solo ante `queue`);
  el cliente pide `queue` al conectar para poblarla.
- **Reconexión acotada** (`planReconexion`, pura): backoff exponencial a 16 s; tras
  agotar intentos la UI degrada a "sin conexión" (volver a local) pero **sigue
  reintentando** para recuperarse solo cuando vuelva el PC/WiFi. Reinicia el backoff
  al recibir cualquier frame. El 401/desvinculación lo detecta la capa de sync (re-emparejar).
- Multi-dispositivo: el PC ya difunde a todos los sockets (verificado en el contrato).

### Correcciones del Connect (2026-06-13)
- **Repetición off/una/todas funcionaba a medias**: el móvil hablaba `ninguno|una|todas`
  pero el enum AS-BUILT del PC (`ModoRepeticion` en `servicios/reproductor.py`) es
  `ninguno|uno|todo`, y `set_modo_repeticion` **descarta** (try/except ValueError) lo
  desconocido. Efecto: desde el móvil solo se podía **apagar** (el único valor que
  coincidía era `ninguno`); el icono nunca mostraba "una" (se quedaba en el de "todas",
  el fallback). FIX **solo móvil** (PC manda; el contrato doc estaba mal): se centralizó
  el vocabulario real en `ModoRepeticionPc` (`remote_dtos.dart`) y se usa en el ciclo
  (`remote_controller.cicloRepeticion`), en el icono/color (`remote_player_view`) y en el
  handoff remoto→local (`playback.NowPlaying.fromRemote`). Contrato corregido a
  `ninguno|uno|todo`.
- **Botón de karaoke siempre cliqueable**: el frame `estado` no decía si la pista del PC
  tenía instrumental. Se añadió `karaoke_disponible` al snapshot (**lado PC**, lo commitea
  el usuario; ya había `ModeloReproductor.karaoke_disponible`, refrescado por
  `karaokeCambiado` que ya empuja estado) y al `RemoteEstadoDto` (`karakeDisponible`,
  default `true` aditivo para PC viejos). El botón del reproductor remoto se **deshabilita
  y atenúa** (`onPressed: null`, color `text3`) cuando no hay pista o no hay stems.

### Propagación PC→móvil (cambios del PC reflejados al sincronizar)
- `SyncResult` ahora expone los ids del delta (pistas/álbumes/artistas cambiados) y de
  los tombstones (solo recolecta delta en syncs incrementales, `since>0`).
- `OfflinePropagation` (offline/application): tras cada sync, **borra la media offline
  huérfana** de los tombstones (audio/letra/karaoke por pista; portada por álbum; foto
  por artista) + sus filas; y **resetea** (`done`/`unavailable` → `none`) los recursos
  descargados que cambiaron (letra/karaoke por pista; portada por álbum; foto por
  artista) para que se rebajen con el contenido nuevo. Devuelve las pistas a re-encolar;
  `SyncController` las encola antes del mantenimiento offline. `reseteable` es puro.
- **Audio NO se resetea** ante cambios de metadata (caro; el mismatch de hash ya es no
  fatal). **Lado PC (lo commitea el usuario)**: se bumpéa `sync_version` al **generar
  karaoke** (jobs_repo) y al **enlazar/cambiar portada** de álbum (sync_repositorio), sin
  lo cual la pista/álbum no llegaría en el delta y la propagación no dispararía.
- **Estadísticas reactivas**: perfil/Descargas ya usan streams; `espacioOfflineProvider`
  ahora recomputa también ante cambios de portadas/fotos (no solo audio), así los GB y
  conteos suben/bajan al sincronizar/propagar borrados.

### Arreglos vistos en la build
- **Placeholders 404**: `Cover`/`ArtistAvatar`/`CoverMosaic` usaban `DecorationImage`,
  que falla en silencio cuando el `/asset/cover/{id}` da 404 (álbum sin portada) →
  cuadro gris. Ahora usan `Image` con **`errorBuilder`** que cae al placeholder tipado
  (disco/persona/nota). Test de widget nuevo.
- **Música local**: movida de Configuración a **General**, debajo de Descargas.
- **Aleatorio**: "Aleatorio" arranca en una pista **al azar** (no siempre la 1ª) y deja
  el aleatorio encendido, **igual en todas las colecciones** (álbum/artista/playlist/
  "Tus me gusta"); `reproducirColeccionAleatorio` unificado.
- **Cerrar la app deja de sonar**: `NbAudioHandler.onTaskRemoved` detiene la
  reproducción al quitar la app de recientes (señal canónica Android/ChromeOS) y
  `NbSoundApp` detiene el handler en `AppLifecycleState.detached` (cierre de ventana en
  Chromebook). Segundo plano (paused/hidden) **sigue sonando** como antes.

### Presencia real de dispositivos en la Sincronización del PC (2026-06-13)
La Vista de Sincronización del PC mostraba "sin dispositivos conectados" aunque el
móvil estuviera online (solo contaba WS abiertos, que casi siempre eran 0 fuera de
Connect). Ahora muestra el estado REAL por dispositivo (verde "Conectado"):
- **PC (lo commitea el usuario)**: `servidor_sync` rastrea WS por dispositivo
  (`_ws_dispositivos`) y el middleware trata `/ping` con token como heartbeat
  (refresca `ultima_conexion`); `sync_repositorio.dispositivos_conectados_ids`
  (ventana ~75 s); `ModeloSincronizacion` marca `conectado` por dispositivo y refresca
  con un `QTimer` ~2 s; `clientesConectados` cuenta la unión; badge en
  `VistaSincronizacion.qml`.
- **Móvil**: `PairingRepository.heartbeat` (ping autenticado) + `Timer.periodic` ~25 s
  en primer plano (`NbSoundApp`). Test: `heartbeat()` va con el device_token.

## Persistencia de cola en Connect + sliders deslizables + diagnóstico de red (2026-06-13)

Tanda de pulido sobre el Connect (analyze limpio, **249 tests** móvil [+12], **14**
en `test_modelo_sincronizacion` PC [+1]).

### La cola COMPLETA persiste al cambiar de destino (antes solo la pista en curso)

Cambiar "Reproducir en…" perdía la cola: solo viajaba la pista que sonaba. Ahora se
espeja/trae la cola entera en ambos sentidos, conservando índice y posición.

- **Móvil → PC** (`playback.usarRemoto`): nuevo puro `planHandoffRemoto(cola, index,
  posSeg)` (filtra música local id<0, reubica el índice contando las no locales, normaliza
  posición). Manda la cola entera con `establecerCola(ids, indice, posicionSeg:)` (una sola
  difusión `set_queue`) en vez del antiguo `reproducir_pista` de una pista. Si lo que suena
  es local (no existe en el PC), solo pausa el móvil.
- **PC → móvil** (`playback.usarLocal`): captura `remoto.cola` (la cola espejada que el PC
  ya empuja) e `indiceCola` ANTES de desconectar y llama `PlayerController.reproducirColaRemota`
  (nuevo). Puro `mapearColaRemota(ids, indice, porId)`: mapea ids del PC a `Pista` de la
  biblioteca (omite las no sincronizadas), reubica el índice (a la pista en curso o, si falta,
  la siguiente disponible). Degrada a traer solo la pista en curso (`reproducirIdRemota`) si el
  PC no publicó cola. Conserva posición y estado (sonando/pausa).
- **PC (lo commitea el usuario)**: el handler `set_queue` acepta `posicion_seg` opcional →
  tras `reproducir_cola_desde_pistas` hace `buscar_posicion` (misma semántica best-effort que
  el handoff de una pista). Contrato (`pc-contract.md` §5.2) y `mobile-ecosystem.md` actualizados.
- Tests puros nuevos: `planHandoffRemoto` y `mapearColaRemota` (`cola_test.dart`);
  `set_queue` con/ sin `posicion_seg` (`test_modelo_sincronizacion`).

### Sliders deslizables de verdad en "REPRODUCIENDO EN MI PC"

El scrubber y el volumen del reproductor remoto eran barras con `onChanged: (_) {}`: el
pulgar no seguía al dedo (volvía a la posición del PC) y solo aplicaban al **tocar** un punto
o **soltar**. Nuevo `_LiveSlider` (StatefulWidget): el pulgar sigue al dedo (estado local de
arrastre), aplica **en vivo** mientras se arrastra (acotado: volumen ~90 ms, scrubber ~180 ms),
ignora el valor del PC mientras se arrastra y, al soltar, mantiene la posición elegida hasta
que el PC la refleje (tolerancia 4 % + gracia de 2 s) para no "saltar atrás" con un frame
viejo. `_RemoteScrubber`/`_RemoteVolume` lo usan (el tiempo y el % siguen al dedo en vivo).

### Diagnóstico de red al vincular (caso Chromebook "distinto Wi-Fi")

`PairingRepository._codeFor` englobaba TODO fallo no-401 en `error_red` ("misma red"), que
**despistaba**: estando en la misma WiFi, un timeout/conexión rechazada suele ser el
**firewall del PC** o el **aislamiento de clientes** del punto de acceso (redes de
invitados/malla), no la red. Ahora distingue por `DioExceptionType`: `red_timeout`,
`red_inalcanzable`, `red_tls` (y `error_red` genérico), con mensajes accionables en
`sync_screen._ErrorView`. **No** se añadió ningún chequeo de subred (el PC nunca lo exigió);
el fallo del Chromebook es de entorno (firewall/aislamiento), no de la app.

### Auto-refresco de presencia en la Sincronización del PC (lo commitea el usuario)

La vista no reflejaba al instante quién estaba conectado. `VistaSincronizacion.qml` ahora
refresca `recargarDispositivos()` al **entrar** (`Component.onCompleted` + `onVisibleChanged`)
y cada **3 s mientras la vista está visible** (`Timer running: raiz.visible`), además del
timer global de presencia (~2 s). Actualiza también la "última conexión".
