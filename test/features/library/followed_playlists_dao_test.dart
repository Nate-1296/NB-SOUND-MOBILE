import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/data/db/database.dart';

/// Estado "guardada/seguida" de las playlists del PC (vive aparte del catálogo).
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('guardar / estaGuardada / dejarDeSeguir', () async {
    expect(await db.followedPlaylistsDao.estaGuardada(2), isFalse);

    await db.followedPlaylistsDao.guardar(2);
    expect(await db.followedPlaylistsDao.estaGuardada(2), isTrue);
    expect(await db.followedPlaylistsDao.watchGuardadasIds().first, <int>{2});

    // Idempotente: guardar dos veces no duplica.
    await db.followedPlaylistsDao.guardar(2);
    expect(await db.followedPlaylistsDao.watchGuardadasIds().first, <int>{2});

    await db.followedPlaylistsDao.dejarDeSeguir(2);
    expect(await db.followedPlaylistsDao.estaGuardada(2), isFalse);
  });

  test('un tombstone de playlist (deletePlaylist) limpia la guardada', () async {
    await db.catalogDao.upsertPlaylists(<PlaylistsCompanion>[
      PlaylistsCompanion.insert(id: const Value(7), nombre: 'Mix'),
    ]);
    await db.followedPlaylistsDao.guardar(7);
    expect(await db.followedPlaylistsDao.estaGuardada(7), isTrue);

    await db.catalogDao.deletePlaylist(7);
    expect(await db.followedPlaylistsDao.estaGuardada(7), isFalse,
        reason: 'no deben quedar guardadas huérfanas');
  });
}
