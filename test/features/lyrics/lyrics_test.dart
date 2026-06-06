import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/lyrics/data/lyrics_models.dart';

void main() {
  group('parseLrc', () {
    test('parsea marcas [mm:ss.xx] y conserva el texto', () {
      final List<LyricsLine> lines = parseLrc('[00:08.72] Hola mundo');
      expect(lines.length, 1);
      expect(lines.first.time, const Duration(seconds: 8, milliseconds: 720));
      expect(lines.first.text, 'Hola mundo');
    });

    test('soporta múltiples marcas por línea y ordena por tiempo', () {
      final List<LyricsLine> lines =
          parseLrc('[00:05.00] coro\n[00:01.00][00:09.00] verso');
      expect(lines.map((LyricsLine l) => l.time.inSeconds).toList(),
          <int>[1, 5, 9]);
      expect(lines.first.text, 'verso');
    });

    test('ignora etiquetas de metadatos y líneas sin marca', () {
      final List<LyricsLine> lines =
          parseLrc('[ar:Artista]\n[ti:Título]\nsin marca\n[00:02.00] real');
      expect(lines.length, 1);
      expect(lines.first.text, 'real');
    });

    test('interpreta fracción de 1/2/3 dígitos correctamente', () {
      expect(parseLrc('[00:01.5] a').first.time,
          const Duration(seconds: 1, milliseconds: 500));
      expect(parseLrc('[00:01.50] a').first.time,
          const Duration(seconds: 1, milliseconds: 500));
      expect(parseLrc('[00:01.500] a').first.time,
          const Duration(seconds: 1, milliseconds: 500));
    });

    test('cadena vacía ⇒ sin líneas', () {
      expect(parseLrc(''), isEmpty);
      expect(parseLrc('   \n  '), isEmpty);
    });
  });

  group('Lyrics', () {
    final Lyrics ly = Lyrics.fromContract(
      syncedLyrics: '[00:01.00] uno\n[00:03.00] dos\n[00:05.00] tres',
      plainLyrics: 'uno dos tres',
    );

    test('activeIndex devuelve la última línea con time ≤ posición', () {
      expect(ly.activeIndex(Duration.zero), -1);
      expect(ly.activeIndex(const Duration(seconds: 1)), 0);
      expect(ly.activeIndex(const Duration(seconds: 4)), 1);
      expect(ly.activeIndex(const Duration(seconds: 10)), 2);
    });

    test('round-trip de cache (toCacheJson → fromJson) preserva las líneas', () {
      final Lyrics back = Lyrics.fromJson(ly.toCacheJson());
      expect(back.synced.length, 3);
      expect(back.synced[1].time, const Duration(seconds: 3));
      expect(back.synced[1].text, 'dos');
      expect(back.plain, 'uno dos tres');
    });

    test('sin contenido ⇒ isEmpty', () {
      expect(const Lyrics().isEmpty, isTrue);
      expect(Lyrics.fromContract(syncedLyrics: '', plainLyrics: '').isEmpty,
          isTrue);
    });
  });
}
