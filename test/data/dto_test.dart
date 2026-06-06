import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/models/history_dto.dart';
import 'package:nb_sound_mobile/data/models/manifest_dto.dart';

void main() {
  group('PistaDto', () {
    // Fixture tomado de docs/pc-contract.md §4.3.
    final Map<String, dynamic> pistaJson = <String, dynamic>{
      'id': 123,
      'titulo': 'One More Time',
      'artista_nombre': 'Daft Punk',
      'album_titulo': 'Discovery',
      'album_id': 10,
      'artista_id': 5,
      'track_number': 1,
      'duracion_seg': 320.4,
      'anio': 2001,
      'genero': 'House',
      'isrc': 'GBDUW0000059',
      'mb_recording_id': '....',
      'favorita': false,
      'favorita_actualizada_en': '2026-05-30T10:00:00.000Z',
      'hash_sha256': 'ab12...',
      'sync_version': 40,
      'bpm': 123.0,
      'energy': 0.82,
      'key': 'F#',
      'audio_url': '/api/v1/track/123/audio',
      'cover_url': '/api/v1/asset/cover/10',
      'lyrics_url': '/api/v1/track/123/lyrics',
    };

    test('mapea snake_case del contrato', () {
      final PistaDto p = PistaDto.fromJson(pistaJson);
      expect(p.id, 123);
      expect(p.artistaNombre, 'Daft Punk');
      expect(p.trackNumber, 1);
      expect(p.duracionSeg, 320.4);
      expect(p.hashSha256, 'ab12...');
      expect(p.syncVersion, 40);
      expect(p.key, 'F#');
      expect(p.audioUrl, '/api/v1/track/123/audio');
    });

    test('round-trip JSON↔DTO es estable', () {
      final PistaDto p = PistaDto.fromJson(pistaJson);
      final PistaDto p2 = PistaDto.fromJson(p.toJson());
      expect(p2, p);
    });

    test('tolera duracion_seg entera y campos ausentes', () {
      final PistaDto p = PistaDto.fromJson(<String, dynamic>{
        'id': 1,
        'titulo': 'X',
        'duracion_seg': 200,
        'campo_desconocido_futuro': 'ignorado',
      });
      expect(p.duracionSeg, 200.0);
      expect(p.artistaNombre, '');
      expect(p.coverUrl, isNull);
    });
  });

  group('ManifestDto', () {
    test('parsea encabezado, listas y tombstones', () {
      final ManifestDto m = ManifestDto.fromJson(<String, dynamic>{
        'protocolo': 1,
        'since': 0,
        'sync_version_actual': 42,
        'sync_version': 42,
        'next_since': 20,
        'has_more': true,
        'generado_en': '2026-05-30T15:00:00.000Z',
        'pistas': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'titulo': 'A'},
        ],
        'tombstones': <Map<String, dynamic>>[
          <String, dynamic>{
            'entidad': 'pista',
            'entidad_id': 7,
            'sync_version': 41,
          },
        ],
        'perfil': <String, dynamic>{
          'nombre': 'Jonathan',
          'estadisticas': <String, dynamic>{
            'total_pistas': 1200,
            'total_favoritas': 80,
          },
        },
      });
      expect(m.syncVersionActual, 42);
      expect(m.nextSince, 20);
      expect(m.hasMore, isTrue);
      expect(m.pistas.single.titulo, 'A');
      expect(m.tombstones.single.entidadId, 7);
      expect(m.perfil?.estadisticas?.totalPistas, 1200);
    });

    test('aplica defaults con payload mínimo', () {
      final ManifestDto m = ManifestDto.fromJson(<String, dynamic>{});
      expect(m.protocolo, 1);
      expect(m.pistas, isEmpty);
      expect(m.hasMore, isFalse);
    });
  });

  group('history DTOs', () {
    test('request serializa historial y favoritos', () {
      const HistoryUploadRequest req = HistoryUploadRequest(
        historial: <HistorialItemDto>[
          HistorialItemDto(
            pistaId: 123,
            reproducidoEn: '2026-05-30T10:00:00.000Z',
            duracionSeg: 200,
            completada: true,
          ),
        ],
        favoritos: <FavoritoItemDto>[
          FavoritoItemDto(
            pistaId: 123,
            favorita: true,
            actualizadaEn: '2026-05-30T10:00:00.000Z',
          ),
        ],
      );
      final Map<String, dynamic> json = req.toJson();
      expect(
        (json['historial'] as List<dynamic>).single,
        containsPair('pista_id', 123),
      );
      expect(
        (json['favoritos'] as List<dynamic>).single,
        containsPair('actualizada_en', '2026-05-30T10:00:00.000Z'),
      );
    });

    test('response parsea contadores', () {
      final HistoryUploadResponse r =
          HistoryUploadResponse.fromJson(<String, dynamic>{
        'ok': true,
        'historial_insertado': 1,
        'favoritos_aplicados': 1,
        'favoritos_ignorados': 0,
      });
      expect(r.ok, isTrue);
      expect(r.historialInsertado, 1);
      expect(r.favoritosAplicados, 1);
    });
  });
}
