import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/sync/data/qr_payload.dart';

void main() {
  group('QrPairingPayload.tryParse', () {
    // Fixture del QR (docs/pc-contract.md §3).
    final String validJson = jsonEncode(<String, dynamic>{
      'host': '192.168.1.40',
      'puerto': 8731,
      'token': 'efimero-123',
      'version': 1,
      'tls': true,
      'tls_fingerprint':
          '9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08',
      'servicio': 'NB Sound',
    });

    test('parsea un QR válido y mapea snake_case', () {
      final QrPairingPayload? p = QrPairingPayload.tryParse(validJson);
      expect(p, isNotNull);
      expect(p!.host, '192.168.1.40');
      expect(p.puerto, 8731);
      expect(p.token, 'efimero-123');
      expect(p.tls, isTrue);
      expect(p.tlsFingerprint.length, 64);
    });

    test('deriva baseUrl/wsUrl según TLS', () {
      final QrPairingPayload p = QrPairingPayload.tryParse(validJson)!;
      expect(p.baseUrl, 'https://192.168.1.40:8731');
      expect(p.wsUrl, 'wss://192.168.1.40:8731');
      expect(p.pinnedFingerprint, isNotNull);
    });

    test('sin TLS usa http/ws y no fija huella', () {
      final String plain = jsonEncode(<String, dynamic>{
        'host': '10.0.0.5',
        'puerto': 8799,
        'token': 't',
        'tls': false,
        'tls_fingerprint': '',
      });
      final QrPairingPayload p = QrPairingPayload.tryParse(plain)!;
      expect(p.baseUrl, 'http://10.0.0.5:8799');
      expect(p.pinnedFingerprint, isNull);
    });

    test('rechaza JSON inválido o campos faltantes', () {
      expect(QrPairingPayload.tryParse('no-es-json'), isNull);
      expect(QrPairingPayload.tryParse('[1,2,3]'), isNull);
      expect(
        QrPairingPayload.tryParse(jsonEncode(<String, dynamic>{'host': ''})),
        isNull,
      );
    });
  });
}
