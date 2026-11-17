import 'dart:ui' as ui;

import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/widgets/moneo_icon_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

const List<IconData> _historical43Icons = [
  Icons.fastfood,
  Icons.restaurant,
  Icons.local_cafe,
  Icons.local_bar,
  Icons.shopping_bag,
  Icons.shopping_cart,
  Icons.credit_card,
  Icons.receipt,
  Icons.directions_car,
  Icons.directions_bus,
  Icons.flight,
  Icons.hotel,
  Icons.home,
  Icons.build,
  Icons.lightbulb,
  Icons.wifi,
  Icons.health_and_safety,
  Icons.local_hospital,
  Icons.fitness_center,
  Icons.spa,
  Icons.school,
  Icons.book,
  Icons.work,
  Icons.computer,
  Icons.phone_android,
  Icons.tv,
  Icons.videogame_asset,
  Icons.music_note,
  Icons.pets,
  Icons.child_friendly,
  Icons.card_giftcard,
  Icons.savings,
  Icons.account_balance,
  Icons.attach_money,
  Icons.trending_up,
  Icons.category,
  Icons.swap_horiz_rounded,
  Icons.north_rounded,
  Icons.south_rounded,
  Icons.sync_alt,
  Icons.arrow_downward_rounded,
  Icons.arrow_upward_rounded,
  Icons.account_balance_wallet,
];

const List<AppThemeMode> _officialModes = [
  AppThemeMode.defaultDark,
  AppThemeMode.diurno,
  AppThemeMode.dia,
  AppThemeMode.nocturno,
];

