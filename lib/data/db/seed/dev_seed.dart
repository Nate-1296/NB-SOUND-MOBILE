import 'package:drift/drift.dart';

import '../database.dart';

/// Activa el sembrado de datos de desarrollo en el primer arranque. **Apagado en
/// producción**: el catálogo real llega del PC vía sync. Para desarrollo sin PC,
/// poner en `true` (o pasar `--dart-define=NB_SEED=true`). El catálogo de ejemplo
/// (`seedDevData`) se conserva, solo se omite su aplicación automática.
///
/// Nota: la media de ejemplo (audio en `assets/audio`, portadas en
/// `assets/covers`) ya **no se empaqueta** (no está declarada en `pubspec.yaml`).
/// Con el seed activo se siembra el catálogo, pero sin audio reproducible ni
/// portadas; para una demo offline completa hay que re-declarar esos assets.
const bool kSeedDevData =
    bool.fromEnvironment('NB_SEED', defaultValue: false);

// ── Datos de ejemplo (portados de NB_Sound_Mobile/app/data.jsx) ───────────
// Tupla álbum: (id, título, artistaId, año, claveCover).
const List<(int, String, int, int, String)> _albums =
    <(int, String, int, int, String)>[
  (1, 'nadie sabe lo que va a pasar mañana', 1, 2023, 'nadie-sabe'),
  (2, 'Un verano sin ti', 1, 2022, 'un-verano'),
  (3, '÷ (Divide)', 3, 2017, 'divide'),
  (4, 'YHLQMDLG', 1, 2020, 'yhlqmdlg'),
  (5, 'DeBÍ TiRAR MáS FOToS', 1, 2025, 'debi-tirar'),
  (6, 'ARIRANG', 4, 2026, 'arirang'),
  (7, 'EL ÚLTIMO TOUR DEL MUNDO', 1, 2020, 'ultimo-tour'),
  (8, 'The Life of a Showgirl', 6, 2025, 'showgirl'),
  (9, '30', 2, 2021, 'adele-30'),
  (10, 'Positions', 5, 2020, 'positions'),
  (11, '21', 2, 2011, 'adele-21'),
  (12, 'Apambichao', 7, 2024, 'apambichao'),
];

// Tupla artista: (id, nombre, claveCover).
const List<(int, String, String)> _artistas = <(int, String, String)>[
  (1, 'Bad Bunny', 'nadie-sabe'),
  (2, 'Adele', 'adele-30'),
  (3, 'Ed Sheeran', 'divide'),
  (4, 'BTS', 'arirang'),
  (5, 'Ariana Grande', 'positions'),
  (6, 'Taylor Swift', 'showgirl'),
  (7, 'Manuel Turizo', 'apambichao'),
];

// Tupla pista: (id, título, artistaId, artistaNombre, albumId, duraciónSeg, liked).
const List<(int, String, int, String, int, int, bool)> _pistas =
    <(int, String, int, String, int, int, bool)>[
  (1, 'Monaco', 1, 'Bad Bunny', 1, 226, true),
  (2, 'Fina', 1, 'Bad Bunny', 1, 201, false),
  (3, 'Vou 787', 1, 'Bad Bunny', 1, 188, false),
  (4, 'Tití Me Preguntó', 1, 'Bad Bunny', 2, 243, true),
  (5, 'Moscow Mule', 1, 'Bad Bunny', 2, 245, false),
  (6, 'Ojitos Lindos', 1, 'Bad Bunny', 2, 258, false),
  (7, 'Perfect', 3, 'Ed Sheeran', 3, 263, true),
  (8, 'Shape of You', 3, 'Ed Sheeran', 3, 234, false),
  (9, 'Castle on the Hill', 3, 'Ed Sheeran', 3, 261, false),
  (10, 'Safaera', 1, 'Bad Bunny', 4, 295, false),
  (11, 'Yo Perreo Sola', 1, 'Bad Bunny', 4, 192, true),
  (12, 'BAILE INoLVIDABLE', 1, 'Bad Bunny', 5, 310, false),
  (13, 'No. 29', 4, 'BTS', 6, 99, false),
  (14, 'Spring Day', 4, 'BTS', 6, 285, true),
  (15, 'Dakiti', 1, 'Bad Bunny', 7, 205, false),
  (16, 'The Fate of Ophelia', 6, 'Taylor Swift', 8, 218, true),
  (17, 'Easy on Me', 2, 'Adele', 9, 224, true),
  (18, 'Oh My God', 2, 'Adele', 9, 225, false),
  (19, 'positions', 5, 'Ariana Grande', 10, 172, false),
  (20, 'Someone Like You', 2, 'Adele', 11, 285, true),
  (21, 'Rolling in the Deep', 2, 'Adele', 11, 228, false),
  (22, 'Apambichao', 7, 'Manuel Turizo', 12, 148, false),
];

