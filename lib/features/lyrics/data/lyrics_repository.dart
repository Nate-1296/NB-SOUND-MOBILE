import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;

import '../../../core/security/secure_store.dart';
import 'lyrics_models.dart';

/// Cliente de letra (docs/pc-contract.md §4.7): `GET /track/{id}/lyrics`.
/// **Cache-first**: si la letra ya está en disco no toca la red; si no, la pide
/// al PC y la guarda (`lyrics/{id}.json`) para uso offline posterior.
class LyricsRepository {
  LyricsRepository({required this.dioFor, required this.lyricsDir});

  final Dio Function(PairedPc pc) dioFor;
  final Directory lyricsDir;

  File _fileFor(int pistaId) => File(p.join(lyricsDir.path, '$pistaId.json'));

  /// Devuelve la letra de [pistaId]:
  /// - cacheada → desde disco (sin red);
  /// - no cacheada + [pc] != null → la pide y la cachea (404 ⇒ [Lyrics] vacía);
  /// - no cacheada + sin PC → null (desconocida hasta conectar).
  Future<Lyrics?> load(PairedPc? pc, int pistaId) async {
    final File cache = _fileFor(pistaId);
    if (await cache.exists()) {
      try {
        final Object? json = jsonDecode(await cache.readAsString());
        if (json is Map<String, dynamic>) {
          return Lyrics.fromJson(json);
        }
      } catch (_) {
        // Cache corrupta: se reintenta por red más abajo.
      }
    }
    if (pc == null) {
      return null;
    }
    try {
      final Response<dynamic> res =
          await dioFor(pc).get<dynamic>('/api/v1/track/$pistaId/lyrics');
      final Map<String, dynamic> data = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final Lyrics lyrics = Lyrics.fromJson(data);
      if (!lyrics.isEmpty) {
        await lyricsDir.create(recursive: true);
        await cache.writeAsString(jsonEncode(lyrics.toCacheJson()));
      }
      return lyrics;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const Lyrics(); // sin_lyrics
      }
      rethrow;
    }
  }
}