Widget _wrapWithTheme(
  AppThemeMode mode,
  Widget child, {
  double textScale = 1.0,
}) {
  return MaterialApp(
    theme: buildThemeData(mode),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 640),
        textScaler: TextScaler.linear(textScale),
      ),
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeNotifier.init();
    await ThemeNotifier.setMode(AppThemeMode.defaultDark);
  });

  group('AppIcons catálogo ampliado y retrocompatibilidad', () {
    test('conserva exactamente los 43 codePoints históricos y los resuelve con getIcon', () {
      expect(_historical43Icons.length, 43);

      final allCodePoints = AppIcons.allIcons.map((i) => i.codePoint).toSet();
      expect(
        allCodePoints.length,
        AppIcons.allIcons.length,
        reason: 'AppIcons.allIcons no debe tener codePoints duplicados',
      );

      for (final legacyIcon in _historical43Icons) {
        expect(
          allCodePoints.contains(legacyIcon.codePoint),
          isTrue,
          reason: 'Falta codePoint histórico ${legacyIcon.codePoint}',
        );
        expect(
          AppIcons.getIcon(legacyIcon.codePoint).codePoint,
          legacyIcon.codePoint,
        );
      }
    });

    test('catalog tiene >= 100 íconos únicos y todas las 8 categorías pobladas', () {
      expect(AppIcons.catalog.length, greaterThanOrEqualTo(100));
      expect(AppIcons.categories.length, 8);

      final catalogCodePoints =
          AppIcons.catalog.map((entry) => entry.icon.codePoint).toSet();
      expect(
        catalogCodePoints.length,
        AppIcons.catalog.length,
        reason: 'AppIcons.catalog no debe tener codePoints duplicados',
      );

      for (final entry in AppIcons.catalog) {
        expect(
          AppIcons.getIcon(entry.icon.codePoint).codePoint,
          entry.icon.codePoint,
          reason: 'Todo ícono del catálogo debe resolverse en AppIcons.getIcon',
        );
      }

      for (final category in AppIcons.categories) {
        final items = AppIcons.search('', category: category);
        expect(
          items,
          isNotEmpty,
          reason: 'La categoría $category debe tener al menos un ícono',
        );
      }
    });

    test('AppIcons.search busca por español, acentos y categoría', () {
      final cafeMatches = AppIcons.search('café');
      expect(cafeMatches.any((e) => e.icon == Icons.local_cafe), isTrue);

      final cafeUnaccented = AppIcons.search('cafe');
      expect(cafeUnaccented.any((e) => e.icon == Icons.local_cafe), isTrue);

      final gymMatches = AppIcons.search('gimnasio');
      expect(gymMatches.any((e) => e.icon == Icons.fitness_center), isTrue);

      final foodFiltered = AppIcons.search('', category: 'Comida');
      expect(foodFiltered.every((e) => e.category == 'Comida'), isTrue);

      final workAliasFiltered = AppIcons.search('', category: 'Trabajo');
      expect(
        workAliasFiltered.every((e) => e.category == 'Trabajo y Otros'),
        isTrue,
      );
      expect(workAliasFiltered, isNotEmpty);
    });
  });

  group('MoneoIconPickerTrigger', () {
    testWidgets('cumple altura mínima >= 48dp, Semantics(button, expanded) y onTap', (tester) async {
      final semanticsHandle = tester.ensureSemantics();
      var tapped = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          AppThemeMode.defaultDark,
          MoneoIconPickerTrigger(
            selectedIcon: Icons.local_cafe,
            accentColor: const Color(0xFF00D09E),
            isExpanded: false,
            onTap: () => tapped = true,
          ),
        ),
      );

      final triggerFinder = find.byType(MoneoIconPickerTrigger);
      final size = tester.getSize(triggerFinder);
      expect(size.height, greaterThanOrEqualTo(48));

      final semantics = tester.getSemantics(triggerFinder);
      expect(semantics.flagsCollection.isButton, isTrue);
      expect(
        semantics.flagsCollection.isExpanded,
        equals(ui.Tristate.isFalse),
      );
      expect(semantics.label, contains('Ícono, seleccionado'));

      await tester.tap(triggerFinder);
      await tester.pump();
      expect(tapped, isTrue);

      // Estado expandido
      await tester.pumpWidget(
        _wrapWithTheme(
          AppThemeMode.diurno,
          MoneoIconPickerTrigger(
            selectedIcon: Icons.local_cafe,
            accentColor: const Color(0xFF00D09E),
            isExpanded: true,
            onTap: () {},
          ),
        ),
      );

      final expandedSemantics = tester.getSemantics(triggerFinder);
      expect(
        expandedSemantics.flagsCollection.isExpanded,
        equals(ui.Tristate.isTrue),
      );
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);

      semanticsHandle.dispose();
    });
  });

  group('MoneoIconPickerPanel', () {
    testWidgets('filtra por categoría, busca en español, muestra estado vacío y llama onIconSelected', (tester) async {
      IconData? pickedIcon;

      await tester.pumpWidget(
        _wrapWithTheme(
          AppThemeMode.defaultDark,
          MoneoIconPickerPanel(
            selectedIcon: Icons.category,
            accentColor: const Color(0xFF2196F3),
            onIconSelected: (icon) => pickedIcon = icon,
          ),
        ),
      );

      // Filtrar por categoría Comida
      await tester.tap(find.text('Comida'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsNothing);

      // Filtrar por categoría Finanzas
      await tester.tap(find.text('Finanzas'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.savings), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsNothing);

      // Volver a Todos y buscar 'café'
      await tester.tap(find.text('Todos'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'café');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.local_cafe), findsOneWidget);
      expect(find.byIcon(Icons.directions_car), findsNothing);

      // Tap en ícono de café -> dispara onIconSelected
      await tester.tap(find.byIcon(Icons.local_cafe));
      await tester.pump();
      expect(pickedIcon, Icons.local_cafe);

      // Limpiar búsqueda y buscar 'gimnasio'
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'gimnasio');
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.fitness_center), findsOneWidget);

      await tester.tap(find.byIcon(Icons.fitness_center));
      await tester.pump();
      expect(pickedIcon, Icons.fitness_center);

      // Estado vacío cuando no coincide
      await tester.enterText(find.byType(TextField), 'zzzz_inexistente');
      await tester.pumpAndSettle();
      expect(find.text('Sin íconos coincidentes'), findsOneWidget);
    });

    testWidgets('targets táctiles de íconos en grilla >= 44x44 dp y cero overflow en 360x640 @ 1.35x en los 4 temas', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final mode in _officialModes) {
        await ThemeNotifier.setMode(mode);

        await tester.pumpWidget(
          _wrapWithTheme(
            mode,
            SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: SizedBox(height: 48),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MoneoIconPickerTrigger(
                          selectedIcon: Icons.account_balance_wallet,
                          accentColor: const Color(0xFF00D09E),
                          isExpanded: true,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MoneoIconPickerPanel(
                    selectedIcon: Icons.account_balance_wallet,
                    accentColor: const Color(0xFF00D09E),
                    onIconSelected: (_) {},
                  ),
                ],
              ),
            ),
            textScale: 1.35,
          ),
        );
        await tester.pumpAndSettle();

        expect(
          tester.takeException(),
          isNull,
          reason: 'No debe haber overflow ni excepciones en $mode (360x640 @ 1.35x)',
        );

        final firstGridTile = find
            .descendant(
              of: find.byType(GridView),
              matching: find.byType(InkWell),
            )
            .first;
        final tileSize = tester.getSize(firstGridTile);
        expect(
          tileSize.width,
          greaterThanOrEqualTo(44),
          reason: 'Ancho táctil del ícono en $mode debe ser >= 44dp',
        );
        expect(
          tileSize.height,
          greaterThanOrEqualTo(44),
          reason: 'Alto táctil del ícono en $mode debe ser >= 44dp',
        );
      }
    });
  });
}
