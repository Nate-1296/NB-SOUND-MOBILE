import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import 'nb_theme.dart';

/// Clave de persistencia del tema en la kv de estado (SyncEstado).
const String kTemaPrefKey = 'tema';

/// Tema inicial cargado desde disco. Se sobreescribe en `main()` tras leer la
/// preferencia persistida; por defecto, el primer tema oscuro.
final Provider<NbThemeId> initialThemeProvider =
    Provider<NbThemeId>((Ref ref) => NbThemeId.negroPuro);

/// Tema activo de la app. Arranca desde [initialThemeProvider] (preferencia
/// persistida) y guarda cada cambio en la BD para sobrevivir reinicios.
class ThemeController extends Notifier<NbThemeId> {
  @override
  NbThemeId build() => ref.read(initialThemeProvider);

  /// Fija un tema concreto y lo persiste.
  void select(NbThemeId id) {
    state = id;
    ref.read(syncStateDaoProvider).setValor(kTemaPrefKey, id.name);
  }

  /// Avanza al siguiente tema (tweak rápido del diseño).
  void cycle() {
    final List<NbThemeId> values = NbThemeId.values;
    select(values[(state.index + 1) % values.length]);
  }
}

/// Provider del tema activo.
final NotifierProvider<ThemeController, NbThemeId> themeControllerProvider =
    NotifierProvider<ThemeController, NbThemeId>(ThemeController.new);
