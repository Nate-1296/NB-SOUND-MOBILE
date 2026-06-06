import 'dart:io';

import 'tls_pinning.dart';

/// Override global de [HttpClient] que aplica pinning TLS por huella (TOFU) a
/// las rutas que NO pasan por `dio` —en particular `NetworkImage` (portadas
/// remotas) y el proxy interno de `just_audio` (streaming de audio/stems)—, que
/// usan el `HttpClient` de `dart:io` y consultan [HttpOverrides.global].
///
/// `dio` ya hace su propio pinning en [NbApiClient] (no pasa por aquí). El PC es
/// único, así que basta una huella global [fingerprint], que se actualiza al
/// emparejar/reconectar (ver `NbSoundApp`). Si es null (sin TLS), no se fija nada.
class NbHttpOverrides extends HttpOverrides {
  /// Huella SHA-256 del certificado del PC emparejado, o null.
  static String? fingerprint;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final HttpClient client = super.createHttpClient(context);
    // El callback se fija SIEMPRE y lee la huella EN VIVO: Flutter crea un único
    // HttpClient compartido para NetworkImage la primera vez, que puede ocurrir
    // antes de conocer la huella (carga async del emparejamiento). Capturar el
    // valor aquí lo dejaría fijado a null para siempre; en su lugar se consulta
    // [fingerprint] en cada validación, ya con el PC resuelto.
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      final String? fp = fingerprint;
      return fp != null && fp.isNotEmpty && certMatchesFingerprint(cert, fp);
    };
    return client;
  }
}
