import 'package:flutter/services.dart';

/// Una canción del dispositivo tal como la devuelve MediaStore (vía el canal
/// nativo). Campos opcionales si MediaStore no los aporta.
class LocalSong {
  const LocalSong({
    required this.id,
    required this.uri,
    required this.title,
    required this.durationMs,
    this.artist,
    this.artistId,
    this.album,
    this.albumId,
    this.track,
    this.year,
    this.mime,
    this.dateAddedSec,
  });

  /// `_ID` de MediaStore (positivo, estable).
  final int id;

  /// `content://…` reproducible por just_audio.
  final String uri;
  final String title;
  final int durationMs;
  final String? artist;
  final int? artistId;
  final String? album;
  final int? albumId;
  final int? track;
  final int? year;
  final String? mime;
  final int? dateAddedSec;

  static LocalSong fromMap(Map<Object?, Object?> m) => LocalSong(
        id: (m['id'] as num).toInt(),
        uri: m['uri'] as String,
        title: (m['title'] as String?)?.trim().isNotEmpty == true
            ? m['title'] as String
            : 'Desconocido',
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        artist: m['artist'] as String?,
        artistId: (m['artistId'] as num?)?.toInt(),
        album: m['album'] as String?,
        albumId: (m['albumId'] as num?)?.toInt(),
        track: (m['track'] as num?)?.toInt(),
        year: (m['year'] as num?)?.toInt(),
        mime: m['mime'] as String?,
        dateAddedSec: (m['dateAddedSec'] as num?)?.toInt(),
      );
}

/// Puente al `MethodChannel` nativo `com.nbsound/local_media` (MediaStore).
/// Inyectable para tests (los métodos se sobreescriben con un fake).
class LocalMediaChannel {
  const LocalMediaChannel();

  static const MethodChannel _channel = MethodChannel('com.nbsound/local_media');

  /// Lista la música del dispositivo (audio con `IS_MUSIC` y duración mínima).
  /// [minDurationMs] descarta notas de voz/sonidos cortos de apps (30 s por def.).
  Future<List<LocalSong>> scan({int minDurationMs = 30000}) async {
    final List<Object?>? raw = await _channel.invokeListMethod<Object?>(
      'scan',
      <String, Object?>{'minDurationMs': minDurationMs},
    );
    if (raw == null) {
      return const <LocalSong>[];
    }
    return <LocalSong>[
      for (final Object? e in raw)
        if (e is Map<Object?, Object?>) LocalSong.fromMap(e),
    ];
  }

  /// Carátula (PNG) de una pista local por su id de MediaStore, o null si no hay.
  Future<Uint8List?> artwork(int mediaStoreId, {int size = 256}) {
    return _channel.invokeMethod<Uint8List?>(
      'artwork',
      <String, Object?>{'id': mediaStoreId, 'size': size},
    );
  }
}
