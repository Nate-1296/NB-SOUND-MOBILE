# Estado de la app (as-built)

Documento factual de **lo que existe hoy** en `nb_sound_mobile`: qué está
implementado, con qué nivel de verificación, y qué falta. No es plan ni diseño
(eso está en [`implementation-plan.md`](implementation-plan.md) y
[`architecture.md`](architecture.md)); es el estado real para usuarios y para
retomar el desarrollo.

Última actualización: 2026-06-05. Bloques 0–10 del plan de cierre **completos** y
verificados (streaming/letra/karaoke/descarga/sync/control **contra el PC real**).
`flutter analyze` limpio · **49 tests** verdes · build Android (APK debug) OK.

---

## Niveles de verificación (importante)

No todo está probado al mismo nivel. Tres categorías:

- **A · Verificado en emulador Android** — visto funcionando en un dispositivo real.
- **B · Implementado + testeado contra simulaciones** — código completo y con
  tests (servidores HTTP/WebSocket falsos), pero **nunca ejecutado contra la app
  de escritorio NB Sound real**. La integración real puede revelar desajustes.
- **C · Placeholder / no implementado** — UI sin lógica real, o ausente.

> **El target verificado es Android.** iOS no se ha compilado (requiere macOS).
> Linux desktop corre la UI en modo *preview* (sin audio; los plugins de audio
> no soportan escritorio).

---

## Funcionalidades por bloque

### Bloque 0–1 · Base + datos locales — **A**
- Navegación (go_router `StatefulShellRoute`): 4 pestañas + detalle + reproductor
  + perfil + sync + descargas.
- Tema: 3 paletas (`medianoche` default, `terracota`, `aurora`) como
  `ThemeExtension`; fuentes bundleadas Space Grotesk + Manrope.
- BD local Drift: catálogo (artistas/álbumes/pistas/playlists), historial,
  favoritos, descargas, estado de sync, PC emparejado. DAOs + migración v1.
- DTOs del protocolo (freezed) espejo de `pc-contract.md`.
- **Seed de desarrollo** (`lib/data/db/seed/dev_seed.dart`, flag `kSeedDevData`):
  puebla la BD con un catálogo de ejemplo (12 álbumes, 22 pistas) y 3 audios
  bundleados, para usar la app sin PC. *Artefacto de desarrollo; convive con los
  datos reales de sync y debe retirarse al pasar a producción.*

### Bloque 4.1 · Reproductor local — **A**
- `just_audio` + `audio_service`: reproducción en background, controles de
  sistema (MediaSession/lockscreen), cola con auto-avance.
- Mini player flotante (en las pestañas) y reproductor full-screen con vistas
  **Portada / Letra / Cola**, scrubber (seek), shuffle, repeat, favorito.
- Registra historial al reproducir; alterna favoritos.
- Reproduce: audio del seed y archivos **descargados**. *No reproduce pistas
  sincronizadas sin descargar (no hay streaming — ver Limitaciones).*

### UI de biblioteca — **A**
- Inicio (recientes desde historial, favoritas, álbumes), Buscar (búsqueda local
  por título/artista), Biblioteca (sub-tabs Álbumes/Artistas/Pistas), Playlists
  (rejilla con mosaicos), detalle de Álbum/Artista/Playlist con reproducción.

### Bloque 2 · Emparejamiento (QR + mDNS) — **B**
- Escaneo de QR (`mobile_scanner`, **el permiso de cámara y el escáner sí abren
  en el emulador**) → `POST /api/v1/pair`.
- Pinning TLS por huella (TOFU) en `dio` (`core/network/tls_pinning.dart`,
  `nb_api_client.dart`); credenciales en `flutter_secure_storage`
  (`core/security/secure_store.dart`); reconexión mDNS (`nsd`, `_nbsound._tcp`).
- UI completa del flujo (`features/sync/presentation/sync_screen.dart`):
  intro → escáner → conectando → conectado → error.
- **No probado contra un PC real:** el emparejamiento end-to-end está pendiente.

### Bloque 3 · Sincronización delta — **B**
- `GET /api/v1/manifest?since=&limit=` paginado, cada página en transacción Drift
  (upsert por id + tombstones + reconciliación de favoritos *last-write-wins*).
  Reanudable/idempotente (`ultima_sync_version` se persiste al terminar).
- `POST /api/v1/history` (sube historial/favoritos no subidos y los marca).
- Selección negociable (`GET/POST /api/v1/seleccion`).
- UI: botón "Sincronizar ahora" con progreso/resultado en el estado conectado.
- **No probado contra un PC real.**

### Bloque 4.2 · Descarga offline — **B**
- `GET /api/v1/track/{id}/audio` con `Range` reanudable + validación `sha256` al
  completar (`X-NB-Sound-Hash`); estado en `descargas_audio`.
