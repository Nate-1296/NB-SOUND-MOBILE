# NB Sound Mobile

App móvil (Flutter — Android, iOS y tablets) del ecosistema **NB Sound**.

Acompaña a la app de escritorio NB Sound. **El PC es la fuente de verdad** de
la metadata enriquecida (catálogo, portadas, lyrics, audio features, stems de
karaoke); **el celular es la fuente de verdad** de su historial y favoritos
locales. La sincronización es **local por WiFi**, iniciada por **QR**. El
audio puede transferirse para **escucha offline**, y con ambos conectados hay
**control remoto bidireccional** del reproductor (estilo Spotify Connect).

> Estado: **MVP local + emparejamiento** (Bloques 0–4 y 2 del plan).
> Offline-first: navega su biblioteca local (Drift), reproduce audio en
> background (just_audio + audio_service) y registra historial/favoritos sin PC.
> **Emparejamiento + sincronización** implementados: escaneo de QR
> (`mobile_scanner`), `POST /api/v1/pair`, pinning TLS por huella (TOFU) en
> `dio`, credenciales en `flutter_secure_storage`, reconexión por mDNS (`nsd`);
> y **sync delta**: `GET /api/v1/manifest` paginado aplicado en transacción Drift
> (upsert + tombstones + reconciliación de favoritos last-write-wins), subida de
> historial/favoritos (`POST /api/v1/history`) y selección negociable
> (`/api/v1/seleccion`); y **descarga offline**: `GET /api/v1/track/{id}/audio`
> con `Range` reanudable + validación `hash_sha256`, cola de descargas por
> pista/álbum/playlist y reproducción desde el archivo local; y **control remoto**
> (Spotify Connect): WebSocket `/api/v1/control` (WSS con pinning por huella),
> refleja el estado del PC y envía comandos, con selector de destino "Este
> teléfono"/"Mi PC". Todos los bloques del plan (0–5) están implementados y
> probados contra [`docs/pc-contract.md`](docs/pc-contract.md). La contraparte de
> escritorio está en `../nb_sound/docs/mobile-ecosystem.md`.
>
> En desarrollo, un **seed** (`lib/data/db/seed/dev_seed.dart`, gated por
> `kSeedDevData`) puebla la BD con un catálogo de ejemplo y audio bundleado para
> ejercitar la app sin PC; se retira cuando la sync provee datos reales.
>
> **Preview en Linux desktop** (`flutter run -d linux`): la UI corre sin audio
> (just_audio/audio_service no soportan escritorio; hay un guard de plataforma).
> El target de verificación fiel sigue siendo Android.

## Estructura del proyecto

```text
nb_sound_mobile/
├── pubspec.yaml              # Dependencias y metadatos del paquete
├── analysis_options.yaml     # Lints (flutter_lints + reglas del proyecto)
├── README.md
├── docs/                     # Documentación de implementación
│   ├── app-state.md          # ★ Estado real as-built (qué hay, verificado, faltantes)
│   ├── pc-contract.md        # ★ Contrato as-built del PC (FUENTE DE VERDAD)
│   ├── architecture.md       # Arquitectura de la app móvil
│   ├── sync-protocol.md      # Cliente del protocolo de sync (espejo del PC)
│   ├── local-data.md         # BD local, fuente de verdad de favoritos/historial
│   ├── remote-control.md     # Control remoto (Spotify Connect)
│   └── implementation-plan.md# Plan de implementación móvil por bloques
├── lib/
│   ├── main.dart             # Entry point
│   ├── core/                 # Config, DI, routing, errores, utilidades
│   ├── data/                 # Repositorios, fuentes (local/remota), modelos
│   ├── features/             # Feature-first: cada feature autocontenida
│   │   ├── library/          # Catálogo: artistas, álbumes, pistas, búsqueda
│   │   ├── player/           # Reproductor local (just_audio + audio_service)
│   │   ├── sync/             # Descubrimiento (QR/mDNS), handshake, sync delta
│   │   ├── remote_control/   # Control del reproductor del PC vía WebSocket
│   │   └── offline/          # Transferencia y gestión de audio offline
│   └── shared/               # Widgets y tema compartidos
│       ├── widgets/
│       └── theme/
└── test/                     # Tests unitarios y de widget
```

## Arquitectura (resumen)

- **Patrón**: feature-first + capas (presentación → dominio → datos).
- **Estado**: Riverpod (testable, sin context para la lógica).
- **BD local**: Drift (SQLite type-safe).
- **Audio**: `just_audio` + `audio_service` (reproducción en background).
- **Red**: `dio` (HTTP) + `web_socket_channel` (control remoto).
- **QR**: `mobile_scanner` (escaneo). **mDNS**: `nsd`/`multicast_dns`.

Detalle en [`docs/architecture.md`](docs/architecture.md).

## Cómo construir y correr

Requiere el toolchain de Flutter (stable ≥ 3.29) + Android SDK 36. Las
plataformas (`android/`, `ios/`, `linux/`) ya están generadas.

```bash
flutter pub get
dart run build_runner build              # codegen (drift, freezed, json)
flutter analyze && flutter test          # lint + tests (datos + widget)
flutter run -d <emulador-o-dispositivo>  # Android es el target verificado
```

> El codegen es necesario tras tocar tablas Drift, DTOs freezed o providers; los
> `*.g.dart`/`*.freezed.dart` están en `.gitignore`. iOS requiere macOS para
> compilar.

## Empaquetar (refrescar `build/` y `dist/`)

Reconstruye el APK de release desde cero y deja `dist/` al día (limpia los
artefactos anteriores). La versión sale de `pubspec.yaml`, así los nombres no
quedan obsoletos al subir `version:`.

```bash
# 1) Limpiar artefactos previos
flutter clean
rm -f dist/*.apk

# 2) Dependencias + codegen
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 3) Compilar release: universal + por ABI
flutter build apk --release                  # → app-release.apk (universal)
flutter build apk --release --split-per-abi  # → app-<abi>-release.apk

# 4) Empaquetar en dist/ con el nombre de release
mkdir -p dist
VER=$(sed -nE 's/^version: *([0-9.]+).*/\1/p' pubspec.yaml)
APK=build/app/outputs/flutter-apk
cp "$APK/app-release.apk"            "dist/NB-Sound-$VER-universal.apk"
cp "$APK/app-arm64-v8a-release.apk"   "dist/NB-Sound-$VER-arm64-v8a.apk"
cp "$APK/app-armeabi-v7a-release.apk" "dist/NB-Sound-$VER-armeabi-v7a.apk"
```

> `build/` y `dist/` son artefactos (no se versionan). El release de tienda usa
> App Bundle: `flutter build appbundle --release`. Firma, política de assets e
> instalación en [`docs/release.md`](docs/release.md).

## Relación con el escritorio

| Tema | Dónde se especifica |
| --- | --- |
| **Contrato as-built del PC (endpoints/JSON/WS exactos, v1.1.0)** | [`docs/pc-contract.md`](docs/pc-contract.md) ← codificar contra este |
| Servidor local, endpoints, QR, schema BD, vista de sync (PC) | `../nb_sound/docs/mobile-ecosystem.md` |
| Plan de implementación del PC | `../nb_sound/docs/mobile-rollout-plan.md` |
| Compatibilidad cross-platform (PC) | `../nb_sound/docs/cross-platform.md` |
| App móvil (esta) | `docs/` de este proyecto |
