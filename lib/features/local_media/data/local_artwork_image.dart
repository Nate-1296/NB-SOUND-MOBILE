import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'local_media_channel.dart';

/// [ImageProvider] de la carátula embebida de una pista **local** del teléfono,
/// obtenida por el canal nativo (MediaStore `loadThumbnail`). Se usa solo cuando
/// el catálogo ya confirmó que la pista tiene carátula (`coverPath = localart://`);
/// si por una carrera no hubiera, lanza error y la `Cover` cae al placeholder.
@immutable
class LocalArtworkImage extends ImageProvider<LocalArtworkImage> {
  const LocalArtworkImage(
    this.mediaStoreId, {
    this.size = 512,
    this.channel = const LocalMediaChannel(),
  });

  final int mediaStoreId;
  final int size;
  final LocalMediaChannel channel;

  @override
  Future<LocalArtworkImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<LocalArtworkImage>(this);

  @override
  ImageStreamCompleter loadImage(
    LocalArtworkImage key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _cargar(decode),
      scale: 1.0,
      debugLabel: 'localart://$mediaStoreId',
    );
  }

  Future<ui.Codec> _cargar(ImageDecoderCallback decode) async {
    final Uint8List? bytes = await channel.artwork(mediaStoreId, size: size);
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Sin carátula local para $mediaStoreId');
    }
    final ui.ImmutableBuffer buffer =
        await ui.ImmutableBuffer.fromUint8List(bytes);
    return decode(buffer);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalArtworkImage &&
      other.mediaStoreId == mediaStoreId &&
      other.size == size;

  @override
  int get hashCode => Object.hash(mediaStoreId, size);
}
