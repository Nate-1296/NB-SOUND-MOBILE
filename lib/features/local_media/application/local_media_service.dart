import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import '../../../data/db/daos/local_media_dao.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../../data/db/database.dart';
import '../data/local_media_channel.dart';
import 'local_dedupe.dart';
import 'local_ids.dart';
import 'local_media_mapper.dart';

/// Estado del permiso de acceso al audio del dispositivo.
enum PermisoAudio { concedido, denegado, denegadoPermanente }

/// Resultado de un escaneo de música local.
class EscaneoResultado {
  const EscaneoResultado({
    required this.permiso,
    this.indexadas = 0,
    this.duplicadosQuitados = 0,
  });

  final PermisoAudio permiso;
  final int indexadas;
  final int duplicadosQuitados;

  bool get ok => permiso == PermisoAudio.concedido;
}

/// Integra y **gestiona** la música local del teléfono (MediaStore) dentro del
/// catálogo (`origen='local'`, ids negativos): permiso, escaneo, limpieza,
/// dedupe contra lo sincronizado, ocultar/mostrar (sin borrar del teléfono) y
/// relleno de carátulas embebidas en segundo plano.
class LocalMediaService {
  LocalMediaService({
    required this.dao,
    required this.syncState,
    LocalMediaChannel channel = const LocalMediaChannel(),
  }) : _channel = channel;

  final LocalMediaDao dao;
  final SyncStateDao syncState;
  final LocalMediaChannel _channel;

  // ── Permiso ──────────────────────────────────────────────────────────────
  Future<PermisoAudio> estadoPermiso() => _mapear(Permission.audio.status);
  Future<PermisoAudio> pedirPermiso() => _mapear(Permission.audio.request());

  Future<PermisoAudio> _mapear(Future<PermissionStatus> f) async {
    final PermissionStatus s = await f;
    if (s.isGranted || s.isLimited) {
      return PermisoAudio.concedido;
    }
    if (s.isPermanentlyDenied || s.isRestricted) {
      return PermisoAudio.denegadoPermanente;
    }
    return PermisoAudio.denegado;
  }

  // ── Preferencias ───────────────────────────────────────────────────────────
  /// ¿Está oculta TODA la música local? (flag global del usuario).
  Future<bool> ocultaGlobal() async =>
      (await syncState.getValor(SyncStateDao.kMusicaLocalOculta)) == '1';

  /// ¿Revisión automática activada? (por defecto sí).
  Future<bool> autoRevision() async =>
      (await syncState.getValor(SyncStateDao.kMusicaLocalAuto)) != '0';

  Future<void> setAutoRevision(bool v) =>
      syncState.setValor(SyncStateDao.kMusicaLocalAuto, v ? '1' : '0');

  // ── Escaneo ────────────────────────────────────────────────────────────────
  /// Escaneo completo: pide permiso (si [pedir]), lista MediaStore (saltando las
  /// pistas ocultas individualmente y respetando el "ocultar todas"), hace
  /// upsert, elimina lo que ya no existe/está oculto y deduplica. Idempotente.
  Future<EscaneoResultado> escanear({bool pedir = true}) async {
    final PermisoAudio permiso =
        pedir ? await pedirPermiso() : await estadoPermiso();
    if (permiso != PermisoAudio.concedido) {
      return EscaneoResultado(permiso: permiso);
    }
    // "Ocultar todas": no se indexa nada (los archivos siguen en el teléfono).
    if (await ocultaGlobal()) {
      await dao.borrarTodaLocal();
      return EscaneoResultado(permiso: permiso);
    }

    final List<LocalSong> canciones = await _channel.scan();
    final Set<int> ocultos = await dao.idsOcultos();
    final List<LocalSong> visibles = ocultos.isEmpty
        ? canciones
        : <LocalSong>[
            for (final LocalSong s in canciones)
              if (!ocultos.contains(s.id)) s,
          ];

    final CatalogoLocal cat = mapearEscaneo(visibles);
    await dao.upsertLocal(
      artistasLocales: cat.artistas,
      albumsLocales: cat.albums,
      pistasLocales: cat.pistas,
    );

    // Quita las pistas locales que ya no están presentes en el dispositivo o que
    // el usuario acaba de ocultar.
    final Set<int> presentes = <int>{for (final LocalSong s in visibles) s.id};
    final Set<int> indexados = await dao.mediaIdsIndexados();
    final List<int> aBorrar = <int>[
      for (final int mid in indexados)
        if (!presentes.contains(mid)) idLocalPista(mid),
    ];
    if (aBorrar.isNotEmpty) {
      await dao.borrarPistasLocales(aBorrar);
    }
    await dao.limpiarHuerfanosLocales();

    final int dup = await deduplicar();
    final int total = await dao.contarLocales();
    // Carátulas embebidas: en segundo plano (no bloquea la respuesta).
    unawaited(rellenarCaratulas());
    return EscaneoResultado(
      permiso: permiso,
      indexadas: total,
      duplicadosQuitados: dup,
    );
  }

