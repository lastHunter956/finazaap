import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es_ES', null);
    tempDir = await Directory.systemTemp.createTemp('moneo_home_avail_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
    await Hive.openBox<Add_data>('data');
    await Hive.openBox<Responsibility>('responsibilities');
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'USD',
      'accounts': <String>[],
    });
    await PrefsManager.init();
    await CurrencyHelper.loadCurrency();
    await Hive.box<Add_data>('data').clear();
    await Hive.box<Responsibility>('responsibilities').clear();
  });

  tearDownAll(() async {
    if (Hive.isBoxOpen('data')) {
      await Hive.box<Add_data>('data').close();
    }
    if (Hive.isBoxOpen('responsibilities')) {
      await Hive.box<Responsibility>('responsibilities').close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  testWidgets(
    'Home actualiza Disponible al crear una cuenta con Incluir en saldo total desde Gestionar cuentas',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildThemeData(AppThemeMode.defaultDark),
          home: const Home(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('0.00'), findsWidgets);

      await tester.tap(find.text('Gestionar cuentas'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'Cuenta Nómina');
      await tester.enterText(find.byType(TextField).at(1), '2500.00');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Crear Cuenta'));
      await tester.tap(find.text('Crear Cuenta'));
      await tester.pumpAndSettle();

      // Regresar a Home desde la pantalla de cuentas.
      Navigator.of(
        tester.element(find.byType(FloatingActionButton)),
      ).pop();
      await tester.pumpAndSettle();

      expect(find.textContaining('2,500'), findsWidgets);
    },
  );
}
