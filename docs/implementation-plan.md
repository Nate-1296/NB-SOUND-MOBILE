# Plan de implementación — NB Sound Mobile

Plan ejecutable de la **app móvil** (Flutter). La contraparte de escritorio
(servidor, endpoints, schema, QR) tiene su propio plan en
`../../nb_sound/docs/mobile-rollout-plan.md`. Ambos avanzan acoplados: la app
móvil necesita el endpoint correspondiente del PC para cada bloque.

Formato por tarea: `[S/M/L/XL]` · **Qué** · **Done when** · **Depende de**.

## Estado (2026-06-04)

**Bloques 0–5 code-complete.** Estado real y nivel de verificación de cada parte
en [`app-state.md`](app-state.md). Resumen:

| Bloque | Estado |
| --- | --- |
| 0 Bootstrap · 1 Datos locales | Hecho · **verificado en emulador** |
| 4.1 Reproductor local + UI de biblioteca | Hecho · **verificado en emulador** |
| 2 Emparejamiento (QR/mDNS) | Hecho · **testeado vs. simulación; falta probar con el PC real** |
| 3 Sincronización delta | Hecho · **testeado vs. simulación; falta probar con el PC real** |
| 4.2 Descarga offline (Range+hash) | Hecho · **testeado vs. simulación; falta probar con el PC real** |
| 5 Control remoto (WS) | Hecho · **testeado vs. simulación; falta probar con el PC real** |
| 6.1 UI/UX biblioteca y reproductor | Hecho (parte; Letra/karaoke/streaming = placeholder) |
| 6.2 Builds Android/iOS (firma, ícono, release) | **Pendiente** (solo APK debug; iOS sin compilar) |

Pendiente transversal: integración real contra el PC, streaming sin descarga,
lyrics/karaoke reales, persistir tema, retirar el seed de demo. Detalle en
[`app-state.md`](app-state.md).

---

## BLOQUE 0 — Bootstrap del proyecto (Objetivo: app que compila y corre vacía)

### Tarea 0.1 [S] — Generar plataformas
- **Qué**: `flutter create . --org com.nbsound --project-name nb_sound_mobile`
  (respeta `lib/`, `docs/`, `pubspec.yaml`). `flutter pub get`.
- **Done when**: `flutter run` arranca en un emulador Android y un simulador iOS.
- **Depende de**: nada.

### Tarea 0.2 [S] — Base de app
- **Qué**: `ProviderScope` raíz (Riverpod), tema base (`shared/theme`),
  `go_router` con rutas vacías (biblioteca, reproductor, sync).
- **Done when**: navegación entre 3 pantallas placeholder funciona.
- **Depende de**: 0.1.

---

## BLOQUE 1 — Datos locales (Objetivo: BD local funcional, offline-first)

### Tarea 1.1 [M] — Esquema Drift
- **Qué**: tablas de `local-data.md` (réplica de catálogo + historial/favoritos
  + sync_estado + pc_emparejado). DAOs básicos.
- **Done when**: tests de DAO (insert/upsert/query) verdes; migración inicial.
- **Depende de**: 0.2.

### Tarea 1.2 [M] — Modelos del protocolo
- **Qué**: DTOs (freezed + json_serializable) espejo del payload del PC
  (`../../nb_sound/docs/mobile-ecosystem.md`).
- **Done when**: round-trip JSON↔DTO testeado con fixtures del manifest.
- **Depende de**: 0.2.

---

## BLOQUE 2 — Emparejamiento y descubrimiento (Objetivo: el móvil encuentra y empareja con el PC)

### Tarea 2.1 [M] — Escaneo de QR + handshake
- **Qué**: `mobile_scanner` para leer el QR; `POST /pair`; guardar
  `device_token`+fingerprint en `flutter_secure_storage`.
- **Done when**: contra un PC real (o mock), el emparejamiento persiste y
  sobrevive a reinicios de la app.
- **Depende de**: 1.1; PC Tarea 2.2.

### Tarea 2.2 [M] — Reconexión por mDNS
- **Qué**: `nsd` descubre `_nbsound._tcp`; reconecta usando el token guardado.
- **Done when**: tras emparejar, la app reconecta sola al volver a la red.
- **Depende de**: 2.1; PC Tarea 2.2.

