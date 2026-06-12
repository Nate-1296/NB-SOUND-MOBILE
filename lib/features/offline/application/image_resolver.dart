import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/util/media_source.dart';
import '../../sync/application/remote_media_provider.dart';
import '../data/cover_cache.dart';
import '../data/offline_store.dart';
import 'download_providers.dart';

/// Resuelve un `*_path` del catálogo a un [ImageProvider] **offline-first** y
/// optimizado:
/// - imagen descargada en disco → [FileImage] (sirve sin PC);
/// - si no, remota del PC → [CachedNetworkImageProvider] (caché disco+memoria, auth);
/// - si no hay ni local ni PC → null (el llamador pinta el respaldo en gris).
///
/// Siempre envuelto en [ResizeImage] con [cacheWidth] (px del widget) para
/// decodificar el bitmap al tamaño real y no malgastar memoria con portadas
/// grandes del PC. El catálogo nunca se reescribe con rutas locales: la capa
/// offline se consulta aquí, así el re-sync del manifest no pisa nada.
@immutable
class CoverResolver {
  const CoverResolver({
    required this.store,
    required this.coversLocales,
    required this.artistasLocales,
    this.remote,
    this.cacheManager,
  });

  final OfflineStore store;
  final Set<int> coversLocales;
  final Set<int> artistasLocales;
  final RemoteMedia? remote;

  /// Gestor de caché en disco de las portadas remotas (vida larga). Lo inyecta el
  /// provider con [CoverCache.instance]; si es null se usa el por defecto de
  /// `cached_network_image` (los tests no lo pasan para no tocar path_provider).
  final BaseCacheManager? cacheManager;

  ImageProvider? imageFor(String? path, {int? cacheWidth}) {
    final ImageProvider? base = _base(path);
    if (base == null) {
      return null;
    }
    return cacheWidth != null
        ? ResizeImage(base, width: cacheWidth, allowUpscaling: false)
        : base;
  }

  ImageProvider? _base(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }
    if (path.startsWith('assets/')) {
      return AssetImage(path);
    }
    if (path.startsWith('/api/v1/asset/cover/')) {
      final int? id = _idAlFinal(path);
      if (id != null && coversLocales.contains(id)) {
        return FileImage(store.coverFile(id));
      }
      return _remoteOrNull(path);
    }
    if (path.startsWith('/api/v1/asset/artist/')) {
      final int? id = _idAlFinal(path);
      if (id != null && artistasLocales.contains(id)) {
        return FileImage(store.artistFile(id));
      }
      return _remoteOrNull(path);
    }
    if (path.startsWith('http')) {
      return CachedNetworkImageProvider(path, cacheManager: cacheManager);
    }
    if (path.startsWith('/api/')) {
      return _remoteOrNull(path);
    }
    // Ruta de archivo local explícita.
    return FileImage(File(path));
  }

  ImageProvider? _remoteOrNull(String relativeOrAbsolute) {
    final RemoteMedia? r = remote;
    if (r == null) {
      return null;
    }
    return CachedNetworkImageProvider(
      r.urlFor(relativeOrAbsolute),
      headers: r.authHeaders,
      cacheManager: cacheManager,
    );
  }

  static int? _idAlFinal(String path) =>
      int.tryParse(path.split('/').last);
}

/// Píxeles de decodificación para una portada de [logicalSize] dp (= tamaño
/// lógico × densidad de pantalla). Se pasa como `cacheWidth` a [CoverResolver].
int coverCachePx(BuildContext context, double logicalSize) =>
    (logicalSize * MediaQuery.devicePixelRatioOf(context)).round();

/// [CoverResolver] reactivo: se reconstruye al conectar/desconectar el PC y al
/// completarse descargas de imágenes, de modo que las portadas pasan de remoto a
/// local (o a respaldo) automáticamente.
final Provider<CoverResolver> coverResolverProvider =
    Provider<CoverResolver>((Ref ref) {
  return CoverResolver(
    store: ref.watch(offlineStoreProvider),
    coversLocales: ref.watch(coversDescargadasProvider).value ?? const <int>{},
    artistasLocales:
        ref.watch(artistasDescargadosProvider).value ?? const <int>{},
    remote: ref.watch(remoteMediaProvider),
    cacheManager: CoverCache.instance,
  );
});
