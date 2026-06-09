import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/daos/assets_dao.dart';
import 'package:nb_sound_mobile/data/db/daos/downloads_dao.dart';
import 'package:nb_sound_mobile/data/db/database.dart';

/// Cubre los agregados reactivos que alimentan los contadores reales de la
/// pantalla de Descargas (N de M + desglose por categoría).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> descarga(int id, String estado,
      {String lyrics = 'none', String stems = 'none'}) {
    return db.downloadsDao.upsert(
      DescargasAudioCompanion.insert(
        pistaId: Value(id),
        estado: Value(estado),
        lyricsEstado: Value(lyrics),
        stemsEstado: Value(stems),
        actualizadoEn: DateTime.now().toUtc(),
      ),
    );
  }

  test('watchResumen cuenta por estado y recurso', () async {
    await descarga(1, 'done', lyrics: 'done', stems: 'done');
    await descarga(2, 'done', lyrics: 'failed', stems: 'unavailable');
    await descarga(3, 'failed');
    await descarga(4, 'pending');
    await descarga(5, 'downloading');

    final ResumenDescargas r = await db.downloadsDao.watchResumen().first;
    expect(r.audioDone, 2);
    expect(r.audioFailed, 1);
    expect(r.audioPendientes, 2); // pending + downloading
    expect(r.lyricsDone, 1);
    expect(r.lyricsFailed, 1);
    expect(r.stemsDone, 1);
    expect(r.stemsFailed, 0);
    expect(r.totalFallidas, 2); // audio:3 + letra:2 (failed)
  });

  test('assets: watchConteo y watchResueltos (done|unavailable)', () async {
    await db.assetsDao.setEstado(AssetTipo.cover, 10, 'done');
    await db.assetsDao.setEstado(AssetTipo.cover, 11, 'unavailable');
    await db.assetsDao.setEstado(AssetTipo.cover, 12, 'failed');
    await db.assetsDao.setEstado(AssetTipo.artist, 5, 'done');

    final ConteoAsset covers =
        await db.assetsDao.watchConteo(AssetTipo.cover).first;
    expect(covers.done, 1);
    expect(covers.failed, 1);

    final Set<int> resueltas =
        await db.assetsDao.watchResueltos(AssetTipo.cover).first;
    expect(resueltas, <int>{10, 11}); // done + unavailable, no el failed

    final ConteoAsset artistas =
        await db.assetsDao.watchConteo(AssetTipo.artist).first;
    expect(artistas.done, 1);
  });

  test('watchTotalPistas refleja el catálogo', () async {
    expect(await db.catalogDao.watchTotalPistas().first, 0);
    await db.catalogDao.upsertPistas(<PistasCompanion>[
      PistasCompanion.insert(id: const Value(1), titulo: 'A', artistaNombre: 'x'),
      PistasCompanion.insert(id: const Value(2), titulo: 'B', artistaNombre: 'y'),
    ]);
    expect(await db.catalogDao.watchTotalPistas().first, 2);
  });
}
