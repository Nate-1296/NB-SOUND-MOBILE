import 'dart:io';

import 'package:flutter/widgets.dart';

/// Datos del PC emparejado necesarios para resolver media remota (portadas,
/// audio en streaming, letra, stems): URL base + token de autorización + huella
/// TLS. Lo provee `remoteMediaProvider` (features/sync) a partir del
/// emparejamiento activo; es null si no hay PC emparejado.
@immutable
class RemoteMedia {
  const RemoteMedia({
    required this.baseUrl,
    this.token,
    this.fingerprint,
  });

  /// `https://host:puerto` (o `http://` si el PC va sin TLS).
  final String baseUrl;

  /// `device_token` para `Authorization: Bearer`.
  final String? token;

  /// Huella SHA-256 del certificado fijado (TOFU); null si el PC va sin TLS.
  final String? fingerprint;

  /// Cabeceras de autorización para NetworkImage/just_audio, o null sin token.
  Map<String, String>? get authHeaders =>
      token == null ? null : <String, String>{'Authorization': 'Bearer $token'};

  /// Convierte una `*_url` del contrato (relativa `/api/...` o absoluta) en URL
  /// absoluta contra el PC.
  String urlFor(String relativeOrAbsolute) => relativeOrAbsolute.startsWith('http')
      ? relativeOrAbsolute
      : '$baseUrl$relativeOrAbsolute';

  @override
  bool operator ==(Object other) =>
      other is RemoteMedia &&
      other.baseUrl == baseUrl &&
      other.token == token &&
      other.fingerprint == fingerprint;

  @override
  int get hashCode => Object.hash(baseUrl, token, fingerprint);
}

/// Resuelve un `*_path` del catálogo a un [ImageProvider]:
/// - `assets/...` → [AssetImage] (portadas bundleadas / seed).
/// - `http...`    → [NetworkImage].
/// - `/api/...`   → portada remota del PC: [NetworkImage] absoluto con auth, si
///   hay un PC emparejado ([remote] != null); si no, null (respaldo en gris).
/// - otro         → [FileImage] (descarga offline / ruta local).
/// Devuelve null si no hay imagen mostrable (el llamador pinta el respaldo).
ImageProvider? coverImage(String? path, [RemoteMedia? remote]) {
  if (path == null || path.isEmpty) {
    return null;
  }
  if (path.startsWith('assets/')) {
    return AssetImage(path);
  }
  if (path.startsWith('http')) {
    return NetworkImage(path);
  }
  if (path.startsWith('/api/')) {
    // URL relativa del PC: solo resoluble con un PC emparejado (base + auth).
    if (remote == null) {
      return null;
    }
    return NetworkImage(remote.urlFor(path), headers: remote.authHeaders);
  }
  return FileImage(File(path));
}
