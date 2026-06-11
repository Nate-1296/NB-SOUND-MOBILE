import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
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

/// Preferencias de perfil **propias del teléfono** (independientes del PC): el
/// nombre que el usuario fijó a mano y la foto local. El nombre, si está, manda
/// sobre el del PC (no se sobreescribe al sincronizar); si está vacío, se usa el
/// del PC. Persistidas en la kv de estado.
@immutable
class PerfilUsuario {
  const PerfilUsuario({this.nombre, this.fotoPath});

  /// Nombre fijado a mano (null/'' = usar el del PC).
  final String? nombre;

  /// Ruta del archivo local de la foto de perfil (null = sin foto).
  final String? fotoPath;

  PerfilUsuario copyWith({String? nombre, String? fotoPath}) => PerfilUsuario(
        nombre: nombre ?? this.nombre,
        fotoPath: fotoPath ?? this.fotoPath,
      );
}

/// Controla nombre/foto del usuario y los persiste. Carga inicial best-effort.
class PerfilUsuarioController extends Notifier<PerfilUsuario> {
  @override
  PerfilUsuario build() {
    _cargar();
    return const PerfilUsuario();
  }

  Future<void> _cargar() async {
    final SyncStateDao dao = ref.read(syncStateDaoProvider);
    final String? nombre = await dao.getValor(SyncStateDao.kNombreUsuario);
    final String? foto = await dao.getValor(SyncStateDao.kFotoPerfil);
    state = PerfilUsuario(
      nombre: (nombre != null && nombre.trim().isNotEmpty) ? nombre.trim() : null,
      fotoPath: (foto != null && foto.isNotEmpty) ? foto : null,
    );
  }

  /// Fija (o limpia con '') el nombre del usuario y lo persiste.
  Future<void> setNombre(String nombre) async {
    final String n = nombre.trim();
    state = PerfilUsuario(nombre: n.isEmpty ? null : n, fotoPath: state.fotoPath);
    await ref
        .read(syncStateDaoProvider)
        .setValor(SyncStateDao.kNombreUsuario, n);
  }

  /// Fija la ruta de la foto de perfil (cadena vacía la elimina) y la persiste.
  Future<void> setFoto(String? path) async {
    final String p = path ?? '';
    state = PerfilUsuario(nombre: state.nombre, fotoPath: p.isEmpty ? null : p);
    await ref.read(syncStateDaoProvider).setValor(SyncStateDao.kFotoPerfil, p);
  }
}

final NotifierProvider<PerfilUsuarioController, PerfilUsuario>
    perfilUsuarioProvider =
    NotifierProvider<PerfilUsuarioController, PerfilUsuario>(
        PerfilUsuarioController.new);

/// Nombre efectivo del perfil: el fijado por el usuario o, si no, el del PC.
/// Puede ser vacío (sin nombre todavía).
final Provider<String> nombrePerfilProvider = Provider<String>((Ref ref) {
  final String? propio = ref.watch(
      perfilUsuarioProvider.select((PerfilUsuario p) => p.nombre));
  if (propio != null && propio.trim().isNotEmpty) {
    return propio.trim();
  }
  return (ref.watch(perfilProvider).value?.nombre ?? '').trim();
});

/// Imagen del avatar de perfil (foto local) o null si no hay/ no existe.
final Provider<ImageProvider?> avatarPerfilProvider =
    Provider<ImageProvider?>((Ref ref) {
  final String? path =
      ref.watch(perfilUsuarioProvider.select((PerfilUsuario p) => p.fotoPath));
  if (path == null || path.isEmpty) {
    return null;
  }
  final File f = File(path);
  return f.existsSync() ? FileImage(f) : null;
});

/// Inicial del avatar de perfil (la del nombre efectivo, o 'N' por defecto).
final Provider<String> inicialPerfilProvider = Provider<String>((Ref ref) {
  final String nombre = ref.watch(nombrePerfilProvider);
  return nombre.isEmpty ? 'N' : nombre.substring(0, 1).toUpperCase();
});
