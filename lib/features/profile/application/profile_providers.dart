import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/daos/sync_state_dao.dart';
import '../../sync/application/sync_controller.dart';

/// Perfil del usuario tal como lo expone el PC (solo lectura; docs §4.3).
/// La foto del PC es una ruta local suya, no descargable, así que no se incluye.
@immutable
class PerfilLocal {
  const PerfilLocal({
    required this.nombre,
    required this.totalPistas,
    required this.totalFavoritas,
  });

  factory PerfilLocal.fromJson(Map<String, dynamic> json) => PerfilLocal(
        nombre: (json['nombre'] as String?)?.trim() ?? '',
        totalPistas: (json['total_pistas'] as num?)?.toInt() ?? 0,
        totalFavoritas: (json['total_favoritas'] as num?)?.toInt() ?? 0,
      );

  final String nombre;
  final int totalPistas;
  final int totalFavoritas;
}

/// Perfil persistido del PC (null si nunca se ha sincronizado). Se re-lee tras
/// cada sincronización (depende de `lastSync`).
final FutureProvider<PerfilLocal?> perfilProvider =
    FutureProvider<PerfilLocal?>((Ref ref) async {
  // Re-evaluar cuando termine una sync.
  ref.watch(syncControllerProvider.select((SyncState s) => s.lastSync));
  final String? raw =
      await ref.watch(syncStateDaoProvider).getValor(SyncStateDao.kPerfil);
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final Object? json = jsonDecode(raw);
    if (json is Map<String, dynamic>) {
      return PerfilLocal.fromJson(json);
    }
  } catch (_) {
    // valor corrupto: se trata como sin perfil.
  }
  return null;
});

/// Inicial del avatar de perfil (la del nombre real, o 'N' por defecto).
final Provider<String> inicialPerfilProvider = Provider<String>((Ref ref) {
  final String nombre = (ref.watch(perfilProvider).value?.nombre ?? '').trim();
  return nombre.isEmpty ? 'N' : nombre.substring(0, 1).toUpperCase();
});
