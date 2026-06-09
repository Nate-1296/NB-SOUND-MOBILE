import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/features/offline/application/image_resolver.dart';
import 'package:nb_sound_mobile/features/offline/data/offline_store.dart';
import 'package:nb_sound_mobile/shared/util/media_source.dart';

void main() {
  final OfflineStore store = OfflineStore(Directory('/tmp/nb_test'));

  const RemoteMedia remote = RemoteMedia(
    baseUrl: 'https://h:8731',
    token: 't',
    fingerprint: 'fp',
  );

  group('CoverResolver (offline-first)', () {
    test('descargado ⇒ FileImage; remoto ⇒ CachedNetworkImage; nada ⇒ null', () {
      final CoverResolver soloLocal = CoverResolver(
        store: store,
        coversLocales: <int>{10},
        artistasLocales: <int>{5},
      );
      expect(soloLocal.imageFor('/api/v1/asset/cover/10'), isA<FileImage>());
      expect(soloLocal.imageFor('/api/v1/asset/artist/5'), isA<FileImage>());
      // No descargado y sin PC ⇒ respaldo (null).
      expect(soloLocal.imageFor('/api/v1/asset/cover/99'), isNull);

      final CoverResolver conPc = CoverResolver(
        store: store,
        coversLocales: <int>{},
        artistasLocales: <int>{},
        remote: remote,
      );
      expect(conPc.imageFor('/api/v1/asset/cover/99'),
          isA<CachedNetworkImageProvider>());
      expect(conPc.imageFor('/api/v1/asset/artist/5'),
          isA<CachedNetworkImageProvider>());

      final CoverResolver sinNada = CoverResolver(
        store: store,
        coversLocales: <int>{},
        artistasLocales: <int>{},
      );
      expect(sinNada.imageFor('/api/v1/asset/cover/1'), isNull);
      expect(sinNada.imageFor(null), isNull);
      expect(sinNada.imageFor('assets/x.png'), isA<AssetImage>());
    });

    test('cacheWidth envuelve en ResizeImage para decodificar al tamaño', () {
      final CoverResolver r = CoverResolver(
        store: store,
        coversLocales: <int>{10},
        artistasLocales: <int>{},
      );
      expect(r.imageFor('/api/v1/asset/cover/10', cacheWidth: 48),
          isA<ResizeImage>());
    });
  });
}
