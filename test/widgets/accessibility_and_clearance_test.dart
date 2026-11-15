import 'dart:io';

import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/Screens/selecctaccount.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:finazaap/widgets/liquid_glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_a11y_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'COP',
    });
    await CurrencyHelper.loadCurrency();
    await ThemeNotifier.init();
  });

  testWidgets('FloatingActionMenu expone semántica de botón Nueva operación',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
        ),
        home: const Scaffold(
          floatingActionButton: FloatingActionMenu(),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Nueva operación'), findsWidgets);
  });

  testWidgets('MoneoLayoutMetrics.scrollBottomPadding da >= 108px con FAB',
      (tester) async {
    late double bottomPadding;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
        ),
        home: Builder(
          builder: (context) {
            bottomPadding = MoneoLayoutMetrics.scrollBottomPadding(
              context,
              hasFab: true,
            ).bottom;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(bottomPadding, greaterThanOrEqualTo(108.0));
  });

  testWidgets(
      'SettingsScreen separa el selector de divisa para permitir selección directa',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeData(ThemeNotifier.activeMode),
        home: const SettingsScreen(),
      ),
    );

    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    }

    expect(find.text('Divisa por defecto'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'^Selector de divisa por defecto: COP')),
      findsOneWidget,
    );
    final dropdown = find.byType(DropdownButton<String>);
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.textContaining('USD').last);
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.textContaining('Divisa cambiada a USD'),
      findsOneWidget,
    );
  });

  testWidgets('CategoriesScreen expone semántica Nueva categoría en su FAB',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeData(ThemeNotifier.activeMode),
        home: const CategoriesScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.bySemanticsLabel(RegExp('Nueva categoría')), findsOneWidget);
    expect(find.byTooltip('Nueva categoría'), findsOneWidget);
  });

  testWidgets('Cuentas (MyHomePage) expone semántica Nueva cuenta en su FAB',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildThemeData(ThemeNotifier.activeMode),
        home: MyHomePage(onBalanceUpdated: (_) {}),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.bySemanticsLabel(RegExp('Nueva cuenta')), findsOneWidget);
    expect(find.byTooltip('Nueva cuenta'), findsOneWidget);
  });
}