  // ── Ocultar / mostrar ──────────────────────────────────────────────────────
  /// Quita una pista local de la app (no la borra del teléfono) y la recuerda.
  Future<void> ocultarPista(int mediaId, String titulo, String? artista) =>
      dao.ocultarPista(mediaId, titulo, artista);

  /// Revela una pista oculta y la vuelve a indexar.
  Future<void> mostrarPista(int mediaId) async {
    await dao.mostrarPista(mediaId);
    await escanear(pedir: false);
  }

  /// Revela TODAS las pistas ocultas individualmente y re-indexa.
  Future<EscaneoResultado> mostrarTodasOcultas() async {
    await dao.mostrarTodasOcultas();
    return escanear(pedir: false);
  }

  /// Oculta TODA la música local (flag global) y la quita del catálogo.
  Future<void> ocultarTodas() async {
    await syncState.setValor(SyncStateDao.kMusicaLocalOculta, '1');
    await dao.borrarTodaLocal();
  }

  /// Muestra de nuevo toda la música local (desactiva el flag y re-indexa).
  Future<EscaneoResultado> mostrarTodas() async {
    await syncState.setValor(SyncStateDao.kMusicaLocalOculta, '0');
    return escanear(pedir: false);
  }

  // ── Carátulas embebidas (segundo plano) ──────────────────────────────────
  /// Rellena `coverPath` de las pistas locales aún sin probar: `localart://id`
  /// si tienen carátula embebida, o `''` si no (para no volver a probarlas). La
  /// UI muestra el placeholder tipado mientras tanto y la carátula real aparece
  /// de forma incremental (reactivo por el watch del catálogo).
  Future<void> rellenarCaratulas() async {
    while (true) {
      final List<Pista> lote = await dao.localesSinProbarCaratula();
      if (lote.isEmpty) {
        return;
      }
      final Map<int, String> updates = <int, String>{};
      for (final Pista p in lote) {
        final int mid = mediaStoreIdDePista(p.id);
        // size pequeño: solo comprobar existencia (el display la carga grande).
        final bytes = await _channel.artwork(mid, size: 16);
        updates[p.id] =
            (bytes != null && bytes.isNotEmpty) ? coverPathLocal(mid) : '';
      }
      await dao.fijarCoverLocal(updates);
    }
  }

  // ── Dedupe (la sincronizada prima) ───────────────────────────────────────
  /// Elimina las pistas locales que duplican una sincronizada del PC (misma
  /// identidad + duración ±10 s), remapando sus playlists/favoritos a la del PC.
  /// Devuelve cuántas se quitaron.
  Future<int> deduplicar() async {
    final List<Pista> locales = await dao.pistasPorOrigen(origenLocal);
    if (locales.isEmpty) {
      return 0;
    }
    final List<Pista> pc = await dao.pistasPorOrigen(origenPc);
    if (pc.isEmpty) {
      return 0;
    }
    final Map<int, int> mapa = mapaDuplicadosLocales(
      locales.map(_toDedupe).toList(),
      pc.map(_toDedupe).toList(),
    );
    if (mapa.isEmpty) {
      return 0;
    }
    for (final MapEntry<int, int> e in mapa.entries) {
      await dao.remapReferencias(e.key, e.value);
    }
    await dao.borrarPistasLocales(mapa.keys.toList());
    await dao.limpiarHuerfanosLocales();
    return mapa.length;
  }

  static PistaDedupe _toDedupe(Pista p) => PistaDedupe(
        id: p.id,
        titulo: p.titulo,
        artista: p.artistaNombre,
        album: p.albumTitulo,
        duracionSeg: p.duracionSeg,
      );
}
