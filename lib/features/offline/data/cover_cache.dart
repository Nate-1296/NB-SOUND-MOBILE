import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Gestor de caché en disco para las **portadas remotas** del PC. El gestor por
/// defecto de `cached_network_image` solo guarda ~200 objetos y caduca a 30 días,
/// así que con una biblioteca grande las portadas se desalojaban y se volvían a
/// descargar al reentrar a una vista (el "parpadeo" molesto). Este gestor sube el
/// tope a 10 000 objetos y la caducidad a un año: una portada se baja una vez y
/// queda en disco para siempre (en la práctica). Las portadas de pistas
/// descargadas ya viven como archivo local (no pasan por aquí).
class CoverCache {
  CoverCache._();

  static const String _key = 'nbCoverCache';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 365),
      maxNrOfCacheObjects: 10000,
    ),
  );
}
