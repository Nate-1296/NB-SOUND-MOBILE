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

/// Sirve [content] como audio, soportando Range (206) y enviando el hash en
/// `X-NB-Sound-Hash`. [hashOverride] permite simular un hash incorrecto.
class _AudioAdapter implements HttpClientAdapter {
  _AudioAdapter(this.content, {String? hashOverride})
      : hash = hashOverride ?? sha256.convert(content).toString();
  final Uint8List content;
  final String hash;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final String? range =
        (options.headers['range'] ?? options.headers['Range']) as String?;
    final Map<String, List<String>> headers = <String, List<String>>{
      Headers.contentTypeHeader: <String>['application/octet-stream'],
      'x-nb-sound-hash': <String>[hash],
    };
    if (range != null) {
      final int start =
          int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
      final Uint8List slice = Uint8List.sublistView(content, start);
      headers['content-range'] = <String>[
        'bytes $start-${content.length - 1}/${content.length}',
      ];
      headers['content-length'] = <String>['${slice.length}'];
      return ResponseBody.fromBytes(slice, 206, headers: headers);
    }
    headers['content-length'] = <String>['${content.length}'];
    return ResponseBody.fromBytes(content, 200, headers: headers);
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
  final Uint8List content =
      Uint8List.fromList(List<int>.generate(5000, (int i) => (i * 7) % 256));
  final String hash = sha256.convert(content).toString();

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = await Directory.systemTemp.createTemp('nb_dl_test');
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
        id: const Value(1),
        titulo: 'X',
        artistaNombre: 'A',
        hashSha256: Value(hash),
      ),
    ]);
  });
  tearDown(() async {
    await db.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  DownloadRepository repoWith(HttpClientAdapter adapter) => DownloadRepository(
        db: db,
        audioDir: dir,
        dioFor: (PairedPc pc) {
          final Dio d = Dio(BaseOptions(baseUrl: pc.baseUrl));
          d.httpClientAdapter = adapter;
          return d;
        },
      );

  test('descarga completa, valida el hash y marca done', () async {
    final DownloadRepository repo = repoWith(_AudioAdapter(content));
    final Pista pista = (await db.catalogDao.getPista(1))!;

    final File f = await repo.download(_pc, pista);

    expect(await f.exists(), isTrue);
    expect(await f.readAsBytes(), content);
    final DescargaAudio? estado = await db.downloadsDao.getEstado(1);
    expect(estado?.estado, DownloadEstado.done);
    expect(estado?.hashOk, isTrue);
    expect(await db.downloadsDao.estaDescargada(1), isTrue);
  });

  test('reanuda por Range desde un archivo parcial', () async {
    // Simula una descarga cortada: .part con la primera mitad.
    final File part = File('${dir.path}/1.audio.part');
    await part.writeAsBytes(content.sublist(0, 2000));

    final DownloadRepository repo = repoWith(_AudioAdapter(content));
    final Pista pista = (await db.catalogDao.getPista(1))!;

    final File f = await repo.download(_pc, pista);

    // El archivo reensamblado es el contenido completo (sin duplicar la parte).
    expect(await f.readAsBytes(), content);
    expect((await db.downloadsDao.getEstado(1))?.estado, DownloadEstado.done);
  });

  test('hash incorrecto: conserva el archivo y marca hashOk=false (no falla)',
      () async {
    // El `hash_sha256` del PC es de identidad (head+tail) y puede quedar stale;
    // un mismatch no debe descartar un archivo bien transferido (ver
    // docs/integration-notes.md). Se conserva como "descargado, no verificado".
    final DownloadRepository repo =
        repoWith(_AudioAdapter(content, hashOverride: 'deadbeef'));
    final Pista pista = (await db.catalogDao.getPista(1))!;

    final File f = await repo.download(_pc, pista);

    expect(await f.exists(), isTrue);
    expect(await f.readAsBytes(), content);
    final DescargaAudio? estado = await db.downloadsDao.getEstado(1);
    expect(estado?.estado, DownloadEstado.done);
    expect(estado?.hashOk, isFalse);
    expect(await db.downloadsDao.estaDescargada(1), isTrue);
  });

  test('archivo >1MB: valida con hash head+tail, no del archivo completo',
      () async {
    final Uint8List big = Uint8List.fromList(
        List<int>.generate(1300000, (int i) => (i * 31 + 7) % 256));
    final String headTail = _headTailHash(big);
    expect(headTail, isNot(sha256.convert(big).toString())); // semántica distinta

    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(
        id: const Value(2),
        titulo: 'Big',
        artistaNombre: 'A',
        hashSha256: Value(headTail),
      ),
    ]);
    final DownloadRepository repo =
        repoWith(_AudioAdapter(big, hashOverride: headTail));
    final Pista pista = (await db.catalogDao.getPista(2))!;

    final File f = await repo.download(_pc, pista);

    expect(await f.readAsBytes(), big);
    final DescargaAudio? estado = await db.downloadsDao.getEstado(2);
    expect(estado?.estado, DownloadEstado.done);
    expect(estado?.hashOk, isTrue);
  });
}

/// Réplica del hash de identidad del PC (primeros 512KB + últimos 512KB).
String _headTailHash(Uint8List data) {
  const int head = 512 * 1024;
  const int tail = 512 * 1024;
  final int size = data.length;
  final int headLen = size < head ? size : head;
  final List<int> bytes = <int>[...data.sublist(0, headLen)];
  if (size > head + tail) {
    bytes.addAll(data.sublist(size - tail));
  }
  return sha256.convert(bytes).toString();
}
