import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/shared/theme/nb_colors.dart';
import 'package:nb_sound_mobile/shared/widgets/cover.dart';
import 'package:nb_sound_mobile/shared/widgets/cover_placeholder.dart';

const NbColors _c = NbColors(
  bg: Color(0xFF101010),
  bg2: Color(0xFF181818),
  bg3: Color(0xFF222222),
  line: Color(0xFF2A2A2A),
  line2: Color(0xFF333333),
  text: Color(0xFFFFFFFF),
  text2: Color(0xFFCCCCCC),
  text3: Color(0xFF888888),
  accent: Color(0xFFC25939),
  accent2: Color(0xFFE0794F),
  ink: Color(0xFF000000),
  soft: Color(0xFF202020),
  ambient: Color(0xFF402020),
);

/// [ImageProvider] que SIEMPRE falla al cargar (simula un `/asset/cover/{id}` que
/// el PC responde 404 porque el álbum no tiene portada).
@immutable
class _FailingImage extends ImageProvider<_FailingImage> {
  const _FailingImage();

  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_FailingImage>(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) =>
      MultiFrameImageStreamCompleter(
        codec: Future<ui.Codec>.error(Exception('404 simulada')),
        scale: 1.0,
      );

  @override
  bool operator ==(Object other) => other is _FailingImage;
  @override
  int get hashCode => 0;
}

Widget _wrap(Widget child) => MaterialApp(
      theme: ThemeData(extensions: const <ThemeExtension<dynamic>>[_c]),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('Cover sin imagen y con kind muestra el placeholder tipado',
      (WidgetTester tester) async {
    await tester.pumpWidget(
        _wrap(const Cover(kind: CoverKind.track, size: 100)));
    await tester.pump();
    expect(find.byType(CoverPlaceholder), findsOneWidget);
  });

  testWidgets(
      'Cover con imagen que falla (404) cae al placeholder en vez de quedar gris',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const Cover(
      image: _FailingImage(),
      kind: CoverKind.album,
      coverSeed: 1,
      size: 100,
    )));
    // La imagen se intenta cargar y falla; el errorBuilder pinta el respaldo.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(CoverPlaceholder), findsOneWidget);
  });

  testWidgets('ArtistAvatar con foto que falla muestra el icono de respaldo',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const ArtistAvatar(
      image: _FailingImage(),
      size: 80,
      seed: 2,
    )));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    // El respaldo del avatar es un icono de persona.
    expect(find.byIcon(iconForCoverKind(CoverKind.artist)), findsOneWidget);
  });
}