- Cola secuencial; selección por pista/álbum/playlist; reanuda pendientes al
  arrancar. El reproductor resuelve la pista descargada a su archivo local.
- UI: botón descargar (detalle + menú de pista), indicador en filas, pantalla
  **Descargas** (`/descargas`, estado/progreso/borrar). *La pantalla renderiza
  (empty state verificado en emulador); la descarga real necesita el PC.*

### Bloque 5 · Control remoto (Spotify Connect) — **B**
- WebSocket `/api/v1/control` (WSS con `customClient` pinned por huella + Bearer);
  refleja el frame `estado` plano del PC y el `cola`; envía comandos
  (play_pause/next/prev/seek/set_volume/play_index/repeat/shuffle/queue);
  reconexión con backoff.
- Selector de destino "Este teléfono" / "Mi PC" (**UI verificada en emulador**);
  `RemotePlayerView` con controles + volumen + cola del PC.
- **No probado contra un PC real.**

---

## Inventario de pantallas

| Pantalla | Ruta | Estado |
| --- | --- | --- |
| Inicio | `/inicio` | A |
| Buscar | `/buscar` | A |
| Biblioteca (Álbumes/Artistas/Pistas) | `/biblioteca` | A |
| Playlists | `/playlists` | A (read-only) |
| Detalle Álbum / Artista / Playlist | `/album/:id` etc. | A |
| Reproductor (Portada/Letra/Cola) | `/player` | A (Letra = placeholder) |
| Reproductor remoto "Mi PC" | `/player` (si destino=remoto) | B |
| Perfil (tema + accesos) | `/profile` | A |
| Sincronizar con PC | `/sync` | B |
| Descargas | `/descargas` | B |

---

## Stack as-built

Riverpod 3 (+ codegen), go_router 17, Drift 2.33, just_audio 0.10 +
audio_service 0.18, dio 5.9, web_socket_channel 3, mobile_scanner 7, nsd 5,
flutter_secure_storage 10, freezed 3 + json_serializable, crypto. **Iconos:
Material Icons** (no Lucide; ver `shared/widgets/app_icons.dart`). Codegen con
`dart run build_runner build`.

---

## Hecho y verificado contra el PC real (2026-06-05)

Ver detalle en [`integration-notes.md`](integration-notes.md). Sube a **A**:

- **Streaming sin descargar** ✅: pista sincronizada suena por `/audio` (HTTPS
  pinned vía proxy de just_audio) sin descargar. Botón de descarga en caliente.
- **Letra real** ✅: `/lyrics` (LRC sincronizado con resaltado + auto-scroll),
  cache-first en `lyrics/{id}.json`; estados sin-letra / sin-PC.
- **Karaoke real** ✅: `/stems` (instrumental por streaming conservando posición;
  toggle deshabilitado si la pista no tiene stems).
- **Descargas** ✅: hash de identidad **head+tail** (no archivo completo) alineado
  con el PC; un mismatch no borra el archivo (`hashOk=false`).
- **Portadas remotas** ✅: `NetworkImage` con auth + pinning global (404→respaldo).
- **Emparejamiento, sync delta, /history, control remoto WSS** ✅ (B→A).
- **Pinning Android**: `network_security_config` (cleartext solo a loopback, para
  el proxy de just_audio) + huella en vivo en `NbHttpOverrides`.

## Hecho (features de calidad)

- **Playlists locales** ✅: tablas Drift propias (schema v2), CRUD completo
  (crear/renombrar/borrar/añadir/quitar/reordenar), "Añadir a playlist" en el menú
  de pista. Las del PC siguen read-only.
- **Tema persistente + 6 temas del escritorio** ✅ (Negro Puro OLED, Arcilla
  Nocturna, Hielo OLED [oscuros]; Arcilla Cálida, Blanco Editorial, Marfil Grafito
  [claros]); persistido en `SyncEstado` y cargado en `main`.
- **Perfil real (solo lectura)** ✅: nombre + estadísticas del PC (guardadas en
  cada sync) + estado de conexión. La foto del PC es ruta local suya, no descargable.
- **Mini player**: confirmado by-design que no aparece en rutas full-screen.
- **Seed de demo**: **apagado por defecto** (`kSeedDevData` =
  `bool.fromEnvironment('NB_SEED')`); empty state en Inicio guía a sincronizar.
- **Tablet/accesibilidad**: rejillas con columnas responsivas; `Semantics` en los
  controles personalizados del reproductor.

## Empaquetado (Bloque 6.2) — **hecho**

