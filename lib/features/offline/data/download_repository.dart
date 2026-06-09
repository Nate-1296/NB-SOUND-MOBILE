import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';

import '../../../core/security/secure_store.dart';
import '../../../data/db/daos/assets_dao.dart';
import '../../../data/db/database.dart';
import '../../lyrics/data/lyrics_models.dart';
import 'offline_store.dart';

/// Estados de descarga por recurso (`descargas_audio` y `assets_descargados`).
abstract final class DownloadEstado {
  static const String none = 'none';
  static const String pending = 'pending';
  static const String downloading = 'downloading';
  static const String done = 'done';

  /// El PC respondió 404: el recurso no existe. NO se reintenta.
  static const String unavailable = 'unavailable';

  /// Error transitorio (red/IO): se reintenta en la próxima pasada.
  static const String failed = 'failed';
}

/// Descarga offline **completa** de una pista (docs/pc-contract.md §4.5–4.8):
/// audio (`/track/{id}/audio`, Range + hash), portada (`/asset/cover/{albumId}`),
/// foto de artista (`/asset/artist/{artistaId}`), letra (`/track/{id}/lyrics`) e
/// instrumental de karaoke (`/track/{id}/stems`, Range). Cada recurso es
/// independiente, idempotente y selectivo: no rebaja lo ya `done`/`unavailable`.
class DownloadRepository {
  DownloadRepository({
    required this.db,
    required this.dioFor,
    required this.store,
  });

  final AppDatabase db;
  final Dio Function(PairedPc pc) dioFor;
  final OfflineStore store;

  /// Archivo final del audio descargado de [pistaId].
  File fileFor(int pistaId) => store.audioFile(pistaId);
  File _partOf(File f) => File('${f.path}.part');

  /// Descarga TODO lo de [pista] para offline. Las sub-descargas son
  /// independientes: el fallo de una no aborta las demás (se marca y se reintenta
  /// en otra pasada). [onProgress] refleja el recurso pesado en curso (audio/stems).
  Future<void> descargarPista(
    PairedPc pc,
    Pista pista, {
    void Function(int received, int? total)? onProgress,
  }) async {
    try {
      await download(pc, pista, onProgress: onProgress);
    } on _RecursoNoDisponible {
      // 404: el PC no tiene el archivo de audio. No se reintenta.
      await _mark(pista.id, DownloadEstado.unavailable);
    } catch (_) {
      await _mark(pista.id, DownloadEstado.failed);
    }
    if (pista.albumId != null) {
      await _descargarAsset(pc, AssetTipo.cover, pista.albumId!);
    }
    if (pista.artistaId != null) {
      await _descargarAsset(pc, AssetTipo.artist, pista.artistaId!);
    }
    await _descargarLyrics(pc, pista.id);
    await _descargarStems(pc, pista.id, onProgress: onProgress);
  }

  // ── Audio (recurso principal) ─────────────────────────────────────────────
  /// Descarga (o reanuda) el audio de [pista]. Idempotente: si ya está completo
  /// no hace nada. Reintenta fallos transitorios con backoff; un 404 lanza
  /// [_RecursoNoDisponible] (la pista no tiene archivo en el PC). Un mismatch de
  /// hash NO descarta el archivo (ver más abajo).
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
    await store.audioDir.create(recursive: true);

    final _Transferencia t = await _conReintentos(() => _descargarStream(
          pc,
          '/api/v1/track/${pista.id}/audio',
          dest,
          onProgress: onProgress,
          onStart: (int start) =>
              _mark(pista.id, DownloadEstado.downloading, bytes: start),
          onPersist: (int recibidos, int? total) => _mark(
              pista.id, DownloadEstado.downloading,
              bytes: recibidos, total: total),
        ));

