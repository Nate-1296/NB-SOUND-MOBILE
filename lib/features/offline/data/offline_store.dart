import 'dart:io';

import 'package:path/path.dart' as p;

/// Convención única de rutas de la media offline. Todo lo descargado vive bajo un
/// directorio base (`<documentos>`), con una subcarpeta por tipo de recurso:
/// `audio/`, `covers/`, `artists/`, `stems/`, `lyrics/`. Centralizar aquí evita
/// que el repositorio de descargas, el resolver de imágenes, el reproductor y la
/// caché de letra discrepen sobre dónde está cada archivo.
class OfflineStore {
  const OfflineStore(this.baseDir);

  /// Directorio raíz (normalmente `getApplicationDocumentsDirectory()`).
  final Directory baseDir;

  Directory get audioDir => _sub('audio');
  Directory get coversDir => _sub('covers');
  Directory get artistsDir => _sub('artists');
  Directory get stemsDir => _sub('stems');
  Directory get lyricsDir => _sub('lyrics');

  /// Audio de la pista (`audio/{id}.audio`).
  File audioFile(int pistaId) => File(p.join(audioDir.path, '$pistaId.audio'));

  /// Portada del álbum (`covers/{albumId}.img`); la comparten sus pistas.
  File coverFile(int albumId) => File(p.join(coversDir.path, '$albumId.img'));

  /// Foto del artista (`artists/{artistaId}.img`).
  File artistFile(int artistaId) =>
      File(p.join(artistsDir.path, '$artistaId.img'));

  /// Instrumental de karaoke (`stems/{id}.audio`).
  File stemFile(int pistaId) => File(p.join(stemsDir.path, '$pistaId.audio'));

  /// Letra cacheada (`lyrics/{id}.json`).
  File lyricsFile(int pistaId) => File(p.join(lyricsDir.path, '$pistaId.json'));

  Directory _sub(String name) => Directory(p.join(baseDir.path, name));

  /// Espacio en disco usado por cada categoría de media offline. Recorre los
  /// subdirectorios; los `.part` (descargas a medias) cuentan en su categoría.
  Future<EspacioOffline> calcularEspacio() async {
    return EspacioOffline(
      audio: await _tamanoDir(audioDir),
      covers: await _tamanoDir(coversDir),
      artists: await _tamanoDir(artistsDir),
      stems: await _tamanoDir(stemsDir),
      lyrics: await _tamanoDir(lyricsDir),
    );
  }

  static Future<int> _tamanoDir(Directory d) async {
    if (!await d.exists()) {
      return 0;
    }
    int total = 0;
    await for (final FileSystemEntity e
        in d.list(recursive: true, followLinks: false)) {
      if (e is File) {
        try {
          total += await e.length();
        } catch (_) {
          // Archivo borrado entre el listado y el length: se ignora.
        }
      }
    }
    return total;
  }
}

/// Bytes en disco por categoría de media offline (para la pantalla de Descargas).
class EspacioOffline {
  const EspacioOffline({
    this.audio = 0,
    this.covers = 0,
    this.artists = 0,
    this.stems = 0,
    this.lyrics = 0,
  });

  final int audio;
  final int covers;
  final int artists;
  final int stems;
  final int lyrics;

  int get total => audio + covers + artists + stems + lyrics;
}
