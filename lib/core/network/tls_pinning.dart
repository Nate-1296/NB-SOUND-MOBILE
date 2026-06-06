import 'dart:io';

import 'package:crypto/crypto.dart';

/// Compara el certificado presentado contra la huella fijada (TOFU): el cert
/// se acepta solo si SHA-256(DER) == [fingerprintHex]. No valida CA ni hostname
/// (el PC usa un autofirmado persistido; docs/pc-contract.md §1).
bool certMatchesFingerprint(X509Certificate cert, String fingerprintHex) {
  final String digest = sha256.convert(cert.der).toString();
  return digest.toLowerCase() == fingerprintHex.toLowerCase();
}

/// HttpClient que solo acepta el certificado cuya huella SHA-256 coincide con
/// [fingerprintHex]. Si la huella es null/vacía (PC sin TLS), no se fija nada.
HttpClient pinnedHttpClient(String? fingerprintHex) {
  final HttpClient client = HttpClient();
  final String? fp = fingerprintHex;
  if (fp != null && fp.isNotEmpty) {
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) =>
            certMatchesFingerprint(cert, fp);
  }
  return client;
}
