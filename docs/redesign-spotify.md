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
