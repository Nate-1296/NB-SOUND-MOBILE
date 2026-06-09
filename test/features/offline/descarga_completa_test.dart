import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/data/db/daos/assets_dao.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/lyrics/data/lyrics_models.dart';
import 'package:nb_sound_mobile/features/offline/data/download_repository.dart';
import 'package:nb_sound_mobile/features/offline/data/offline_store.dart';

/// Adaptador que enruta por ruta y permite simular 200/404 por recurso, contando
/// las peticiones para verificar la descarga incremental (no rebaja lo ya hecho).
class _FullAdapter implements HttpClientAdapter {
  _FullAdapter({
    required this.audio,
    this.coverStatus = 200,
    this.artistStatus = 200,
    this.lyricsStatus = 200,
    this.stemsStatus = 200,
  });

  final Uint8List audio;
  final int coverStatus;
  final int artistStatus;
  final int lyricsStatus;
  final int stemsStatus;
  final String syncedLyrics = '[00:01.00] hola';

  final Map<String, int> calls = <String, int>{};
  final Uint8List _img = Uint8List.fromList(<int>[1, 2, 3, 4]);
  final Uint8List _stem = Uint8List.fromList(
      List<int>.generate(800, (int i) => (i * 13) % 256));

  void resetCalls() => calls.clear();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String path = options.uri.path;
    final String key = _key(path);
    calls[key] = (calls[key] ?? 0) + 1;

