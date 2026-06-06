# Empaquetado y release (Android)

Cómo construir el APK de producción de `nb_sound_mobile`, cómo está firmado y qué
política de assets se aplica. iOS queda fuera (requiere macOS).

Última actualización: 2026-06-06. Bloque 6.2 (empaquetado Android) completo.

---

## Identidad de la app

| Campo | Valor |
| --- | --- |
| `applicationId` / package | `com.nbsound.nb_sound_mobile` |
| Nombre visible | NB Sound |
| `versionName` / `versionCode` | `0.1.0` / `1` (desde `pubspec.yaml`: `version: 0.1.0+1`) |
| `minSdk` / `targetSdk` / `compileSdk` | los de Flutter (target/compile 36) |
| Ícono | logo NB Sound (adaptativo: fondo terracota `#C25939` + silueta) |

La versión se gobierna **solo** desde `pubspec.yaml` (`version: x.y.z+build`). Para
publicar una actualización hay que subir el `+build` (versionCode) y normalmente
`x.y.z` (versionName).

---

## Firma (keystore release)

La build de release se firma con una **keystore propia** (no la debug). Es
production-quality: la app es actualizable y queda lista para tienda.

- Keystore: `android/nb-sound-release.jks` (alias `nbsound`, RSA 2048, validez
  10000 días).
- Credenciales: `android/key.properties` (`storePassword`, `keyPassword`,
  `keyAlias`, `storeFile=../nb-sound-release.jks`).
- Gradle (`android/app/build.gradle.kts`) carga `key.properties` y firma release
  con esa config. **Si `key.properties` no existe** (otra máquina sin la
  keystore), recae en la firma debug para no bloquear el desarrollo — pero ese
  APK **no** sirve para tienda ni para actualizar el instalado.
- Huella del certificado (SHA-256):
  `00:59:0F:10:20:E1:E9:1C:33:74:E3:D2:22:11:D2:48:0D:73:32:F5:F8:29:01:AC:0E:5F:BD:19:49:3B:F7:2D`

> **CUSTODIA (crítico).** `nb-sound-release.jks` y su contraseña son la identidad
> de firma de la app. Si se pierden, **no se puede publicar otra actualización**
> con la misma identidad en Play Store (habría que publicar como app nueva).
> Ambos están en `android/.gitignore` (`key.properties`, `*.jks`, `*.keystore`):
> **no** se versionan. Respaldarlos fuera del repo (gestor de secretos / copia
> cifrada).

---

## Política de assets (no empaquetar datos de prueba)

El APK **no** incluye media de catálogo: audio y portadas llegan del PC vía
sync/streaming. En `pubspec.yaml` **no** se declaran `assets/audio`,
`assets/covers` ni `assets/images` (el logo es solo fuente del ícono, build-time).
Únicamente se empaquetan las **fuentes** de UI (Space Grotesk, Manrope).

El seed de desarrollo (`NB_SEED`) sigue existiendo pero, al no empaquetarse su
media, solo siembra metadata (sin audio reproducible ni portadas). Para una demo
offline completa hay que re-declarar temporalmente `assets/audio` y
`assets/covers`. Verificación: el APK no contiene `assets/covers|audio|images`
(solo `assets/flutter_assets/assets/fonts/*`).

---

## Ícono

Generado con `flutter_launcher_icons` (dev_dependency) desde el logo NB Sound:

```bash
dart run flutter_launcher_icons
```

Config en `pubspec.yaml` (`flutter_launcher_icons:`): `image_path` y
`adaptive_icon_foreground` = `assets/images/logo_lg.png`; `adaptive_icon_background`
= `#C25939` (terracota de marca). La herramienta aplica un inset del 16% al
foreground (zona segura), por eso se pasa el logo completo, no uno pre-reducido.
Salida: `android/app/src/main/res/mipmap-*/ic_launcher.png`, el adaptativo en
`mipmap-anydpi-v26/ic_launcher.xml` y `values/colors.xml`.

---

## Construir el APK

Requiere el toolchain (Flutter stable, Android SDK 36, JDK 17). En los shells del
harness, exportar antes `PATH`/`ANDROID_HOME`/`JAVA_HOME`.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # si cambió codegen
flutter analyze && flutter test                            # 49 tests

# Universal (todas las ABIs en un APK; ~77 MB):
flutter build apk --release
#  → build/app/outputs/flutter-apk/app-release.apk

# Por ABI (más liviano; recomendado para sideload):
flutter build apk --release --split-per-abi
#  → app-arm64-v8a-release.apk    (~30 MB)  ← teléfonos modernos
#  → app-armeabi-v7a-release.apk  (~25 MB)  ← teléfonos 32-bit antiguos
#  → app-x86_64-release.apk       (~32 MB)  ← emuladores
```

Con `--split-per-abi`, Flutter desplaza el `versionCode` por ABI (p. ej. arm64 →
`2001`) para que convivan en Play; es esperado, no un error.

Para Play Store, preferir App Bundle: `flutter build appbundle --release`
(`build/app/outputs/bundle/release/app-release.aab`).

Copias listas para transferir en `dist/` (artefacto de build; no versionar):
`NB-Sound-0.1.0-arm64-v8a.apk` (recomendado), `-armeabi-v7a`, `-universal`.

---

## Instalar en el teléfono

1. Transferir `dist/NB-Sound-0.1.0-arm64-v8a.apk` al teléfono (USB, descarga, etc.).
2. En el teléfono, permitir "instalar apps de orígenes desconocidos" para el
   gestor de archivos/navegador usado.
3. Abrir el APK e instalar. La primera vez NB Sound aparece vacía: ir a
   **Sincronizar con PC** y escanear el QR de la app de escritorio.

Vía adb con el teléfono conectado y depuración USB activa:

```bash
adb install -r dist/NB-Sound-0.1.0-arm64-v8a.apk
```

---

## Notas

- **Warning KGP**: `audio_session`, `mobile_scanner`, `nsd_android` aplican el
  Kotlin Gradle Plugin a la antigua. Solo es un aviso (futuras versiones de
  Flutter lo exigirán); hoy compila. Migración pendiente cuando los plugins
  publiquen versiones compatibles con "Built-in Kotlin".
- **Warning CupertinoIcons**: el tree-shaker menciona `CupertinoIcons` sin la
  fuente. No hay uso de Cupertino en el código (target Android, íconos Material);
  proviene de referencias del framework cuyos glifos no se muestran. Benigno.
- No se habilita R8/`minifyEnabled` (default de Flutter) para no arriesgar los
  plugins nativos (just_audio, drift, mobile_scanner) sin reglas ProGuard
  específicas. Optimización futura si se requiere reducir tamaño.
- **Escáner QR / ML Kit**: se usa el modelo **unbundled** de Google Play Services
  (`dev.steenbakker.mobile_scanner.useUnbundled=true` en `android/gradle.properties`
  + meta-data `com.google.mlkit.vision.DEPENDENCIES=barcode` en el manifest), no el
  bundled, porque el bundled producía un NPE nativo al iniciar la cámara en
  dispositivo. Implica que el módulo de barcode lo provee/actualiza Play Services;
  en instalaciones por **sideload** se descarga la primera vez que se abre el
  escáner (requiere conexión a internet esa vez). Esto reduce el APK ~6 MB.
