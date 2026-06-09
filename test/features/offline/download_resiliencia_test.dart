import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/offline/data/download_repository.dart';
import 'package:nb_sound_mobile/features/offline/data/offline_store.dart';

/// Adaptador que controla el resultado del audio: 404, o N cortes de red
/// transitorios antes de servir los bytes. El resto de recursos responden 404.
class _AudioAdapter implements HttpClientAdapter {
  _AudioAdapter({
    required this.audio,
    this.audioStatus = 200,
    this.fallosAudio = 0,
  });

  final Uint8List audio;
  final int audioStatus;
  int fallosAudio;
  int audioCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.uri.path;
    if (path.endsWith('/audio')) {
      audioCalls++;
      if (fallosAudio > 0) {
        fallosAudio--;
        // Error genérico ⇒ Dio lo envuelve como `unknown` (transitorio).
        throw Exception('corte de red simulado');
      }
      if (audioStatus == 404) {
        return ResponseBody.fromString(
          '{"error":"no_encontrado"}',
          404,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/json'],
          },
        );
      }
      return ResponseBody.fromBytes(
        audio,
        200,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>['application/octet-stream'],
          'content-length': <String>['${audio.length}'],
          'x-nb-sound-hash': <String>[sha256.convert(audio).toString()],
        },
      );
    }
    // lyrics / stems / cover / artist → 404 (no relevantes aquí).
    return ResponseBody.fromString(
      '{}',
      404,
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
  host: 'h',
  port: 8731,
  nombre: 'PC',
);

void main() {
  late AppDatabase db;
  late Directory dir;
  late OfflineStore store;
  final Uint8List audio =
      Uint8List.fromList(List<int>.generate(3000, (int i) => (i * 7) % 256));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('nb_resi');
    store = OfflineStore(dir);
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
        id: const Value(1),
        titulo: 'X',
        artistaNombre: 'A',
        hashSha256: Value(sha256.convert(audio).toString()),
      ),
    ]);
  });
  tearDown(() async {
    await db.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  DownloadRepository repoWith(_AudioAdapter adapter) => DownloadRepository(
        db: db,
        store: store,
        dioFor: (PairedPc pc) {
          final Dio d = Dio(BaseOptions(baseUrl: pc.baseUrl));
          d.httpClientAdapter = adapter;
          return d;
        },
      );

  test('audio 404 ⇒ unavailable (no failed) y sin archivo', () async {
    final DownloadRepository repo =
        repoWith(_AudioAdapter(audio: audio, audioStatus: 404));
    final Pista pista = (await db.catalogDao.getPista(1))!;

    await repo.descargarPista(_pc, pista);

    final DescargaAudio? d = await db.downloadsDao.getEstado(1);
    expect(d?.estado, DownloadEstado.unavailable);
    expect(await store.audioFile(1).exists(), isFalse);
  });

  test('reintenta un corte de red transitorio y completa la descarga',
      () async {
    final _AudioAdapter adapter = _AudioAdapter(audio: audio, fallosAudio: 1);
    final DownloadRepository repo = repoWith(adapter);
    final Pista pista = (await db.catalogDao.getPista(1))!;

    final File f = await repo.download(_pc, pista);

    expect(await f.exists(), isTrue);
    expect(adapter.audioCalls, 2, reason: '1 fallo transitorio + 1 éxito');
    expect((await db.downloadsDao.getEstado(1))?.estado, DownloadEstado.done);
  });

  test('agota los reintentos ante fallos persistentes y propaga el error',
      () async {
    final _AudioAdapter adapter = _AudioAdapter(audio: audio, fallosAudio: 99);
    final DownloadRepository repo = repoWith(adapter);
    final Pista pista = (await db.catalogDao.getPista(1))!;

    await expectLater(repo.download(_pc, pista), throwsA(anything));
    // Máximo 3 intentos (backoff acotado); no reintenta indefinidamente.
    expect(adapter.audioCalls, 3);
  });
}
