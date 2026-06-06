import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/sync/data/sync_repository.dart';

/// Adaptador HTTP programable: enruta por método + path + query.
class _RouteAdapter implements HttpClientAdapter {
  _RouteAdapter(this.handler);
  final (int, Map<String, dynamic>) Function(RequestOptions) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (int status, Map<String, dynamic> body) = handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const PairedPc _pc = PairedPc(
  deviceToken: 't',
  fingerprint: 'fp',
  host: '192.168.1.40',
  port: 8731,
  nombre: 'PC',
);

SyncRepository _repoWith(
  AppDatabase db,
  (int, Map<String, dynamic>) Function(RequestOptions) handler,
) {
  final _RouteAdapter adapter = _RouteAdapter(handler);
  return SyncRepository(
    db: db,
    dioFor: (PairedPc pc) {
      final Dio dio = Dio(BaseOptions(baseUrl: pc.baseUrl));
      dio.httpClientAdapter = adapter;
      return dio;
    },
  );
}

Map<String, dynamic> _pista(int id, String titulo,
        {bool favorita = false, String? favTs}) =>
    <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'artista_nombre': 'Artista',
      'sync_version': id,
      'favorita': favorita,
      'favorita_actualizada_en': ?favTs,
      'audio_url': '/api/v1/track/$id/audio',
      'cover_url': '/api/v1/asset/cover/$id',
    };

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test('sync aplica altas/cambios + tombstones y avanza la versión', () async {
    // Pista preexistente que el PC borrará vía tombstone.
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
        id: const Value(999),
        titulo: 'Vieja',
        artistaNombre: 'X',
      ),
    ]);

    int sinceOf(RequestOptions o) =>
        int.parse('${o.queryParameters['since'] ?? 0}');

    final SyncRepository repo = _repoWith(db, (RequestOptions o) {
      if (o.path.contains('/history')) {
        return (200, <String, dynamic>{'ok': true});
      }
      // manifest paginado: página 1 (since 0) y página 2 (since 20).
      if (sinceOf(o) == 0) {
        return (
          200,
          <String, dynamic>{
            'has_more': true,
            'next_since': 20,
            'sync_version_actual': 42,
            'artistas': <Map<String, dynamic>>[
              <String, dynamic>{'id': 1, 'nombre': 'Daft Punk', 'sync_version': 1},
            ],
            'albums': <Map<String, dynamic>>[
              <String, dynamic>{'id': 10, 'titulo': 'Discovery', 'sync_version': 2},
            ],
            'pistas': <Map<String, dynamic>>[_pista(100, 'One More Time')],
          }
        );
      }
      return (
        200,
        <String, dynamic>{
          'has_more': false,
          'next_since': 42,
          'sync_version_actual': 42,
          'pistas': <Map<String, dynamic>>[_pista(101, 'Aerodynamic')],
          'tombstones': <Map<String, dynamic>>[
            <String, dynamic>{'entidad': 'pista', 'entidad_id': 999},
          ],
        }
      );
    });

    final SyncResult r = await repo.sync(_pc);

    expect(r.syncVersion, 42);
    final List<Pista> pistas = await db.catalogDao.watchPistas().first;
    final Set<int> ids = pistas.map((Pista p) => p.id).toSet();
    expect(ids, containsAll(<int>[100, 101]));
    expect(ids.contains(999), isFalse); // borrada por tombstone
    expect((await db.catalogDao.watchAlbums().first).length, 1);
    expect(await db.syncStateDao.getUltimaSyncVersion(), 42);
  });

  test('sync reconcilia favoritos last-write-wins (PC más nuevo gana)',
      () async {
    // Local: pista 100 favorita desde el 1-ene (antiguo).
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
          id: const Value(100), titulo: 'X', artistaNombre: 'A'),
    ]);
    await db.favoritesDao.setFavorita(100, true, cuando: DateTime.utc(2026, 1, 1));

    final SyncRepository repo = _repoWith(db, (RequestOptions o) {
      if (o.path.contains('/history')) {
        return (200, <String, dynamic>{'ok': true});
      }
      // El PC dice: no favorita, actualizado el 1-feb (más nuevo) → gana.
      return (
        200,
        <String, dynamic>{
          'has_more': false,
          'sync_version_actual': 5,
          'pistas': <Map<String, dynamic>>[
            _pista(100, 'X',
                favorita: false, favTs: '2026-02-01T00:00:00.000Z'),
          ],
        }
      );
    });

    await repo.sync(_pc);
    expect(await db.favoritesDao.esFavorita(100), isFalse);
  });

  test('sync sube historial/favoritos no subidos y los marca subidos',
      () async {
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
          id: const Value(7), titulo: 'X', artistaNombre: 'A'),
    ]);
    await db.historyDao.registrarReproduccion(7);
    await db.favoritesDao.setFavorita(7, true);

    Map<String, dynamic>? sentBody;
    final SyncRepository repo = _repoWith(db, (RequestOptions o) {
      if (o.path.contains('/history')) {
        sentBody = o.data as Map<String, dynamic>;
        return (
          200,
          <String, dynamic>{
            'ok': true,
            'historial_insertado': 1,
            'favoritos_aplicados': 1,
          }
        );
      }
      return (200, <String, dynamic>{'has_more': false, 'sync_version_actual': 0});
    });

    final SyncResult r = await repo.sync(_pc);

    expect((sentBody?['historial'] as List<dynamic>).length, 1);
    expect((sentBody?['favoritos'] as List<dynamic>).length, 1);
    expect(r.historialSubido, 1);
    expect(await db.historyDao.noSubidos(), isEmpty);
    expect(await db.favoritesDao.noSubidos(), isEmpty);
  });

  test('sync es reanudable: reaplica la página y completa tras un fallo',
      () async {
    int sinceOf(RequestOptions o) =>
        int.parse('${o.queryParameters['since'] ?? 0}');
    bool failedOnce = false;

    final SyncRepository repo = _repoWith(db, (RequestOptions o) {
      if (o.path.contains('/history')) {
        return (200, <String, dynamic>{'ok': true});
      }
      if (sinceOf(o) == 0) {
        return (
          200,
          <String, dynamic>{
            'has_more': true,
            'next_since': 20,
            'sync_version_actual': 30,
            'pistas': <Map<String, dynamic>>[_pista(100, 'Uno')],
          }
        );
      }
      // La 2ª página falla la primera vez (corte de red simulado).
      if (!failedOnce) {
        failedOnce = true;
        return (503, <String, dynamic>{'error': 'corte'});
      }
      return (
        200,
        <String, dynamic>{
          'has_more': false,
          'sync_version_actual': 30,
          'pistas': <Map<String, dynamic>>[_pista(101, 'Dos')],
        }
      );
    });

    // Primer intento falla en la 2ª página; no se avanza la versión.
    await expectLater(repo.sync(_pc), throwsA(isA<DioException>()));
    expect(await db.syncStateDao.getUltimaSyncVersion(), 0);
    expect((await db.catalogDao.watchPistas().first).length, 1); // página 1 aplicada

    // Reintento: reaplica página 1 (idempotente) y completa.
    final SyncResult r = await repo.sync(_pc);
    expect(r.syncVersion, 30);
    final List<int> ids =
        (await db.catalogDao.watchPistas().first).map((Pista p) => p.id).toList()
          ..sort();
    expect(ids, <int>[100, 101]); // sin duplicados
    expect(await db.syncStateDao.getUltimaSyncVersion(), 30);
  });
}
