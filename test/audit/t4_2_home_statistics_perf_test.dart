import 'dart:io';

import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
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
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t4_2_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'accounts': <String>[],
      'available_balance': 0.0,
      'default_currency': 'COP',
    });
    await PrefsManager.init();
    await CurrencyHelper.loadCurrency();
    if (!Hive.isBoxOpen('data')) {
      await Hive.openBox<Add_data>('data');
    } else {
      await Hive.box<Add_data>('data').clear();
    }
  });

  tearDown(() async {
    if (Hive.isBoxOpen('data')) {
      await Hive.box<Add_data>('data').clear();
    }
  });

  tearDownAll(() async {
    await Hive.close().timeout(const Duration(seconds: 2), onTimeout: () => <void>[]);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget wrapWithTheme(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
      ),
      home: Scaffold(body: child),
    );
  }

  testWidgets(
      'Statistics preserves selected year on Hive update (L5.4) and removes 20s TweenAnimationBuilder',
      (tester) async {
    final now = DateTime.now();
    final previousYear = now.year - 1;
    final box = Hive.box<Add_data>('data');

    await tester.runAsync(() async {
      await box.add(
        Add_data(
          'Income',
          '1000',
          now,
          'Salario',
          'Trabajo',
          'Efectivo',
          0,
        ),
      );
      await box.add(
        Add_data(
          'Income',
          '500',
          DateTime(previousYear, 3, 15),
          'Bono',
          'Trabajo',
          'Efectivo',
          0,
        ),
      );
    });

    await tester.pumpWidget(wrapWithTheme(const Statistics()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('${now.year}'), findsOneWidget);

    final tweenBuilders = tester
        .widgetList<TweenAnimationBuilder<double>>(
          find.byType(TweenAnimationBuilder<double>),
        )
        .where((w) => w.duration >= const Duration(seconds: 20));
    expect(tweenBuilders, isEmpty);

    await tester.tap(find.byIcon(Icons.arrow_left));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('$previousYear'), findsOneWidget);

    await tester.runAsync(() async {
      await box.add(
        Add_data(
          'Income',
          '250',
          now,
          'Extra',
          'Trabajo',
          'Efectivo',
          0,
        ),
      );
    });
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('$previousYear'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('TotalBalanceWidget initializes synchronously without initState callback',
      (tester) async {
    var callbackCount = 0;
    final balanceNotifier = ValueNotifier<double>(1000);
    addTearDown(balanceNotifier.dispose);

    await tester.pumpWidget(
      wrapWithTheme(
        TotalBalanceWidget(
          availableBalanceNotifier: balanceNotifier,
          accountingBalance: 1000,
          totalIncome: 500,
          totalExpenses: 200,
          onManageAccounts: () {},
          onShowAll: () {},
          onShowExpenses: () {},
          onShowIncome: () {},
          selectedMonthYear: 'Nov 2026',
          onDateSelected: (_, __) {
            callbackCount++;
          },
        ),
      ),
    );
    await tester.pump();

    expect(callbackCount, 0);
  });
}
