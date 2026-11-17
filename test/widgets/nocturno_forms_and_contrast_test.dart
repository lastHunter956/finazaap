import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    GoogleFonts.config.allowRuntimeFetching = false;
    tempDir = await Directory.systemTemp.createTemp('moneo_nocturno_forms_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    final accountsJson = [
      json.encode({
        'id': 'acc-tc',
        'icon': Icons.credit_card_rounded.codePoint,
        'title': 'Tarjeta Visa',
        'subtitle': 'Tarjeta de Crédito',
        'balance': '120000',
        'iconColor': const Color(0xFFBD93F9).toARGB32(),
        'includeInTotal': false,
      }),
      json.encode({
        'id': 'acc-cash',
        'icon': Icons.account_balance_wallet_rounded.codePoint,
        'title': 'Efectivo',
        'subtitle': 'Efectivo',
        'balance': '450000',
        'iconColor': const Color(0xFF50FA7B).toARGB32(),
        'includeInTotal': true,
      }),
    ];

    final ingresosJson = [
      json.encode({
        'text': 'Salario',
        'icon': Icons.work_rounded.codePoint,
        'color': const Color(0xFF50FA7B).toARGB32(),
      }),
    ];

    final gastosJson = [
      json.encode({
        'text': 'Alimentación',
        'icon': Icons.restaurant_rounded.codePoint,
        'color': const Color(0xFFFF5555).toARGB32(),
      }),
    ];

    SharedPreferences.setMockInitialValues({
      'accounts': accountsJson,
      'deleted_accounts': <String>[],
      'ingresos': ingresosJson,
      'gastos': gastosJson,
      'income_categories': ['Salario'],
      'expense_categories': ['Alimentación'],
      'deleted_income_categories': <String>[],
      'deleted_expense_categories': <String>[],
    });

    await Hive.openBox<Add_data>('data');
    final respBox = await Hive.openBox<Responsibility>('responsibilities');
    await respBox.add(
      Responsibility(
        id: 'resp-1',
        name: 'Internet Fibra Óptica Hogar',
        amount: 95000,
        dueDay: 15,
        category: 'servicio',
        frequency: 'mensual',
        iconCode: Icons.wifi_rounded.codePoint,
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Widget buildHarness(AppThemeMode mode, Widget child) {
    return MaterialApp(
      key: ValueKey('harness-$mode-${child.runtimeType}'),
      theme: buildThemeData(mode),
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 640),
          textScaler: TextScaler.linear(1.35),
        ),
        child: child,
      ),
    );
  }

  const allModes = [
    AppThemeMode.nocturno,
    AppThemeMode.defaultDark,
    AppThemeMode.diurno,
    AppThemeMode.dia,
  ];

  group('FloatingActionMenuScreen - Contraste y layout 360x640 @ 1.35x', () {
    testWidgets(
      'Renderiza sin overflow y con bordes/divisores nítidos en los 4 temas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in allModes) {
          await tester.pumpWidget(
            buildHarness(mode, const FloatingActionMenuScreen()),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$mode: FloatingActionMenuScreen no debe lanzar excepciones ni overflow',
          );

          expect(find.text('Nueva Operación'), findsOneWidget);
          expect(find.text('Ingreso'), findsOneWidget);
          expect(find.text('Transferencia'), findsOneWidget);
          expect(find.text('Egreso'), findsOneWidget);
          expect(find.text('Cerrar'), findsOneWidget);

          final theme = AppTheme.forMode(mode);
          final borderedContainers = tester
              .widgetList<Container>(find.byType(Container))
              .where((c) => c.decoration is BoxDecoration)
              .map((c) => c.decoration as BoxDecoration)
              .where((d) => d.border != null)
              .toList();

          expect(
            borderedContainers.any(
              (d) =>
                  d.border is Border &&
                  (d.border as Border).top.color == theme.borderVisible,
            ),
            isTrue,
            reason: '$mode: debe usar borderVisible para definir card/divisores en Nueva Operación',
          );
        }
      },
    );
  });

  group('Formularios (Egreso, Ingreso, Transferencia) - 360x640 @ 1.35x', () {
    testWidgets(
      'AddExpenseScreen renderiza sin overflow en los 4 temas (incluyendo TC y obligación)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in allModes) {
          await tester.pumpWidget(
            buildHarness(mode, const AddExpenseScreen()),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$mode: AddExpenseScreen inicial no debe tener overflow',
          );
          expect(find.text('Nuevo Egreso'), findsOneWidget);
          expect(find.text('Cuotas'), findsOneWidget);
          expect(find.text('¿Sin intereses?'), findsOneWidget);

          // Activar sección de obligación para verificar ChoiceChips y Divider.
          await tester.tap(find.byType(Switch));
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$mode: AddExpenseScreen con obligación activa no debe tener overflow',
          );
          expect(find.text('Personalizado'), findsOneWidget);
          expect(
            find.text('Marcar obligación como pagada completa'),
            findsOneWidget,
          );

          // Verificar contraste de texto en botones primarios/chips en Nocturno.
          if (mode == AppThemeMode.nocturno) {
            final theme = AppTheme.forMode(mode);
            final saveText = tester.widget<Text>(find.text('Guardar'));
            expect(
              saveText.style?.color,
              isNot(Colors.white),
              reason: 'Nocturno Guardar sobre expense no debe usar Colors.white',
            );
            expect(
              saveText.style?.color,
              theme.foregroundOn(theme.expense),
            );
          }
        }
      },
    );

    testWidgets(
      'Add_Screen renderiza sin overflow en los 4 temas y garantiza contraste en Guardar',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in allModes) {
          await tester.pumpWidget(
            buildHarness(mode, const Add_Screen()),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$mode: Add_Screen no debe tener overflow',
          );
          expect(find.text('Nuevo Ingreso'), findsOneWidget);
          expect(find.text('Guardar'), findsOneWidget);

          if (mode == AppThemeMode.nocturno) {
            final theme = AppTheme.forMode(mode);
            final saveText = tester.widget<Text>(find.text('Guardar'));
            expect(
              saveText.style?.color,
              theme.foregroundOn(theme.income),
            );
          }
        }
      },
    );

    testWidgets(
      'TransferScreen renderiza sin overflow en los 4 temas y DatePicker respeta tema',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        for (final mode in allModes) {
          await tester.pumpWidget(
            buildHarness(mode, const TransferScreen()),
          );
          await tester.pumpAndSettle();

          expect(
            tester.takeException(),
            isNull,
            reason: '$mode: TransferScreen no debe tener overflow',
          );
          expect(find.text('Nueva Transferencia'), findsOneWidget);
          expect(find.text('Transferir'), findsOneWidget);

          if (mode == AppThemeMode.nocturno) {
            final theme = AppTheme.forMode(mode);
            final transferText = tester.widget<Text>(find.text('Transferir'));
            expect(
              transferText.style?.color,
              theme.foregroundOn(theme.secondaryAccent),
            );
          }
        }

        // Abrir DatePicker en Diurno para verificar que no fuerza ThemeData.dark().
        await tester.pumpWidget(
          buildHarness(AppThemeMode.diurno, const TransferScreen()),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byIcon(Icons.calendar_today_rounded));
        await tester.tap(find.byIcon(Icons.calendar_today_rounded));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        final dialogFinder = find.byType(DatePickerDialog);
        expect(dialogFinder, findsOneWidget);
        final dialogContext = tester.element(dialogFinder);
        expect(Theme.of(dialogContext).brightness, Brightness.light);
      },
    );
  });
}
