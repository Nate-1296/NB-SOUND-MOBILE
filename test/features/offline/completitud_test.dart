import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/offline/application/download_providers.dart';

DescargaAudio _d({
  String estado = 'done',
  String lyrics = 'done',
  String stems = 'done',
}) =>
    DescargaAudio(
      pistaId: 1,
      estado: estado,
      bytes: 0,
      lyricsEstado: lyrics,
      stemsEstado: stems,
      stemsBytes: 0,
      actualizadoEn: DateTime.utc(2026),
    );

void main() {
  group('recursoResuelto', () {
    test('done y unavailable cuentan como resueltos', () {
      expect(recursoResuelto('done'), isTrue);
      expect(recursoResuelto('unavailable'), isTrue);
    });
    test('pending/downloading/failed/none NO están resueltos', () {
      expect(recursoResuelto('pending'), isFalse);
      expect(recursoResuelto('downloading'), isFalse);
      expect(recursoResuelto('failed'), isFalse);
      expect(recursoResuelto('none'), isFalse);
    });
  });

  group('pistaCompletaCore', () {
    test('sin fila de descarga ⇒ incompleta', () {
      expect(
        pistaCompletaCore(
            descarga: null, coverResuelta: true, artistaResuelta: true),
        isFalse,
      );
    });

    test('todos los recursos done ⇒ completa', () {
      expect(
        pistaCompletaCore(
            descarga: _d(), coverResuelta: true, artistaResuelta: true),
        isTrue,
      );
    });

    test('audio unavailable (el PC no tiene el archivo) cuenta como completa',
        () {
      expect(
        pistaCompletaCore(
          descarga: _d(estado: 'unavailable'),
          coverResuelta: true,
          artistaResuelta: true,
        ),
        isTrue,
      );
    });

    test('letra failed ⇒ incompleta (se reintentará)', () {
      expect(
        pistaCompletaCore(
          descarga: _d(lyrics: 'failed'),
          coverResuelta: true,
          artistaResuelta: true,
        ),
        isFalse,
      );
    });

    test('karaoke pending ⇒ incompleta', () {
      expect(
        pistaCompletaCore(
          descarga: _d(stems: 'pending'),
          coverResuelta: true,
          artistaResuelta: true,
        ),
        isFalse,
      );
    });

    test('portada/foto sin resolver ⇒ incompleta', () {
      expect(
        pistaCompletaCore(
            descarga: _d(), coverResuelta: false, artistaResuelta: true),
        isFalse,
      );
      expect(
        pistaCompletaCore(
            descarga: _d(), coverResuelta: true, artistaResuelta: false),
        isFalse,
      );
    });
  });
}
