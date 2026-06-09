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
        theme: NbTheme.build('negro_puro'),
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

  test('catálogo de 63 temas, con claves únicas y acentos variados', () {
    expect(kNbThemes.length, 63);
    // Claves únicas.
    final Set<String> claves = <String>{for (final NbThemeDef t in kNbThemes) t.key};
    expect(claves.length, 63);
    // Hay temas oscuros y claros (brillo derivado del fondo).
    expect(kNbThemes.any((NbThemeDef t) => t.brightness == Brightness.dark), isTrue);
    expect(kNbThemes.any((NbThemeDef t) => t.brightness == Brightness.light), isTrue);
    // Acentos variados.
    final Set<int> acentos = <int>{
      for (final NbThemeDef t in kNbThemes) t.colors.accent.toARGB32(),
    };
    expect(acentos.length, greaterThan(10));
  });

  test('resolución de clave de tema (incluye legacy camelCase)', () {
    // Clave válida nueva.
    expect(nbThemeKeyFromStored('arcilla_calida'), 'arcilla_calida');
    expect(nbThemeByKey('arcilla_calida').brightness, Brightness.light);
    expect(nbThemeByKey('hielo_oled').brightness, Brightness.dark);
    // Claves antiguas (camelCase) de los 6 temas originales se migran.
    expect(nbThemeKeyFromStored('arcillaCalida'), 'arcilla_calida');
    expect(nbThemeKeyFromStored('marfilGrafito'), 'marfil_grafito');
    // Desconocida ⇒ primer tema.
    expect(nbThemeKeyFromStored('inexistente'), kNbThemes.first.key);
    expect(nbThemeKeyFromStored(null), kNbThemes.first.key);
  });
}