// Tupla playlist: (id, nombre, tipo, predicado de pertenencia).
final List<(int, String, String, bool Function((int, String, int, String, int, int, bool)))>
    _playlists = <(
  int,
  String,
  String,
  bool Function((int, String, int, String, int, int, bool))
)>[
  (1, 'Me gusta', 'me-gusta', (t) => t.$7),
  (2, 'This is Bad Bunny', 'this-is', (t) => t.$3 == 1),
  (3, 'Voces femeninas', 'manual', (t) => t.$3 == 2 || t.$3 == 5 || t.$3 == 6),
  (4, 'Pop internacional', 'inteligente', (t) => t.$3 == 3 || t.$3 == 5),
];

String _coverAsset(String key) => 'assets/covers/$key.png';

String _audioAsset(int pistaId) =>
    'assets/audio/sample_${(pistaId % 3) + 1}.mp3';

String _albumTitulo(int albumId) =>
    _albums.firstWhere(((int, String, int, int, String) a) => a.$1 == albumId).$2;

String _albumCover(int albumId) =>
    _coverAsset(_albums.firstWhere(((int, String, int, int, String) a) => a.$1 == albumId).$5);

/// Siembra el catálogo de ejemplo solo si está habilitado ([kSeedDevData]) y la
/// BD está vacía. Es la vía de la app (no hace nada en producción).
Future<void> applyDevSeedIfEmpty(AppDatabase db) async {
  if (!kSeedDevData) {
    return;
  }
  if (await db.catalogDao.contarPistas() > 0) {
    return;
  }
  await seedDevData(db);
}

/// Inserta el catálogo de ejemplo (sin comprobar el flag ni la emptiness).
/// Pensado para los tests; en la app se invoca vía [applyDevSeedIfEmpty].
Future<void> seedDevData(AppDatabase db) async {
  await db.catalogDao.upsertArtistas(<ArtistasCompanion>[
    for (final (int id, String nombre, String cover) a in _artistas)
      ArtistasCompanion.insert(
        id: Value(a.$1),
        nombre: a.$2,
        imagenPath: Value(_coverAsset(a.$3)),
        syncVersion: const Value(1),
      ),
  ]);

  await db.catalogDao.upsertAlbums(<AlbumsCompanion>[
    for (final (int id, String titulo, int artistaId, int anio, String cover)
        a in _albums)
      AlbumsCompanion.insert(
        id: Value(a.$1),
        titulo: a.$2,
        artistaId: Value(a.$3),
        anio: Value(a.$4),
        coverPath: Value(_coverAsset(a.$5)),
        syncVersion: const Value(1),
      ),
  ]);

  // trackNumber por orden de aparición dentro de cada álbum.
  final Map<int, int> trackCounter = <int, int>{};
  await db.catalogDao.upsertPistas(<PistasCompanion>[
    for (final (
          int id,
          String titulo,
          int artistaId,
          String artistaNombre,
          int albumId,
          int dur,
          bool liked
        ) t in _pistas)
      PistasCompanion.insert(
        id: Value(t.$1),
        titulo: t.$2,
        artistaNombre: t.$4,
        albumTitulo: Value(_albumTitulo(t.$5)),
        albumId: Value(t.$5),
        artistaId: Value(t.$3),
        trackNumber: Value(trackCounter.update(t.$5, (int v) => v + 1,
            ifAbsent: () => 1)),
        duracionSeg: Value(t.$6.toDouble()),
        coverPath: Value(_albumCover(t.$5)),
        audioPath: Value(_audioAsset(t.$1)),
        syncVersion: const Value(1),
      ),
  ]);

  for (final (
        int id,
        String nombre,
        String tipo,
        bool Function((int, String, int, String, int, int, bool)) pred
      ) pl in _playlists) {
    await db.catalogDao.upsertPlaylists(<PlaylistsCompanion>[
      PlaylistsCompanion.insert(
        id: Value(pl.$1),
        nombre: pl.$2,
        tipo: Value(pl.$3),
        syncVersion: const Value(1),
      ),
    ]);
    int pos = 0;
    final List<PlaylistPistasCompanion> miembros = <PlaylistPistasCompanion>[
      for (final (int, String, int, String, int, int, bool) t in _pistas)
        if (pl.$4(t))
          PlaylistPistasCompanion.insert(
            playlistId: pl.$1,
            pistaId: t.$1,
            posicion: pos++,
          ),
    ];
    await db.catalogDao.upsertPlaylistPistas(miembros);
  }

  // Refleja los favoritos del seed en la tabla local (fuente de verdad móvil).
  for (final (int, String, int, String, int, int, bool) t in _pistas) {
    if (t.$7) {
      await db.favoritesDao.setFavorita(t.$1, true);
    }
  }
}
