import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/annual_projection_screen.dart';
import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es', null);
    tempDir = await Directory.systemTemp.createTemp('moneo_lote1_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
    await Hive.openBox<Add_data>('data');
    await ResponsibilityService.init();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Widget wrapCompactViewport(Widget child) {
    return MaterialApp(
      theme: buildThemeData(AppThemeMode.diurno),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.35),
        ),
        child: child,
      ),
    );
  }

  group('Lote 1 - Mejoras UI Incrementales', () {
    testWidgets(
      'AnnualProjectionScreen tiene FAB con Semantics, tooltip y sin overflow en 360x640 a 1.35x',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          wrapCompactViewport(const AnnualProjectionScreen()),
        );
        await tester.pumpAndSettle();

        final fabFinder = find.byType(FloatingActionButton);
        expect(fabFinder, findsOneWidget);
        final fab = tester.widget<FloatingActionButton>(fabFinder);
        expect(fab.tooltip, 'Nueva obligación anual');

        expect(
          find.bySemanticsLabel(RegExp('Nueva obligación anual')),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CategoriesScreen muestra estado vacío accionable con CTA >= 48dp y sin siembra automática',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          wrapCompactViewport(const CategoriesScreen(activeIndex: 2)),
        );
        await tester.pumpAndSettle();

        expect(find.text('Crear categoría'), findsOneWidget);
        expect(
          find.text('Crea categorías para organizar tus ingresos y egresos.'),
          findsOneWidget,
        );

        final ctaSize = tester.getSize(find.text('Crear categoría'));
        expect(ctaSize.width, greaterThanOrEqualTo(48));

        final buttonFinder = find.ancestor(
          of: find.text('Crear categoría'),
          matching: find.byType(ElevatedButton),
        );
        expect(buttonFinder, findsOneWidget);
        final buttonSize = tester.getSize(buttonFinder);
        expect(buttonSize.height, greaterThanOrEqualTo(48));

        final storedIncome = await CategoryService.getCategories('Income');
        final storedExpenses = await CategoryService.getCategories('Expenses');
        expect(storedIncome, isEmpty);
        expect(storedExpenses, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Statistics renderiza sin overflow y sin truncar fechas con "..." en 360x640 a 1.35x',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(wrapCompactViewport(const Statistics()));
        await tester.pumpAndSettle();

        expect(find.textContaining('...'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Formularios AddScreen, AddExpenseScreen y TransferScreen conservan monto inválido sin cerrar pantalla',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        // Add_Screen (Ingreso)
        await tester.pumpWidget(wrapCompactViewport(const Add_Screen()));
        await tester.pumpAndSettle();
        final incomeAmountField = find.byType(TextField).first;
        await tester.enterText(incomeAmountField, '0');
        await tester.pump();
        final saveIncomeBtn = find.text('Guardar');
        await tester.ensureVisible(saveIncomeBtn);
        await tester.tap(saveIncomeBtn);
        await tester.pump();
        expect(find.text('El monto debe ser mayor a 0'), findsOneWidget);
        expect(find.byType(Add_Screen), findsOneWidget);
        expect(find.text('0'), findsWidgets);

        // AddExpenseScreen (Egreso)
        await tester.pumpWidget(wrapCompactViewport(const AddExpenseScreen()));
        await tester.pumpAndSettle();
        final expenseAmountField = find.byType(TextField).first;
        await tester.enterText(expenseAmountField, '0');
        await tester.pump();
        final saveExpenseBtn = find.text('Guardar');
        await tester.ensureVisible(saveExpenseBtn);
        await tester.tap(saveExpenseBtn);
        await tester.pump();
        expect(find.text('El monto debe ser mayor a 0'), findsOneWidget);
        expect(find.byType(AddExpenseScreen), findsOneWidget);

        // TransferScreen (Transferencia)
        await tester.pumpWidget(wrapCompactViewport(const TransferScreen()));
        await tester.pumpAndSettle();
        final transferAmountField = find.byType(TextField).first;
        await tester.enterText(transferAmountField, '0');
        await tester.pump();
        final saveTransferBtn = find.text('Transferir');
        await tester.ensureVisible(saveTransferBtn);
        await tester.tap(saveTransferBtn);
        await tester.pump();
        expect(find.text('El monto debe ser mayor a 0'), findsOneWidget);
        expect(find.byType(TransferScreen), findsOneWidget);
      },
    );
  });
}
