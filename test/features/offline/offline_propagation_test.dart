import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/core/security/secure_store.dart';
import 'package:nb_sound_mobile/data/db/daos/assets_dao.dart';
import 'package:nb_sound_mobile/data/db/database.dart';
import 'package:nb_sound_mobile/features/offline/application/offline_propagation.dart';
import 'package:nb_sound_mobile/features/offline/data/download_repository.dart';
import 'package:nb_sound_mobile/features/offline/data/offline_store.dart';
import 'package:nb_sound_mobile/features/sync/data/sync_repository.dart';

SyncResult _result({
  List<int> pistasDelta = const <int>[],
  List<int> albumsDelta = const <int>[],
  List<int> artistasDelta = const <int>[],
  List<int> pistasBorradas = const <int>[],
  List<int> albumsBorrados = const <int>[],
  List<int> artistasBorrados = const <int>[],
}) =>
    SyncResult(
      syncVersion: 1,
      pistas: 0,
      albums: 0,
      artistas: 0,
      playlists: 0,
      tombstones: 0,
      historialSubido: 0,
      favoritosSubidos: 0,
      pistasDelta: pistasDelta,
      albumsDelta: albumsDelta,
      artistasDelta: artistasDelta,
      pistasBorradas: pistasBorradas,
      albumsBorrados: albumsBorrados,
      artistasBorrados: artistasBorrados,
    );

Future<void> _crear(File f) async {
  await f.parent.create(recursive: true);
  await f.writeAsString('x', flush: true);
}

void main() {
  group('reseteable (pura)', () {
    test('done y unavailable se resetean; el resto no', () {
      expect(reseteable(DownloadEstado.done), isTrue);
      expect(reseteable(DownloadEstado.unavailable), isTrue);
      expect(reseteable(DownloadEstado.none), isFalse);
      expect(reseteable(DownloadEstado.pending), isFalse);
      expect(reseteable(DownloadEstado.downloading), isFalse);
      expect(reseteable(DownloadEstado.failed), isFalse);
    });
  });

  group('OfflinePropagation', () {
    late AppDatabase db;
    late Directory dir;
    late OfflineStore store;
    late OfflinePropagation prop;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      dir = await Directory.systemTemp.createTemp('nb_prop_test');
      store = OfflineStore(dir);
      final DownloadRepository repo = DownloadRepository(
        db: db,
        store: store,
        dioFor: (PairedPc pc) => Dio(), // remove() no usa red
      );
      prop = OfflinePropagation(db: db, store: store, downloads: repo);
    });
    tearDown(() async {
      await db.close();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    test('tombstone de pista borra su media offline y la fila de descarga',
        () async {
      await _crear(store.audioFile(1));
      await _crear(store.lyricsFile(1));
      await _crear(store.stemFile(1));
      await db.downloadsDao.upsert(DescargasAudioCompanion.insert(
        pistaId: const Value(1),
        estado: const Value(DownloadEstado.done),
        actualizadoEn: DateTime.now().toUtc(),
      ));

      await prop.aplicar(_result(pistasBorradas: <int>[1]));

      expect(await store.audioFile(1).exists(), isFalse);
      expect(await store.lyricsFile(1).exists(), isFalse);
      expect(await store.stemFile(1).exists(), isFalse);
      expect(await db.downloadsDao.getEstado(1), isNull);
    });

    test('tombstone de álbum/artista borra portada/foto y su fila de asset',
        () async {
      await _crear(store.coverFile(10));
      await _crear(store.artistFile(5));
      await db.assetsDao.setEstado(AssetTipo.cover, 10, DownloadEstado.done);
      await db.assetsDao.setEstado(AssetTipo.artist, 5, DownloadEstado.done);

      await prop.aplicar(_result(
        albumsBorrados: <int>[10],
        artistasBorrados: <int>[5],
      ));

      expect(await store.coverFile(10).exists(), isFalse);
      expect(await store.artistFile(5).exists(), isFalse);
      expect(await db.assetsDao.getEstado(AssetTipo.cover, 10), isNull);
      expect(await db.assetsDao.getEstado(AssetTipo.artist, 5), isNull);
    });

    test(
        'delta de pista resetea letra/karaoke resueltos a none, conserva el audio '
        'y la marca para re-encolar', () async {
      await db.downloadsDao.upsert(DescargasAudioCompanion.insert(
        pistaId: const Value(1),
        estado: const Value(DownloadEstado.done), // audio: NO se toca
        lyricsEstado: const Value(DownloadEstado.done),
        stemsEstado: const Value(DownloadEstado.unavailable),
        actualizadoEn: DateTime.now().toUtc(),
      ));

      final Set<int> reencolar = await prop.aplicar(_result(pistasDelta: <int>[1]));

      final DescargaAudio? row = await db.downloadsDao.getEstado(1);
      expect(row!.estado, DownloadEstado.done); // audio intacto
      expect(row.lyricsEstado, DownloadEstado.none); // reseteado
      expect(row.stemsEstado, DownloadEstado.none); // reseteado (404 → reprobar)
      expect(reencolar, contains(1));
    });

    test('delta de pista SIN descarga previa no crea fila ni la re-encola',
        () async {
      final Set<int> reencolar = await prop.aplicar(_result(pistasDelta: <int>[1]));
      expect(await db.downloadsDao.getEstado(1), isNull);
      expect(reencolar, isEmpty);
    });

    test('delta de álbum/artista resetea la portada/foto descargada a none',
        () async {
      await db.assetsDao.setEstado(AssetTipo.cover, 10, DownloadEstado.done);
      await db.assetsDao
          .setEstado(AssetTipo.artist, 5, DownloadEstado.unavailable);

      await prop
          .aplicar(_result(albumsDelta: <int>[10], artistasDelta: <int>[5]));

      expect((await db.assetsDao.getEstado(AssetTipo.cover, 10))!.estado,
          DownloadEstado.none);
      expect((await db.assetsDao.getEstado(AssetTipo.artist, 5))!.estado,
          DownloadEstado.none);
    });

    test('un recurso failed NO se resetea (ya lo reintenta la cola)', () async {
      await db.downloadsDao.upsert(DescargasAudioCompanion.insert(
        pistaId: const Value(1),
        estado: const Value(DownloadEstado.done),
        lyricsEstado: const Value(DownloadEstado.failed),
        actualizadoEn: DateTime.now().toUtc(),
      ));

      await prop.aplicar(_result(pistasDelta: <int>[1]));

      expect((await db.downloadsDao.getEstado(1))!.lyricsEstado,
          DownloadEstado.failed);
    });
  });
}
