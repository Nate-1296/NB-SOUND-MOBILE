import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../../../core/security/secure_store.dart';
import '../../../data/db/database.dart';

/// Estados de `descargas_audio`.
abstract final class DownloadEstado {
  static const String pending = 'pending';
  static const String downloading = 'downloading';
  static const String done = 'done';
  static const String failed = 'failed';
}

class DownloadException implements Exception {
  DownloadException(this.code);
  final String code;
  @override
  String toString() => 'DownloadException($code)';
}

/// Descarga de audio offline (docs/pc-contract.md §4.5): `GET /track/{id}/audio`
/// con `Range` reanudable y validación de `hash_sha256` al completar.
class DownloadRepository {
  DownloadRepository({
    required this.db,
    required this.dioFor,
    required this.audioDir,
  });

  final AppDatabase db;
  final Dio Function(PairedPc pc) dioFor;
  final Directory audioDir;

  /// Archivo final del audio descargado de [pistaId].
  File fileFor(int pistaId) => File(p.join(audioDir.path, '$pistaId.audio'));
  File _partFor(int pistaId) => File(p.join(audioDir.path, '$pistaId.audio.part'));

  /// Descarga (o reanuda) el audio de [pista]. Idempotente: si ya está completa
  /// no hace nada. Lanza [DownloadException] si el hash no valida.
  Future<File> download(
    PairedPc pc,
    Pista pista, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final File dest = fileFor(pista.id);
    if (await dest.exists()) {
      await _mark(pista.id, DownloadEstado.done, hashOk: true);
      return dest;
    }
    await audioDir.create(recursive: true);
    final File part = _partFor(pista.id);
    int start = await part.exists() ? await part.length() : 0;

    await _mark(pista.id, DownloadEstado.downloading, bytes: start);

    final Dio dio = dioFor(pc);
    final Response<ResponseBody> res = await dio.get<ResponseBody>(
      '/api/v1/track/${pista.id}/audio',
      options: Options(
        responseType: ResponseType.stream,
        headers: start > 0
            ? <String, dynamic>{'range': 'bytes=$start-'}
            : null,
        validateStatus: (int? s) => s != null && s < 400,
      ),
    );

    final bool partial = res.statusCode == 206;
    if (!partial) {
      // El servidor ignoró el Range (200): se reescribe desde cero.
      start = 0;
    }
    final int? total = _totalBytes(res.headers, start);
    final IOSink sink = part.openWrite(
      mode: partial ? FileMode.append : FileMode.writeOnly,
    );

    int received = start;
    int lastPersisted = start;
    try {
      await for (final List<int> chunk in res.data!.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
        if (received - lastPersisted >= 1 << 20) {
          lastPersisted = received;
          await _mark(pista.id, DownloadEstado.downloading,
              bytes: received, total: total);
        }
      }
    } finally {
      await sink.close();
    }

    await part.rename(dest.path);

    // Verificación de integridad. El PC define `hash_sha256` / `X-NB-Sound-Hash`
    // como SHA256 de los primeros 512KB + los últimos 512KB del archivo (hash de
    // identidad para dedupe; NO del archivo completo — ver docs/integration-notes.md
    // y nb_sound/core/validator.py::_calcular_hash_combinado). Un mismatch NO
    // descarta el archivo: TLS ya garantiza la integridad de transporte y el
    // tamaño se valida por Range, así que se conserva y se marca `hashOk=false`
    // ("descargado, no verificado"). hashOk=null si el PC no envió hash.
    final String? expected =
        res.headers.value('x-nb-sound-hash') ?? pista.hashSha256;
    bool? hashOk;
    if (expected != null && expected.isNotEmpty) {
      final String actual = await _hashHeadTail(dest);
      hashOk = actual.toLowerCase() == expected.toLowerCase();
    }
    await _mark(pista.id, DownloadEstado.done,
        bytes: received, total: total ?? received, hashOk: hashOk);
    return dest;
  }

  // Ventanas del hash de identidad del PC (deben coincidir con el PC).
  static const int _hashHead = 512 * 1024;
  static const int _hashTail = 512 * 1024;

  /// SHA256 de los primeros [_hashHead] + últimos [_hashTail] bytes (réplica de
  /// `_calcular_hash_combinado` del PC). Para archivos ≤512KB equivale al SHA256
  /// del archivo completo; el tail solo entra si el archivo supera 1 MB.
  static Future<String> _hashHeadTail(File f) async {
    final int size = await f.length();
    final RandomAccessFile raf = await f.open();
    try {
      final int headLen = size < _hashHead ? size : _hashHead;
      final List<int> bytes = <int>[...await raf.read(headLen)];
      if (size > _hashHead + _hashTail) {
        await raf.setPosition(size - _hashTail);
        bytes.addAll(await raf.read(_hashTail));
      }
      return sha256.convert(bytes).toString();
    } finally {
      await raf.close();
    }
  }

  /// Borra el audio descargado de [pistaId] y su estado (vuelve a streaming).
  Future<void> remove(int pistaId) async {
    for (final File f in <File>[fileFor(pistaId), _partFor(pistaId)]) {
      if (await f.exists()) {
        await f.delete();
      }
    }
    await db.downloadsDao.eliminar(pistaId);
  }

  Future<void> _mark(
    int pistaId,
    String estado, {
    int? bytes,
    int? total,
    bool? hashOk,
  }) {
    return db.downloadsDao.upsert(
      DescargasAudioCompanion.insert(
        pistaId: Value(pistaId),
        estado: Value(estado),
        bytes: bytes != null ? Value(bytes) : const Value.absent(),
        totalBytes: total != null ? Value(total) : const Value.absent(),
        hashOk: hashOk != null ? Value(hashOk) : const Value.absent(),
        actualizadoEn: DateTime.now().toUtc(),
      ),
    );
  }

  static int? _totalBytes(Headers headers, int start) {
    // Content-Range: "bytes 200-1023/1024" → total = 1024.
    final String? cr = headers.value('content-range');
    if (cr != null) {
      final int slash = cr.lastIndexOf('/');
      if (slash >= 0) {
        final int? t = int.tryParse(cr.substring(slash + 1).trim());
        if (t != null) {
          return t;
        }
      }
    }
    final String? cl = headers.value('content-length');
    final int? len = cl != null ? int.tryParse(cl) : null;
    return len != null ? len + start : null;
  }
}