Detalle en [`release.md`](release.md). APK release Android **firmado con keystore
propia** (`com.nbsound.nb_sound_mobile`, label "NB Sound", v0.1.0), **ícono**
desde el logo NB Sound (adaptativo terracota), y **sin media de prueba** en el
bundle (audio/portadas llegan del PC; solo van las fuentes de UI). Builds
universal (~77 MB) y `--split-per-abi` (arm64 ~30 MB). Copias en `dist/`.
Verificado: firma = keystore release, identidad/ícono correctos, APK sin
covers/audio/images.

## Paso de datos PC→celular cerrado + en vivo (2026-06-08) — schema v4

Cierre del flujo de descargas y mantenimiento en vivo (`flutter analyze` limpio,
**84 tests**):

- **Playlists del PC guardadas/seguidas**: tabla propia `playlists_guardadas`
  (estado del móvil, aparte del catálogo; sobrevive al sync). En el detalle de
  una playlist del PC, "Guardar" la pasa a **Tus playlists** y descarga todo su
  contenido; el mantenimiento baja las pistas nuevas que el PC añada. `deletePlaylist`
  (tombstone) limpia la guardada. DAO `FollowedPlaylistsDao`.
- **Descargas resilientes**: audio 404 ⇒ `unavailable` (no `failed`); reintentos
  con backoff acotado (0.5/1/2 s, máx. 3) para fallos transitorios en audio/karaoke
  (helper `_descargarStream` compartido). Cola: `reintentarFallidas()`,
  `encolarTodo()` (espejo completo) y `mantenerPlaylistsGuardadas()`.
- **Selección inteligente** (Biblioteca › Pistas): "Todas" marca solo las
  **incompletas**; las completas salen con check deshabilitado. Predicado puro
  compartido `pistaCompletaCore` + `pistasCompletasProvider` (done|unavailable).
- **Contadores reales** en Descargas (no del lote): `watchResumen` (audio/letra/
  karaoke por estado) + `watchConteo` (portadas/artistas) + `watchTotalPistas` →
  "N de M", desglose por categoría, espacio en disco por carpeta, lista de
  playlists guardadas con progreso, y acciones Reintentar / **Descargar todo**.
- **Todo en vivo (auto-sync)**: `SyncController` sincroniza al conectar/arrancar
  y `NbSoundApp` al volver a primer plano (resume) + periódico (5 min en
  foreground). Cada sync con éxito encadena el **mantenimiento offline**
  (reintentos + playlists guardadas + "descargar todo" si está activo). La
  reactividad de Drift refleja cambios sin reabrir.
- **Conexión por IP (sin cámara)** — VERIFICADA contra el PC real: en Sincronizar
  → "Sin cámara: conectar por IP", se escribe la dirección (`host` o `host:puerto`)
  y el código del QR. `PairingRepository.pairPorIp` descubre el puerto (escaneo
  8731–8799 vía `/ping`), **aprende y fija la huella TLS por TOFU**, y llama a
  `/pair`. Validado: emparejó por IP descubriendo el puerto y con la huella
  correcta (`395f3acd…`); código inválido ⇒ 401. (El PC solo muestra la IP, no el
  token en texto: el código sigue saliendo del QR — no se tocó el escritorio.)

## No hecho / pendiente

- **iOS**: no compilado (requiere macOS). Solo Android verificado.
- **Tienda**: falta App Bundle (`flutter build appbundle`) + alta en Play; la
  firma ya es de release. R8/minify no habilitado (ver `release.md`).
- **i18n**: todo en español fijo (intl/arb pendiente; esfuerzo aparte).
- **Datos del PC**: la biblioteca de prueba tiene solo 41/2231 pistas versionadas,
  0 portadas y hashes stale (re-indexar en el PC). No es un fallo del móvil.

---

## Cómo correr y verificar

Requiere el toolchain (Flutter stable ≥ 3.29, Android SDK 36). Las plataformas
(`android/`, `ios/`, `linux/`) ya están generadas.

```bash
flutter pub get
dart run build_runner build          # codegen (drift/freezed/json)
flutter analyze && flutter test      # lint + 35 tests
flutter run -d <emulador|dispositivo>
```

**Tests** (en `test/`): formato de duración; round-trip de DTOs; DAOs
(upsert/append/favoritos LWW/seed); sync (paginado+tombstones+versión, favoritos
LWW, push, reanudación); descarga (completa+hash, reanudación por Range, hash
mismatch); QR parse + pairing repo (mock dio); control remoto (parseo de frames +
cliente WS contra servidor local). **Cubren la lógica, no la integración real.**

## Próximos pasos sugeridos

1. **Integración real contra el PC** (encender el escritorio, emparejar →
   sincronizar → descargar → controlar; arreglar desajustes). Sube B → A.
2. Cerrar placeholders: lyrics y **streaming** (para oír/ver sin descargar);
   luego karaoke/stems.
3. **Bloque 6.2**: ícono, permisos finales, firma, APK release (iOS con macOS).
4. Pulido: persistir tema, retirar el seed, errores, tablet.
