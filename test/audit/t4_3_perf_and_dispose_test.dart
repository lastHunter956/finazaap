import 'dart:io';

import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/selecctaccount.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart';
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
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t4_3_');
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
      builder: (context, widget) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: const TextScaler.linear(0.75),
        ),
        child: widget!,
      ),
      home: child,
    );
  }

  testWidgets('FloatingActionMenuScreen uses FadeTransition without Opacity over BackdropFilter',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 2880);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithTheme(const FloatingActionMenuScreen()));
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.byType(BackdropFilter), findsOneWidget);
    expect(find.byType(FadeTransition), findsWidgets);
    expect(
      find.ancestor(
        of: find.byType(BackdropFilter),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('selecctaccount MyHomePage uses ListView in view mode', (tester) async {
    tester.view.physicalSize = const Size(1440, 2880);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrapWithTheme(MyHomePage(onBalanceUpdated: (_) {})),
    );
    await tester.pump();

    expect(find.byType(ListView), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Add_Screen and TransferScreen dispose controllers cleanly', (tester) async {
    tester.view.physicalSize = const Size(1440, 2880);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(wrapWithTheme(const Add_Screen()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    await tester.pumpWidget(wrapWithTheme(const TransferScreen()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