    final Map<String, List<String>> json = <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/json'],
    };

    switch (key) {
      case 'audio':
        return ResponseBody.fromBytes(
          audio,
          200,
          headers: <String, List<String>>{
            Headers.contentTypeHeader: <String>['application/octet-stream'],
            'content-length': <String>['${audio.length}'],
            'x-nb-sound-hash': <String>[sha256.convert(audio).toString()],
          },
        );
      case 'cover':
        return coverStatus == 200
            ? ResponseBody.fromBytes(_img, 200)
            : ResponseBody.fromString('{"error":"no_encontrado"}', 404,
                headers: json);
      case 'artist':
        return artistStatus == 200
            ? ResponseBody.fromBytes(_img, 200)
            : ResponseBody.fromString('{"error":"no_encontrado"}', 404,
                headers: json);
      case 'lyrics':
        return lyricsStatus == 200
            ? ResponseBody.fromString(
                jsonEncode(<String, String>{
                  'synced_lyrics': syncedLyrics,
                  'plain_lyrics': '',
                }),
                200,
                headers: json,
              )
            : ResponseBody.fromString('{"error":"sin_lyrics"}', 404,
                headers: json);
      case 'stems':
        return stemsStatus == 200
            ? ResponseBody.fromBytes(_stem, 200, headers: <String, List<String>>{
                'content-length': <String>['${_stem.length}'],
              })
            : ResponseBody.fromString('{"error":"sin_stems"}', 404,
                headers: json);
      default:
        return ResponseBody.fromString('{}', 404, headers: json);
    }
  }

  static String _key(String path) {
    if (path.endsWith('/audio')) return 'audio';
    if (path.endsWith('/lyrics')) return 'lyrics';
    if (path.endsWith('/stems')) return 'stems';
    if (path.contains('/asset/cover/')) return 'cover';
    if (path.contains('/asset/artist/')) return 'artist';
    return 'otro';
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
      Uint8List.fromList(List<int>.generate(4000, (int i) => (i * 7) % 256));

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('nb_full_dl');
    store = OfflineStore(dir);
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
        id: const Value(1),
        titulo: 'X',
        artistaNombre: 'A',
        albumId: const Value(10),
        artistaId: const Value(5),
        coverPath: const Value('/api/v1/asset/cover/10'),
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

  DownloadRepository repoWith(_FullAdapter adapter) => DownloadRepository(
        db: db,
        store: store,
        dioFor: (PairedPc pc) {
          final Dio d = Dio(BaseOptions(baseUrl: pc.baseUrl));
          d.httpClientAdapter = adapter;
          return d;
        },
      );

  test('descarga TODO: audio, portada, foto de artista, letra y karaoke',
      () async {
    final DownloadRepository repo = repoWith(_FullAdapter(audio: audio));
    final Pista pista = (await db.catalogDao.getPista(1))!;

    await repo.descargarPista(_pc, pista);

    final DescargaAudio? d = await db.downloadsDao.getEstado(1);
    expect(d?.estado, DownloadEstado.done);
    expect(d?.lyricsEstado, DownloadEstado.done);
    expect(d?.stemsEstado, DownloadEstado.done);

    expect((await db.assetsDao.getEstado(AssetTipo.cover, 10))?.estado,
        DownloadEstado.done);
    expect((await db.assetsDao.getEstado(AssetTipo.artist, 5))?.estado,
        DownloadEstado.done);

    expect(await store.audioFile(1).exists(), isTrue);
    expect(await store.coverFile(10).exists(), isTrue);
    expect(await store.artistFile(5).exists(), isTrue);
    expect(await store.stemFile(1).exists(), isTrue);
    expect(await store.lyricsFile(1).exists(), isTrue);

    final Lyrics ly =
        Lyrics.fromJson(jsonDecode(await store.lyricsFile(1).readAsString())
            as Map<String, dynamic>);
    expect(ly.hasSynced, isTrue);
  });

  test('recursos inexistentes (404) ⇒ unavailable, sin romper el audio',
      () async {
    final DownloadRepository repo = repoWith(_FullAdapter(
      audio: audio,
      coverStatus: 404,
      artistStatus: 404,
      lyricsStatus: 404,
      stemsStatus: 404,
    ));
    final Pista pista = (await db.catalogDao.getPista(1))!;

    await repo.descargarPista(_pc, pista);

    final DescargaAudio? d = await db.downloadsDao.getEstado(1);
    expect(d?.estado, DownloadEstado.done); // el audio sí está
    expect(d?.lyricsEstado, DownloadEstado.unavailable);
    expect(d?.stemsEstado, DownloadEstado.unavailable);
    expect((await db.assetsDao.getEstado(AssetTipo.cover, 10))?.estado,
        DownloadEstado.unavailable);
    expect((await db.assetsDao.getEstado(AssetTipo.artist, 5))?.estado,
        DownloadEstado.unavailable);

    expect(await store.coverFile(10).exists(), isFalse);
    expect(await store.stemFile(1).exists(), isFalse);
    expect(await store.lyricsFile(1).exists(), isFalse);
  });

  test('incremental: una segunda pasada no vuelve a pedir lo ya resuelto',
      () async {
    final _FullAdapter adapter = _FullAdapter(audio: audio);
    final DownloadRepository repo = repoWith(adapter);
    final Pista pista = (await db.catalogDao.getPista(1))!;

    await repo.descargarPista(_pc, pista);
    expect(adapter.calls['audio'], 1);

    adapter.resetCalls();
    await repo.descargarPista(_pc, pista);

    // Todo está done/unavailable ⇒ ninguna petición de red en la segunda pasada.
    expect(adapter.calls, isEmpty);
  });

  test('reintenta lo fallido pero respeta lo inexistente (unavailable)',
      () async {
    // 1ª pasada: la portada falla por red (no 404). El repo la marca failed.
    final _FullAdapter adapter = _FullAdapter(
      audio: audio,
      lyricsStatus: 404, // inexistente: no se reintenta
    );
    final DownloadRepository repo = repoWith(adapter);
    final Pista pista = (await db.catalogDao.getPista(1))!;

    // Marca artificialmente la portada como failed y la letra como unavailable
    // tras una primera descarga normal.
    await repo.descargarPista(_pc, pista);
    await db.assetsDao.setEstado(AssetTipo.cover, 10, DownloadEstado.failed);

    adapter.resetCalls();
    await repo.descargarPista(_pc, pista);

    // La portada (failed) se reintenta; la letra (unavailable, 404) no.
    expect(adapter.calls['cover'], 1);
    expect(adapter.calls.containsKey('lyrics'), isFalse);
    expect((await db.assetsDao.getEstado(AssetTipo.cover, 10))?.estado,
        DownloadEstado.done);
  });
}
