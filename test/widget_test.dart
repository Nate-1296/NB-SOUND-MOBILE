import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_sound_mobile/shared/theme/nb_theme.dart';
import 'package:nb_sound_mobile/shared/widgets/bottom_nav.dart';

// Smoke test de presentación: el tema y un widget compartido renderizan sin
// dependencias de BD/streams (esos flujos se validan con los tests de datos y
// el recorrido en emulador).
void main() {
  testWidgets('BottomNav renderiza los 4 destinos con el tema', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: NbTheme.build(NbThemeId.negroPuro),
        home: Scaffold(
          bottomNavigationBar: BottomNav(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomNav), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Buscar'), findsOneWidget);
    expect(find.text('Biblioteca'), findsOneWidget);
    expect(find.text('Playlists'), findsOneWidget);
  });

  test('los 6 temas existen, con su brillo y acento propio', () {
    expect(NbThemeId.values.length, 6);
    // 3 oscuros + 3 claros.
    final int oscuros = NbThemeId.values
        .where((NbThemeId t) => t.brightness == Brightness.dark)
        .length;
    expect(oscuros, 3);
    // Cada tema resuelve una paleta y los acentos no son todos iguales.
    final Set<int> acentos = <int>{
      for (final NbThemeId t in NbThemeId.values)
        (NbPalettes.byId(t).accent.toARGB32()),
    };
    expect(acentos.length, greaterThan(1));
    // Brightness coherente con el id.
    expect(NbThemeId.fromName('arcillaCalida').brightness, Brightness.light);
    expect(NbThemeId.fromName('hieloOled').brightness, Brightness.dark);
  });
}
