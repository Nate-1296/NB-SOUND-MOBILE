# Arquitectura — NB Sound Mobile

App Flutter para Android, iOS y tablets. Cliente del ecosistema NB Sound; la
contraparte (servidor, protocolo, schema) la define el PC en
`../../nb_sound/docs/mobile-ecosystem.md`.

> **Este documento describe el diseño/intención.** El estado real implementado y
> sus desviaciones están en [`app-state.md`](app-state.md). Resumen as-built
> (2026-06-04, Bloques 0–5 code-complete):
> - **Estructura real:** `lib/{core,data,shared}` + `lib/features/{library,
>   player,offline,sync,remote_control,profile}` + `lib/app` (shell + widget raíz).
> - **Estado/DI:** Riverpod 3 con `Notifier`/`NotifierProvider` (hand-written) y
>   `Provider`/`StreamProvider`/`FutureProvider.family`. `databaseProvider`,
>   `audioHandlerProvider` y `appAudioDirProvider` se sobreescriben en `main`.
> - **Iconos:** Material Icons (`shared/widgets/app_icons.dart`), no una librería
>   stroke (lucide_icons no compila con Flutter 3.44).
> - **Audio:** `NbAudioHandler` con modo `preview` (sin audio en escritorio/web).
> - **Reproductor unificado local/remoto:** `features/player/application/
>   playback.dart` (`PlaybackTarget`, `nowPlayingProvider`, `PlaybackActions`).
> - **Verificación:** lo local está probado en emulador Android; **todo lo que
>   habla con el PC está testeado contra simulaciones, no contra el PC real.**

## Principios

1. **El PC manda en metadata; el celular manda en su historial y favoritos.**
   La capa de datos respeta esta dirección en cada merge.
2. **Offline-first.** La app funciona sin el PC: reproduce lo descargado, usa
   su BD local. La sync enriquece, no es requisito para usar la app.
3. **La UI nunca bloquea.** Red, BD y audio en capas async; la presentación
   solo observa estado (Riverpod).
4. **Sin acoplar a una sesión.** El descubrimiento del PC es oportunista: si
   está, se habilita sync y control remoto; si no, la app sigue local.

## Capas

```text
Presentación (features/*/presentation)   widgets + providers Riverpod
        │  observa estado, despacha intents
        ▼
Aplicación/Dominio (features/*/application, data/repositories)
        │  reglas de negocio y merge
        ▼
Datos (data/sources: local Drift, remote dio/WS)
        │
        ▼
  SQLite local  ·  PC (HTTP/WS por WiFi)
```

- **Feature-first**: cada feature (`library`, `player`, `sync`,
  `remote_control`, `offline`) es autocontenida.
- **`core/`** provee config, DI, routing, errores y utils; no depende de
  features.
- **`data/`** es compartida: esquema Drift, DTOs del protocolo, repositorios.

## Decisiones técnicas

| Área | Elección | Motivo |
| --- | --- | --- |
| Estado | **Riverpod** (+ codegen) | Testable, sin BuildContext en lógica, providers componibles |
| Navegación | **go_router** | Rutas declarativas, deep links |
| BD local | **Drift** (SQLite) | Type-safe, migraciones, reactiva |
| Audio | **just_audio + audio_service** | Background, lockscreen, cola |
| HTTP | **dio** | Interceptores (auth token), soporte `Range` |
| WebSocket | **web_socket_channel** | Control remoto en tiempo real |
| QR | **mobile_scanner** | Emparejamiento por escaneo |
| mDNS | **nsd** | Reconexión a PC ya emparejado |
| Modelos | **freezed + json_serializable** | Inmutables, (de)serialización segura |

## Modos de operación

1. **Local puro** (sin PC): reproduce audio offline, navega su biblioteca
   local, registra historial/favoritos.
2. **Conectado al PC** (mismo WiFi, emparejado):
   - **Sync**: descarga delta de catálogo y sube historial/favoritos.
   - **Streaming**: reproduce pistas no descargadas desde el PC.
   - **Control remoto**: comanda el reproductor del PC (Spotify Connect).
3. **Transferencia offline**: selecciona pistas/álbumes/playlists y descarga
   su audio (reanudable) para el modo local puro.

## Flujo de emparejamiento (resumen)

```text
PC: enciende servidor → muestra QR (host, puerto, token efímero, fingerprint TLS)
Móvil: escanea QR → POST /pair (token) → recibe device_token persistente
Móvil: guarda device_token + fingerprint (TOFU) en BD local segura
Reconexión: mDNS descubre el PC → usa device_token guardado
```

Detalle del cliente en [`sync-protocol.md`](sync-protocol.md);
BD local en [`local-data.md`](local-data.md);
control remoto en [`remote-control.md`](remote-control.md).

## Testing

- **Unit**: repositorios y reglas de merge (PC vs celular) con fuentes mock.
- **Widget**: pantallas clave (biblioteca, reproductor, sync).
- **Integración**: cliente de sync contra un servidor PC simulado (o el real
  en CI con la app de escritorio headless).
