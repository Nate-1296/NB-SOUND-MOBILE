import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/db/daos/sync_state_dao.dart';

/// Tipo de un resultado de búsqueda recordado en el historial.
enum TipoItemBusqueda { pista, album, artista, playlist }

/// Un resultado de búsqueda **real** guardado en el historial (estilo Spotify):
/// no es el texto tecleado sino el ítem que el usuario abrió (pista/álbum/
/// artista/playlist). Al tocarlo en el historial se reproduce (pista) o se navega
/// a él (álbum/artista/playlist), sin reescribir la query.
class ItemBusqueda {
  const ItemBusqueda({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.subtitulo,
    this.cover,
  });

  factory ItemBusqueda.fromJson(Map<String, dynamic> j) => ItemBusqueda(
        tipo: TipoItemBusqueda.values.firstWhere(
          (TipoItemBusqueda t) => t.name == j['tipo'],
          orElse: () => TipoItemBusqueda.pista,
        ),
        id: (j['id'] as num?)?.toInt() ?? 0,
        titulo: j['titulo'] as String? ?? '',
        subtitulo: j['subtitulo'] as String? ?? '',
        cover: j['cover'] as String?,
      );

  final TipoItemBusqueda tipo;
  final int id;
  final String titulo;
  final String subtitulo;

  /// Ruta/URL de portada (álbum/pista) o imagen (artista); null para playlists o
  /// sin portada. El artista se pinta en círculo.
  final String? cover;

  bool get circular => tipo == TipoItemBusqueda.artista;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'tipo': tipo.name,
        'id': id,
        'titulo': titulo,
        'subtitulo': subtitulo,
        if (cover != null) 'cover': cover,
      };

  /// Igualdad por identidad lógica (tipo + id), para deduplicar el historial.
  bool mismo(ItemBusqueda o) => o.tipo == tipo && o.id == id;
}

/// Historial de resultados de búsqueda (recientes primero), persistido.
class RecientesBusqueda extends Notifier<List<ItemBusqueda>> {
  static const int _max = 12;

  @override
  List<ItemBusqueda> build() {
    _cargar();
    return const <ItemBusqueda>[];
  }

  Future<void> _cargar() async {
    final String? raw = await ref
        .read(syncStateDaoProvider)
        .getValor(SyncStateDao.kBusquedasRecientesItems);
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is List) {
        state = <ItemBusqueda>[
          for (final Object? x in decoded)
            if (x is Map<String, dynamic>) ItemBusqueda.fromJson(x),
        ];
      }
    } catch (_) {
      // valor corrupto: se ignora.
    }
  }

  void registrar(ItemBusqueda item) {
    final List<ItemBusqueda> nuevo = <ItemBusqueda>[
      item,
      for (final ItemBusqueda i in state)
        if (!i.mismo(item)) i,
    ];
    state = nuevo.length > _max ? nuevo.sublist(0, _max) : nuevo;
    _persistir();
  }

  void borrar(ItemBusqueda item) {
    state = <ItemBusqueda>[
      for (final ItemBusqueda i in state)
        if (!i.mismo(item)) i,
    ];
    _persistir();
  }

  void borrarTodo() {
    state = const <ItemBusqueda>[];
    _persistir();
  }

  void _persistir() => ref.read(syncStateDaoProvider).setValor(
        SyncStateDao.kBusquedasRecientesItems,
        jsonEncode(<Map<String, dynamic>>[
          for (final ItemBusqueda i in state) i.toJson(),
        ]),
      );
}

final NotifierProvider<RecientesBusqueda, List<ItemBusqueda>>
    recientesBusquedaProvider =
    NotifierProvider<RecientesBusqueda, List<ItemBusqueda>>(
        RecientesBusqueda.new);
