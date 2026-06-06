import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'qr_payload.freezed.dart';
part 'qr_payload.g.dart';

/// Contenido del QR de emparejamiento (docs/pc-contract.md §3).
@freezed
abstract class QrPairingPayload with _$QrPairingPayload {
  const QrPairingPayload._();

  const factory QrPairingPayload({
    required String host,
    required int puerto,
    required String token,
    @Default(1) int version,
    @Default(true) bool tls,
    @Default('') String tlsFingerprint,
    @Default('NB Sound') String servicio,
  }) = _QrPairingPayload;

  factory QrPairingPayload.fromJson(Map<String, dynamic> json) =>
      _$QrPairingPayloadFromJson(json);

  /// Intenta parsear el texto crudo del QR; devuelve null si no es válido.
  static QrPairingPayload? tryParse(String raw) {
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final QrPairingPayload p = QrPairingPayload.fromJson(decoded);
      if (p.host.isEmpty || p.puerto <= 0 || p.token.isEmpty) {
        return null;
      }
      return p;
    } catch (_) {
      // Entrada no confiable del QR: cualquier fallo de parseo → inválido.
      return null;
    }
  }

  /// Base de URLs HTTP (https si TLS activo).
  String get baseUrl => '${tls ? 'https' : 'http'}://$host:$puerto';

  /// Base de URLs WebSocket (wss si TLS activo).
  String get wsUrl => '${tls ? 'wss' : 'ws'}://$host:$puerto';

  /// Huella a fijar (TOFU) o null si el PC habla en claro.
  String? get pinnedFingerprint =>
      tls && tlsFingerprint.isNotEmpty ? tlsFingerprint : null;
}
