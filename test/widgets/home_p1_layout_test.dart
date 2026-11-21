import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/monthly_summary_cache.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es_ES', null);
    tempDir = await Directory.systemTemp.createTemp('moneo_home_p1_');
    Hive.init(tempDir.path);
    final addAdapter = AdddataAdapter();
    if (!Hive.isAdapterRegistered(addAdapter.typeId)) {
      Hive.registerAdapter(addAdapter);
    }
    final respAdapter = ResponsibilityAdapter();
    if (!Hive.isAdapterRegistered(respAdapter.typeId)) {
      Hive.registerAdapter(respAdapter);
    }
    await Hive.openBox<Add_data>('data');
    await Hive.openBox<Responsibility>('responsibilities');
    const MethodChannel('home_widget');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      (_) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('home_widget/updates'),
      (_) async => null,
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'USD',
      'accounts': <String>[
        json.encode({
          'title': 'Banco Principal',
          'subtitle': 'Cuenta Corriente',
          'balance': '1500.00',
          'includeInTotal': true,
          'currencyCode': 'USD',
        }),
      ],
      'ingresos': <String>[
        json.encode({
          'text': 'Salario',
          'icon': Icons.work.codePoint,
          'color': 0xFF10B981,
        }),
      ],
      'gastos': <String>[
        json.encode({
          'text': 'Comida',
          'icon': Icons.restaurant.codePoint,
          'color': 0xFFE67E22,
        }),
      ],
      'income_categories': <String>['Salario'],
      'expense_categories': <String>['Comida'],
    });
    await PrefsManager.init();
    await CurrencyHelper.loadCurrency();
    await Hive.box<Add_data>('data').clear();
    await Hive.box<Responsibility>('responsibilities').clear();
    MonthlySummaryCache.instance.invalidate();
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

  Widget buildHomeHarness({
    required AppThemeMode mode,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) {
    return MaterialApp(
      key: ValueKey('home-$mode-${size.width}x${size.height}-$textScale'),
      theme: buildThemeData(mode),
      home: MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: const Home(),
      ),
    );
  }

  group('TotalBalanceWidget P1', () {
    testWidgets(
      'Muestra Disponible prominente (32px tabular) sin filtros internos y anillo 1.0 en t.expense cuando gastos > ingresos',
      (tester) async {
        final balanceNotifier = ValueNotifier<double>(2500.0);
        addTearDown(balanceNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.diurno),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TotalBalanceWidget(
                  availableBalanceNotifier: balanceNotifier,
                  accountingBalance: -300.0,
                  totalExpenses: 800.0,
                  totalIncome: 500.0,
                  onManageAccounts: () {},
                  selectedMonthYear: 'Nov 2026',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // No debe mostrar los antiguos botones de filtro dentro de la tarjeta
        expect(find.text('Todos'), findsNothing);
        expect(find.text('Gastos'), findsNothing);
        expect(find.text('Ingresos'), findsNothing);

        // Disponible prominente >= 32px con tabularFigures
        final amountText = tester.widget<Text>(find.text('\$2,500.00'));
        expect(amountText.style?.fontSize, greaterThanOrEqualTo(32));
        expect(
          amountText.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );

        // Anillo custom en 1.0 con color t.expense y etiqueta EXCEDIDO
        final t = AppTheme.forMode(AppThemeMode.diurno);
        final arcPaint = tester.widget<CustomPaint>(
          find.byKey(const Key('budget_progress_arc')),
        );
        final painter = arcPaint.painter! as BudgetArcPainter;
        expect(painter.progress, equals(1.0));
        expect(painter.progressColor, equals(t.expense));
        expect(find.text('EXCEDIDO'), findsOneWidget);
      },
    );

    testWidgets(
      'Selector modal de mes/año renderiza sin overflow en 360x640 con TextScaler 1.35',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final balanceNotifier = ValueNotifier<double>(1250000.0);
        addTearDown(balanceNotifier.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildThemeData(AppThemeMode.nocturno),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(360, 640),
                textScaler: TextScaler.linear(1.35),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: TotalBalanceWidget(
                    availableBalanceNotifier: balanceNotifier,
                    accountingBalance: 500000.0,
                    totalExpenses: 900000.0,
                    totalIncome: 0.0,
                    onManageAccounts: () {},
                    selectedMonthYear: 'Nov 2026',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Nov 2026'));
        await tester.pumpAndSettle();

        expect(find.text('Seleccionar período'), findsOneWidget);
        expect(find.text('Aplicar filtro'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
      },
    );
  });

  group('Home P1 - Filtros, Agrupación, Color de Categoría, Vacío y 360x640 @ 1.35x', () {
    testWidgets(
      'Usa MoneoSegmentedControl junto al historial, agrupa por "Hoy · ...", aplica color de categoría y hora HH:mm',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final now = DateTime.now();
        final todayTxTime = DateTime(now.year, now.month, now.day, 14, 35);
        final otherSameMonthDay = now.day > 1
            ? todayTxTime.subtract(const Duration(days: 1))
            : todayTxTime.add(const Duration(days: 2));
        final box = Hive.box<Add_data>('data');

        await tester.runAsync(() async {
          await box.add(
            Add_data(
              'Expenses',
              '45.50',
              todayTxTime,
              'Almuerzo',
              'Comida',
              'Banco Principal',
              Icons.restaurant.codePoint,
            ),
          );
          await box.add(
            Add_data(
              'Income',
              '1200.00',
              otherSameMonthDay,
              'Pago quincena',
              'Salario',
              'Banco Principal',
              Icons.work.codePoint,
            ),
          );
        });
        MonthlySummaryCache.instance.invalidate();

        await tester.pumpWidget(buildHomeHarness(mode: AppThemeMode.diurno));
        await tester.pumpAndSettle();

        // MoneoSegmentedControl presente junto al historial (y no dentro de TotalBalanceWidget)
        expect(
          find.byKey(const Key('home_transaction_filter_segmented')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(TotalBalanceWidget),
            matching: find.byType(MoneoSegmentedControl<String>),
          ),
          findsNothing,
        );
        expect(find.text('Historial de transacciones'), findsOneWidget);

        // Agrupación legible Hoy · dd MMM y Ayer · dd MMM (o EEE dd MMM yyyy)
        final todayCompact =
            DateFormat('dd MMM', 'es').format(todayTxTime).replaceAll('.', '');
        final String secondDayLabel;
        if (now.day > 1) {
          final yesterdayCompact = DateFormat('dd MMM', 'es')
              .format(otherSameMonthDay)
              .replaceAll('.', '');
          secondDayLabel = 'Ayer · $yesterdayCompact';
        } else {
          final raw = DateFormat('EEE dd MMM yyyy', 'es')
              .format(otherSameMonthDay)
              .replaceAll('.', '');
          secondDayLabel = raw[0].toUpperCase() + raw.substring(1);
        }
        expect(find.text('Hoy · $todayCompact'), findsOneWidget);
        expect(find.text(secondDayLabel), findsOneWidget);

        // Subtítulo con hora HH:mm · cuenta y monto tabular en fila de transacción
        expect(find.text('14:35 · Banco Principal'), findsOneWidget);
        final expenseAmount = tester.widget<Text>(
          find.descendant(
            of: find.byType(SliverList),
            matching: find.text('\$45.50'),
          ),
        );
        expect(
          expenseAmount.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );

        // Color de categoría real (#E67E22) pasado por AppColors.getReadableColor
        final iconContainer = tester.widget<Container>(
          find.byKey(const ValueKey('tx_icon_Comida')),
        );
        final iconWidget = iconContainer.child as Icon;
        final ctx = tester.element(find.byKey(const ValueKey('tx_icon_Comida')));
        final expectedReadableColor =
            AppColors.getReadableColor(const Color(0xFFE67E22), ctx);
        expect(iconWidget.color, equals(expectedReadableColor));

        // Semántica expandida en cabecera de día
        final todayHeaderSemantics = tester.getSemantics(
          find.ancestor(
            of: find.text('Hoy · $todayCompact'),
            matching: find.byType(Semantics),
          ).first,
        );
        expect(todayHeaderSemantics.flagsCollection.isButton, isTrue);
        expect(
          todayHeaderSemantics.flagsCollection.isExpanded,
          equals(ui.Tristate.isTrue),
        );

        final segmentedFinder =
            find.byKey(const Key('home_transaction_filter_segmented'));

        // Filtrar por Ingresos oculta el gasto de Hoy y muestra el ingreso del otro día
        await tester.tap(
          find.descendant(
            of: segmentedFinder,
            matching: find.text('Ingresos'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Comida - Almuerzo'), findsNothing);
        expect(find.text(secondDayLabel), findsOneWidget);

        // Expandir segundo día y verificar que se muestra el ingreso
        await tester.tap(find.text(secondDayLabel));
        await tester.pumpAndSettle();
        expect(find.text('Salario - Pago quincena'), findsOneWidget);

        // Filtrar por Gastos oculta Salario
        await tester.tap(
          find.descendant(
            of: segmentedFinder,
            matching: find.text('Gastos'),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Comida - Almuerzo'), findsOneWidget);
        expect(find.text('Salario - Pago quincena'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'Estado vacío accionable muestra CTA "Registrar movimiento" >= 48dp y abre formulario',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          buildHomeHarness(
            mode: AppThemeMode.diurno,
            size: const Size(360, 640),
            textScale: 1.35,
          ),
        );
        await tester.pumpAndSettle();

        final emptyStateFinder = find.byKey(
          const Key('home_empty_transactions_state'),
        );
        await tester.scrollUntilVisible(
          emptyStateFinder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        expect(emptyStateFinder, findsOneWidget);
        final ctaFinder = find.byKey(const Key('home_empty_register_cta'));
        await tester.scrollUntilVisible(
          ctaFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(ctaFinder, findsOneWidget);
        expect(find.text('Registrar movimiento'), findsOneWidget);

        final ctaSize = tester.getSize(ctaFinder);
        expect(ctaSize.height, greaterThanOrEqualTo(48.0));

        await tester.ensureVisible(ctaFinder);
        await tester.tap(ctaFinder);
        await tester.pumpAndSettle();
        expect(find.byType(AddExpenseScreen), findsOneWidget);

        Navigator.of(tester.element(find.byType(AddExpenseScreen))).pop();
        await tester.pumpAndSettle();

        // En filtro Ingresos el CTA abre Add_Screen
        await tester.scrollUntilVisible(
          find.text('Ingresos'),
          -150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Ingresos'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          ctaFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(ctaFinder);
        await tester.pumpAndSettle();
        expect(find.byType(Add_Screen), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );

    testWidgets(
      'Home con movimientos renderiza sin overflow en 360x640 con TextScaler 1.35 en los 4 temas',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 640));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final now = DateTime.now();
        final box = Hive.box<Add_data>('data');
        await tester.runAsync(() async {
          await box.add(
            Add_data(
              'Expenses',
              '1250000',
              now,
              'Mercado mensual completo en tienda local',
              'Comida',
              'Banco Principal',
              Icons.restaurant.codePoint,
            ),
          );
          await box.add(
            Add_data(
              'Income',
              '900000',
              now,
              'Honorarios proyecto',
              'Salario',
              'Banco Principal',
              Icons.work.codePoint,
            ),
          );
        });
        MonthlySummaryCache.instance.invalidate();

        for (final mode in [
          AppThemeMode.diurno,
          AppThemeMode.dia,
          AppThemeMode.nocturno,
          AppThemeMode.defaultDark,
        ]) {
          final List<FlutterErrorDetails> errors = [];
          final oldOnError = FlutterError.onError;
          FlutterError.onError = (details) {
            errors.add(details);
            oldOnError?.call(details);
          };
          addTearDown(() => FlutterError.onError = oldOnError);

          await tester.pumpWidget(
            buildHomeHarness(
              mode: mode,
              size: const Size(360, 640),
              textScale: 1.35,
            ),
          );
          await tester.pumpAndSettle();

          await tester.scrollUntilVisible(
            find.text('Comida - Mercado mensual completo en tienda local'),
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();

          FlutterError.onError = oldOnError;
          if (errors.isNotEmpty) {
            for (final err in errors) {
              debugPrint(err.toString());
            }
          }
          expect(
            errors,
            isEmpty,
            reason: '$mode no debe producir overflow en 360x640 @ 1.35x',
          );
          expect(
            tester.takeException(),
            isNull,
            reason: '$mode no debe lanzar excepciones en 360x640 @ 1.35x',
          );
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
      },
    );
  });
}