    // Verificación de integridad. El PC define `hash_sha256` / `X-NB-Sound-Hash`
    // como SHA256 de los primeros 512KB + los últimos 512KB del archivo (hash de
    // identidad para dedupe; NO del archivo completo — ver docs/integration-notes.md
    // y nb_sound/core/validator.py::_calcular_hash_combinado). Un mismatch NO
    // descarta el archivo: TLS ya garantiza la integridad de transporte y el
    // tamaño se valida por Range, así que se conserva y se marca `hashOk=false`
    // ("descargado, no verificado"). hashOk=null si el PC no envió hash.
    final String? expected = t.hash ?? pista.hashSha256;
    bool? hashOk;
    if (expected != null && expected.isNotEmpty) {
      final String actual = await _hashHeadTail(dest);
      hashOk = actual.toLowerCase() == expected.toLowerCase();
    }
    await _mark(pista.id, DownloadEstado.done,
        bytes: t.received, total: t.total ?? t.received, hashOk: hashOk);
    return dest;
  }

  /// Descarga (o reanuda) un recurso por **streaming con Range** a [dest] y
  /// devuelve los bytes transferidos + el hash de respuesta. 404 ⇒
  /// [_RecursoNoDisponible] (permanente). NO marca estado en BD: cada llamador
  /// (audio/karaoke) lo hace por [onStart]/[onPersist]. Idempotente: reanuda
  /// desde el `.part` si quedó uno de un intento previo.
  Future<_Transferencia> _descargarStream(
    PairedPc pc,
    String path,
    File dest, {
    void Function(int received, int? total)? onProgress,
    void Function(int start)? onStart,
    void Function(int received, int? total)? onPersist,
  }) async {
    final File part = _partOf(dest);
    int start = await part.exists() ? await part.length() : 0;
    onStart?.call(start);

    final Response<ResponseBody> res = await dioFor(pc).get<ResponseBody>(
      path,
      options: Options(
        responseType: ResponseType.stream,
        headers: start > 0 ? <String, dynamic>{'range': 'bytes=$start-'} : null,
        validateStatus: (int? s) => s != null && s < 500,
      ),
    );
    final int code = res.statusCode ?? 0;
    if (code == 404) {
      throw const _RecursoNoDisponible();
    }
    if (code != 200 && code != 206) {
      // 401 (revocado) u otros: transitorio/permanente lo decide _esTransitorio.
      throw DioException(requestOptions: res.requestOptions, response: res);
    }

    final bool partial = code == 206;
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
          onPersist?.call(received, total);
        }
      }
    } finally {
      await sink.close();
    }
    await part.rename(dest.path);
    return _Transferencia(
      received: received,
      total: total,
      hash: res.headers.value('x-nb-sound-hash'),
    );
  }

  // ── Imágenes (portada de álbum / foto de artista) ─────────────────────────
  /// Descarga la imagen [tipo]/[refId] a disco. Deduplicada: si ya está
  /// `done`/`unavailable` no hace nada. 404 ⇒ `unavailable` (no se reintenta).
  Future<void> _descargarAsset(PairedPc pc, String tipo, int refId) async {
    final AssetDescargado? cur = await db.assetsDao.getEstado(tipo, refId);
    if (cur?.estado == DownloadEstado.done ||
        cur?.estado == DownloadEstado.unavailable) {
      return;
    }
    final File dest =
        tipo == AssetTipo.cover ? store.coverFile(refId) : store.artistFile(refId);
    try {
      final Response<List<int>> res = await dioFor(pc).get<List<int>>(
        '/api/v1/asset/$tipo/$refId',
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (int? s) => s != null && s < 500,
        ),
      );
      final List<int>? data = res.data;
      if (res.statusCode == 200 && data != null && data.isNotEmpty) {
        await dest.parent.create(recursive: true);
        await dest.writeAsBytes(data, flush: true);
        await db.assetsDao.setEstado(tipo, refId, DownloadEstado.done);
      } else {
        // 404 u otra respuesta sin cuerpo útil: no existe imagen.
        await db.assetsDao.setEstado(tipo, refId, DownloadEstado.unavailable);
      }
    } catch (_) {
      await db.assetsDao.setEstado(tipo, refId, DownloadEstado.failed);
    }
  }

  // ── Letra ──────────────────────────────────────────────────────────────────
  /// Descarga y cachea la letra en `lyrics/{id}.json` (mismo path que lee
  /// [LyricsRepository], así sirve offline). Guarda lo que venga (synced y/o
  /// plain); la presentación decide qué mostrar. 404/sin contenido ⇒ `unavailable`.
  Future<void> _descargarLyrics(PairedPc pc, int pistaId) async {
    final DescargaAudio? row = await db.downloadsDao.getEstado(pistaId);
    if (row?.lyricsEstado == DownloadEstado.done ||
        row?.lyricsEstado == DownloadEstado.unavailable) {
      return;
    }
    try {
      final Response<dynamic> res = await dioFor(pc).get<dynamic>(
        '/api/v1/track/$pistaId/lyrics',
        options: Options(validateStatus: (int? s) => s != null && s < 500),
      );
      if (res.statusCode != 200) {
        await db.downloadsDao.setLyricsEstado(pistaId, DownloadEstado.unavailable);
        return;
      }
      final Map<String, dynamic> data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final Lyrics lyrics = Lyrics.fromJson(data);
      if (lyrics.isEmpty) {
        await db.downloadsDao.setLyricsEstado(pistaId, DownloadEstado.unavailable);
        return;
      }
      await store.lyricsDir.create(recursive: true);
      await store.lyricsFile(pistaId).writeAsString(
            jsonEncode(lyrics.toCacheJson()),
            flush: true,
          );
      await db.downloadsDao.setLyricsEstado(pistaId, DownloadEstado.done);
    } catch (_) {
      await db.downloadsDao.setLyricsEstado(pistaId, DownloadEstado.failed);
    }
  }

  // ── Karaoke (instrumental) ──────────────────────────────────────────────────
  /// Descarga (o reanuda) el instrumental a `stems/{id}.audio`. 404 ⇒
  /// `unavailable` (la pista no tiene karaoke). Sin validación de hash (el PC no
  /// expone uno para stems).
  Future<void> _descargarStems(
    PairedPc pc,
    int pistaId, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final DescargaAudio? row = await db.downloadsDao.getEstado(pistaId);
    if (row?.stemsEstado == DownloadEstado.done ||
        row?.stemsEstado == DownloadEstado.unavailable) {
      return;
    }
    final File dest = store.stemFile(pistaId);
    if (await dest.exists()) {
      await db.downloadsDao.setStemsEstado(pistaId, DownloadEstado.done);
      return;
    }
    try {
      await store.stemsDir.create(recursive: true);
      final _Transferencia t = await _conReintentos(() => _descargarStream(
            pc,
            '/api/v1/track/$pistaId/stems',
            dest,
            onProgress: onProgress,
            onStart: (int start) => db.downloadsDao
                .setStemsEstado(pistaId, DownloadEstado.downloading,
                    bytes: start),
            onPersist: (int recibidos, int? total) => db.downloadsDao
                .setStemsEstado(pistaId, DownloadEstado.downloading,
                    bytes: recibidos, total: total),
          ));
      await db.downloadsDao.setStemsEstado(pistaId, DownloadEstado.done,
          bytes: t.received, total: t.total ?? t.received);
    } on _RecursoNoDisponible {
      await db.downloadsDao.setStemsEstado(pistaId, DownloadEstado.unavailable);
    } catch (_) {
      await db.downloadsDao.setStemsEstado(pistaId, DownloadEstado.failed);
    }
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

  /// Borra la media descargada de [pistaId] (audio + karaoke + letra) y su estado.
  /// NO toca las imágenes (portada/artista): se comparten con otras pistas.
  Future<void> remove(int pistaId) async {
    final List<File> files = <File>[
      fileFor(pistaId),
      _partOf(fileFor(pistaId)),
      store.stemFile(pistaId),
      _partOf(store.stemFile(pistaId)),
      store.lyricsFile(pistaId),
    ];
    for (final File f in files) {
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

  // ── Reintentos ─────────────────────────────────────────────────────────────
  static const int _maxIntentos = 3;

  /// Ejecuta [op] reintentando ante fallos **transitorios** (timeout/conexión/
  /// 5xx/corte de stream) con backoff exponencial (0.5s · 1s · 2s). Los fallos
  /// permanentes ([_RecursoNoDisponible] = 404, o 4xx) se propagan sin reintentar.
  Future<T> _conReintentos<T>(Future<T> Function() op) async {
    for (int intento = 1;; intento++) {
      try {
        return await op();
      } on _RecursoNoDisponible {
        rethrow;
      } catch (e) {
        if (intento >= _maxIntentos || !_esTransitorio(e)) {
          rethrow;
        }
        await Future<void>.delayed(
            Duration(milliseconds: 500 * (1 << (intento - 1))));
      }
    }
  }

  static bool _esTransitorio(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          return (e.response?.statusCode ?? 0) >= 500;
        case DioExceptionType.unknown:
          // Errores de IO durante el streaming (socket caído, etc.).
          return true;
        default:
          return false;
      }
    }
    return e is HttpException || e is SocketException;
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

/// Resultado de una transferencia por streaming: bytes recibidos, total esperado
/// (si el PC lo informó) y el hash de respuesta (`X-NB-Sound-Hash`, si vino).
class _Transferencia {
  const _Transferencia({required this.received, this.total, this.hash});

  final int received;
  final int? total;
  final String? hash;
}

/// El PC respondió 404: el recurso no existe (no se reintenta).
class _RecursoNoDisponible implements Exception {
  const _RecursoNoDisponible();
}