---

## BLOQUE 3 — Sincronización (Objetivo: catálogo en el móvil, historial/favoritos al PC)

### Tarea 3.1 [L] — Cliente de manifest delta
- **Qué**: `GET /manifest?since=`; aplicar en transacción Drift (upsert +
  tombstones); avanzar `ultima_sync_version`.
- **Done when**: test que sincroniza un catálogo de prueba y refleja altas,
  cambios y borrados; reanuda tras corte.
- **Depende de**: 1.1, 1.2, 2.1; PC Tarea 3.1.

### Tarea 3.2 [M] — Subida de historial/favoritos (merge)
- **Qué**: `POST /history` con no-subidos; favoritos con timestamp
  (last-write-wins); marcar `subido`.
- **Done when**: test que un favorito local gana o pierde según timestamp
  frente al PC.
- **Depende de**: 3.1; PC Tarea 3.3.

---

## BLOQUE 4 — Reproductor local + offline (Objetivo: escuchar sin PC)

### Tarea 4.1 [L] — Reproductor local
- **Qué**: `just_audio` + `audio_service` (cola, background, lockscreen);
  registrar historial local al reproducir.
- **Done when**: reproduce audio descargado en background con controles de
  sistema; historial se registra.
- **Depende de**: 1.1.

### Tarea 4.2 [L] — Descarga offline (reanudable)
- **Qué**: cola de descargas con `dio` + `Range`; validar `hash_sha256`;
  estado en `descargas_audio`.
- **Done when**: descarga reanuda tras corte y el archivo valida hash;
  selección por pista/álbum/playlist.
- **Depende de**: 3.1; PC Tarea 3.2.

---

## BLOQUE 5 — Control remoto (Objetivo: el móvil comanda el PC)

### Tarea 5.1 [M] — Cliente WebSocket
- **Qué**: `web_socket_channel` a `/control`; `RemoteController` (estado +
  comandos); reconexión con backoff. Ver `remote-control.md`.
- **Done when**: play/pause/next/seek/volume desde el móvil afectan al PC y el
  estado del PC se refleja en vivo.
- **Depende de**: 2.1; PC Tarea 3.4.

### Tarea 5.2 [M] — Selector de destino (Connect)
- **Qué**: UI para alternar "Este teléfono" / "Mi PC"; el reproductor usa el
  provider correspondiente.
- **Done when**: cambiar de destino conmuta control local↔remoto sin reiniciar.
- **Depende de**: 4.1, 5.1.

---

## BLOQUE 6 — Pulido y empaquetado (Objetivo: builds instalables)

### Tarea 6.1 [M] — UI/UX de biblioteca y reproductor
- **Qué**: pantallas reales (biblioteca, detalle, búsqueda, reproductor,
  sync) sobre los providers.
- **Done when**: navegación completa con datos sincronizados; widget tests.
- **Depende de**: 3.1, 4.1.

### Tarea 6.2 [M] — Builds Android/iOS
- **Qué**: firma, permisos (cámara para QR, red local, almacenamiento),
  íconos; `flutter build apk`/`ipa`.
- **Done when**: APK instalable y build iOS válido; permisos mínimos.
- **Depende de**: 6.1.

---

## Secuencia global

```
0 ─► 1 ─► 2 ─► 3 ─► 4 ─► 5 ─► 6
                 └─ 4.2 depende de PC 3.2
Cada bloque del móvil se acopla al bloque homólogo del PC
(ver ../../nb_sound/docs/mobile-rollout-plan.md).
```

## Acoplamiento PC ↔ móvil

| Bloque móvil | Requiere del PC |
| --- | --- |
| 2 (pairing) | Servidor + `/pair` (PC BLOQUE 2) |
| 3 (sync) | `/manifest`, `/history` (PC BLOQUE 3) |
| 4.2 (offline) | `/track/{id}/audio` con Range (PC Tarea 3.2) |
| 5 (control) | WS `/control` (PC Tarea 3.4) |

Regla compartida: ningún cambio rompe el modo offline-first; la app móvil debe
funcionar sin PC en cualquier punto del desarrollo.
