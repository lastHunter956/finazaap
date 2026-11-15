import 'dart:io';

import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/transfer.dart';
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
    tempDir = await Directory.systemTemp.createTemp('moneo_forms_test_');
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
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'COP',
    });
    await CurrencyHelper.loadCurrency();
  });

  Widget wrapScreen(Widget screen) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => screen),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'AddExpenseScreen conserva datos y no cierra la pantalla cuando falla validación al guardar, y muestra vía para crear categorías si está vacío',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapScreen(const AddExpenseScreen()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(AddExpenseScreen), findsOneWidget);
      expect(find.text('Sin categorías · Crear'), findsOneWidget);

      // Escribir un detalle antes de intentar guardar inválido
      final detailField = find.widgetWithText(TextField, 'Detalles...');
      await tester.enterText(detailField, 'Cafe de prueba');
      await tester.pump();

      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // Debe permanecer abierto y conservar el detalle ingresado
      expect(find.byType(AddExpenseScreen), findsOneWidget);
      expect(find.text('Cafe de prueba'), findsOneWidget);
      expect(find.text('Por favor completa todos los campos'), findsOneWidget);

      // La fecha completa debe estar renderizada dentro de FittedBox sin ellipsis
      final now = DateTime.now();
      final expectedDate = '${now.day}/${now.month}/${now.year}';
      expect(find.text(expectedDate), findsOneWidget);
    },
  );

  testWidgets(
    'Add_Screen muestra Sin categorías · Crear cuando no hay categorías y conserva fecha completa',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapScreen(const Add_Screen()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(Add_Screen), findsOneWidget);
      expect(find.text('Sin categorías · Crear'), findsOneWidget);

      final now = DateTime.now();
      final expectedDate = '${now.day}/${now.month}/${now.year}';
      expect(find.text(expectedDate), findsOneWidget);
    },
  );

  testWidgets(
    'TransferScreen conserva datos y no cierra la pantalla cuando falla validación al transferir',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(wrapScreen(const TransferScreen()));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.byType(TransferScreen), findsOneWidget);

      final detailField =
          find.widgetWithText(TextField, 'Detalle (opcional)');
      await tester.enterText(detailField, 'Transferencia test');
      await tester.pump();

      await tester.ensureVisible(find.text('Transferir'));
      await tester.tap(find.text('Transferir'));
      await tester.pumpAndSettle();

      expect(find.byType(TransferScreen), findsOneWidget);
      expect(find.text('Transferencia test'), findsOneWidget);
      expect(find.text('Por favor ingresa un monto'), findsOneWidget);
    },
  );
}
