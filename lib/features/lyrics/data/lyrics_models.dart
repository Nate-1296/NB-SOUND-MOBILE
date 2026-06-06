import 'package:flutter/foundation.dart';

/// Una línea de letra sincronizada: marca de tiempo + texto.
@immutable
class LyricsLine {
  const LyricsLine(this.time, this.text);
  final Duration time;
  final String text;
}

/// Letra de una pista (docs/pc-contract.md §4.7): líneas sincronizadas (LRC) y/o
/// texto plano. `synced` vacío ⇒ no hay marcas de tiempo (usar [plain]).
@immutable
class Lyrics {
  const Lyrics({this.synced = const <LyricsLine>[], this.plain = ''});

  /// Construye desde la respuesta del PC, parseando el LRC sincronizado.
  factory Lyrics.fromContract({String? syncedLyrics, String? plainLyrics}) {
    return Lyrics(
      synced: parseLrc(syncedLyrics ?? ''),
      plain: (plainLyrics ?? '').trim(),
    );
  }

  factory Lyrics.fromJson(Map<String, dynamic> json) => Lyrics.fromContract(
        syncedLyrics: json['synced_lyrics'] as String?,
        plainLyrics: json['plain_lyrics'] as String?,
      );

  final List<LyricsLine> synced;
  final String plain;

  bool get hasSynced => synced.isNotEmpty;
  bool get isEmpty => synced.isEmpty && plain.isEmpty;

  /// JSON estable para cachear en disco (re-parseable por [fromJson]).
  Map<String, dynamic> toCacheJson() => <String, dynamic>{
        'synced_lyrics': <String>[
          for (final LyricsLine l in synced)
            '[${_fmt(l.time)}]${l.text}',
        ].join('\n'),
        'plain_lyrics': plain,
      };

  /// Índice de la línea activa para [position] (la última con time ≤ position),
  /// o -1 si aún no empieza ninguna. Requiere [synced] ordenado.
  int activeIndex(Duration position) {
    int idx = -1;
    for (int i = 0; i < synced.length; i++) {
      if (synced[i].time <= position) {
        idx = i;
      } else {
        break;
      }
    }
    return idx;
  }

  static String _fmt(Duration d) {
    final int cs = (d.inMilliseconds % 1000) ~/ 10;
    final String mm = d.inMinutes.toString().padLeft(2, '0');
    final String ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$mm:$ss.${cs.toString().padLeft(2, '0')}';
  }
}

final RegExp _lrcTag = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

/// Parsea LRC a líneas ordenadas por tiempo. Soporta múltiples marcas por línea
/// (`[t1][t2] texto`) e ignora etiquetas de metadatos (`[ar:...]`, `[ti:...]`).
List<LyricsLine> parseLrc(String lrc) {
  if (lrc.trim().isEmpty) {
    return const <LyricsLine>[];
  }
  final List<LyricsLine> out = <LyricsLine>[];
  for (final String raw in lrc.split('\n')) {
    final Iterable<RegExpMatch> tags = _lrcTag.allMatches(raw);
    if (tags.isEmpty) {
      continue;
    }
    final String text = raw.replaceAll(_lrcTag, '').trim();
    for (final RegExpMatch m in tags) {
      final int min = int.parse(m.group(1)!);
      final int sec = int.parse(m.group(2)!);
      final String? frac = m.group(3);
      int ms = 0;
      if (frac != null) {
        // 2 dígitos = centésimas, 3 = milésimas.
        ms = frac.length >= 3
            ? int.parse(frac.substring(0, 3))
            : int.parse(frac) * (frac.length == 1 ? 100 : 10);
      }
      out.add(LyricsLine(
        Duration(minutes: min, seconds: sec, milliseconds: ms),
        text,
      ));
    }
  }
  out.sort((LyricsLine a, LyricsLine b) => a.time.compareTo(b.time));
  return out;
}
