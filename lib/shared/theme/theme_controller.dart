import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'nb_theme.dart';

/// Clave de persistencia del tema en la kv de estado (SyncEstado).
const String kTemaPrefKey = 'tema';

/// Clave de tema inicial cargada desde disco. Se sobreescribe en `main()` tras
/// leer la preferencia persistida; por defecto, el primer tema del catálogo.
final Provider<String> initialThemeProvider =
    Provider<String>((Ref ref) => kNbThemes.first.key);

/// Tema activo de la app (por clave). Arranca desde [initialThemeProvider]
/// (preferencia persistida) y guarda cada cambio en la BD para sobrevivir
/// reinicios. La clave es estable (espejo del PC), así que admite los 63 temas.
class ThemeController extends Notifier<String> {
  @override
  String build() => ref.read(initialThemeProvider);

  /// Fija un tema concreto (por clave) y lo persiste.
  void select(String key) {
    state = key;
    ref.read(syncStateDaoProvider).setValor(kTemaPrefKey, key);
  }

  /// Avanza al siguiente tema del catálogo (tweak rápido).
  void cycle() {
    final int i = kNbThemes.indexWhere((NbThemeDef t) => t.key == state);
    final int next = (i + 1) % kNbThemes.length;
    select(kNbThemes[next].key);
  }
}

/// Provider del tema activo (clave).
final NotifierProvider<ThemeController, String> themeControllerProvider =
    NotifierProvider<ThemeController, String>(ThemeController.new);
