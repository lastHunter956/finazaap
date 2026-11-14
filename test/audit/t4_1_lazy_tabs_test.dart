import 'dart:io';

import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/Screens/main_container.dart';
import 'package:finazaap/Screens/responsibilities_screen.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    await initializeDateFormatting('es_ES', null);
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t4_1_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'accounts': <String>[],
      'available_balance': 0.0,
      'default_currency': 'COP',
    });
    await PrefsManager.init();
    final prefs = await PrefsManager.instance;
    await prefs.reload();
    await CurrencyHelper.loadCurrency();

    if (Hive.isBoxOpen('data')) {
      await Hive.box<Add_data>('data').clear();
    } else {
      await Hive.openBox<Add_data>('data');
    }
    if (Hive.isBoxOpen('responsibilities')) {
      await Hive.box<Responsibility>('responsibilities').clear();
    } else {
      await ResponsibilityService.init();
      await Hive.box<Responsibility>('responsibilities').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('T4.1: MainContainer monta solo Home en índice 0 y difiere pestañas no visitadas', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
        ),
        home: const MainContainer(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Home), findsOneWidget);
    expect(find.byType(ResponsibilitiesScreen), findsNothing);
    expect(find.byType(CategoriesScreen), findsNothing);
    expect(find.byType(Statistics), findsNothing);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
