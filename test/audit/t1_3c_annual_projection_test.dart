import 'dart:convert';
import 'dart:io';

import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/annual_projection_screen.dart';
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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_3c_ann_');
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
      'accounts': [
        jsonEncode({
          'title': 'Ahorros',
          'subtitle': 'Cuenta Bancaria',
          'balance': '1000000.0',
          'icon': Icons.account_balance.codePoint,
          'iconColor': Colors.blue.value,
          'includeInTotal': true,
        }),
        jsonEncode({
          'title': 'Visa',
          'subtitle': 'Tarjeta de Crédito',
          'balance': '1700000.0',
          'icon': Icons.credit_card.codePoint,
          'iconColor': Colors.purple.value,
          'includeInTotal': false,
          'creditLimit': '2000000.0',
        }),
      ],
      'available_balance': 1000000.0,
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

  testWidgets('L3.1: AnnualProjectionScreen excluye tarjetas y muestra obligaciones regulares', (tester) async {
    await tester.runAsync(() async {
      final box = Hive.box<Responsibility>('responsibilities');
      await box.add(Responsibility(
        id: 'visa_id',
        name: 'Visa',
        amount: 300000.0,
        dueDay: 25,
        category: 'tarjeta',
        frequency: 'mensual',
        cardBalance: 300000.0,
        iconCode: Icons.credit_card.codePoint,
      ));
      await box.add(Responsibility(
        id: 'arriendo_id',
        name: 'Arriendo',
        amount: 800000.0,
        dueDay: 5,
        category: 'hogar',
        frequency: 'mensual',
        iconCode: Icons.home.codePoint,
      ));
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
        ),
        home: const AnnualProjectionScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visa'), findsNothing);
    expect(find.text('Arriendo'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('L2.1: AddExpenseScreen excluye obligaciones tarjeta del selector de vinculación', (tester) async {
    await tester.runAsync(() async {
      final box = Hive.box<Responsibility>('responsibilities');
      await box.add(Responsibility(
        id: 'visa_id',
        name: 'Visa',
        amount: 300000.0,
        dueDay: 25,
        category: 'tarjeta',
        frequency: 'mensual',
        cardBalance: 300000.0,
        iconCode: Icons.credit_card.codePoint,
      ));
      await box.add(Responsibility(
        id: 'internet_id',
        name: 'Internet',
        amount: 90000.0,
        dueDay: 10,
        category: 'servicios',
        frequency: 'mensual',
        iconCode: Icons.wifi.codePoint,
      ));
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
        ),
        home: const AddExpenseScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    final toggle = find.byType(Switch).last;
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    expect(find.textContaining('Visa'), findsNothing);
    expect(find.textContaining('Internet'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
