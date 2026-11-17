import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/Screens/annual_projection_screen.dart';
import 'package:finazaap/Screens/daily_transactions.dart';
import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/Screens/responsibilities_screen.dart';
import 'package:finazaap/Screens/selecctaccount.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/widgets/pending_transaction_card.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/add_account_dialogs.dart';
import 'package:finazaap/widgets/add_responsibility_dialog.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart';
import 'package:finazaap/widgets/responsibility_actions_menu.dart';
import 'package:finazaap/widgets/responsibility_list_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await initializeDateFormatting('es', null);
    tempDir = await Directory.systemTemp.createTemp('moneo_p2_test_');
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'default_currency': 'COP',
    });
    await CurrencyHelper.loadCurrency();
    await ThemeNotifier.init();
    await Hive.box<Add_data>('data').clear();
    await ResponsibilityService.getBox().clear();
  });

  Widget wrapCompactViewport(
    AppThemeMode mode,
    Widget child, {
    double textScale = 1.35,
  }) {
    return MaterialApp(
      key: ValueKey('p2-${mode.name}-${child.runtimeType}'),
      theme: buildThemeData(mode),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 640),
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    );
  }

  Future<void> setCompactSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('P2 Estados vacíos accionables (360x640 @ 1.35x, 4 temas)', () {
    testWidgets(
      'SelectAccountScreen (MyHomePage) muestra estado vacío con CTA Crear cuenta >= 48dp y abre diálogo',
      (tester) async {
        await setCompactSurface(tester);

        for (final mode in AppThemeMode.values) {
          SharedPreferences.setMockInitialValues({'default_currency': 'COP'});
          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              MyHomePage(onBalanceUpdated: (_) {}),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('No tienes cuentas registradas'), findsOneWidget);
          expect(find.text('Crear cuenta'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Crear cuenta'),
            findsOneWidget,
          );

          final buttonFinder = find.ancestor(
            of: find.text('Crear cuenta'),
            matching: find.bySubtype<ButtonStyleButton>(),
          );
          expect(buttonFinder, findsOneWidget);
          final size = tester.getSize(buttonFinder);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }

        // Verificar acción del CTA en tema Diurno
        await tester.pumpWidget(
          wrapCompactViewport(
            AppThemeMode.diurno,
            MyHomePage(onBalanceUpdated: (_) {}),
          ),
        );
        await tester.pumpAndSettle();

        final cta = find.text('Crear cuenta');
        await tester.ensureVisible(cta);
        await tester.tap(cta);
        await tester.pumpAndSettle();
        expect(find.byType(AddAccountDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'ResponsibilitiesScreen muestra estado vacío con CTA Nueva obligación >= 48dp y abre diálogo',
      (tester) async {
        await setCompactSurface(tester);

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(mode, const ResponsibilitiesScreen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.text('Nueva obligación'),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 300));

          expect(find.text('No hay responsabilidades'), findsOneWidget);
          expect(find.text('Nueva obligación'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Nueva obligación'),
            findsOneWidget,
          );

          final buttonFinder = find.ancestor(
            of: find.text('Nueva obligación'),
            matching: find.bySubtype<ButtonStyleButton>(),
          );
          expect(buttonFinder, findsOneWidget);
          final size = tester.getSize(buttonFinder);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(
          wrapCompactViewport(
            AppThemeMode.nocturno,
            const ResponsibilitiesScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.scrollUntilVisible(
          find.text('Nueva obligación'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 200));

        final cta = find.text('Nueva obligación');
        await tester.tap(cta);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(AddResponsibilityDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AnnualProjectionScreen muestra estado vacío con CTA Nueva obligación >= 48dp y abre diálogo',
      (tester) async {
        await setCompactSurface(tester);

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(mode, const AnnualProjectionScreen()),
          );
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);

          await tester.scrollUntilVisible(
            find.text('Nueva obligación'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pump(const Duration(milliseconds: 200));

          expect(find.text('No tienes obligaciones registradas'), findsOneWidget);
          expect(find.text('Nueva obligación'), findsOneWidget);
          expect(
            find.bySemanticsLabel('Nueva obligación'),
            findsOneWidget,
          );

          final buttonFinder = find.ancestor(
            of: find.text('Nueva obligación'),
            matching: find.bySubtype<ButtonStyleButton>(),
          );
          expect(buttonFinder, findsOneWidget);
          final size = tester.getSize(buttonFinder);
          expect(size.width, greaterThanOrEqualTo(48));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }

        await tester.pumpWidget(
          wrapCompactViewport(
            AppThemeMode.dia,
            const AnnualProjectionScreen(),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));

        await tester.scrollUntilVisible(
          find.text('Nueva obligación'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump(const Duration(milliseconds: 200));

        final cta = find.text('Nueva obligación');
        await tester.tap(cta);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(AddResponsibilityDialog), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('P2 Cero overflows en 360x640 @ 1.35x en los 4 temas', () {
    testWidgets(
      'SelectAccountScreen con cuentas largas, badge Oculta y saldos altos no desborda',
      (tester) async {
        await setCompactSurface(tester);
        final accounts = [
          AccountItem(
            id: 'acc-1',
            icon: Icons.account_balance,
            title: 'Cuenta Principal de Nómina Bancolombia',
            subtitle: 'Cuenta de Ahorros',
            balance: '18450000',
            iconColor: const Color(0xFF3B82F6),
            includeInTotal: true,
          ),
          AccountItem(
            id: 'acc-2',
            icon: Icons.credit_card,
            title: 'Tarjeta Visa Gold Corporativa Internacional',
            subtitle: 'Tarjeta de Crédito',
            balance: '12500000',
            iconColor: const Color(0xFFEF4444),
            includeInTotal: false,
            cutoffDay: 15,
            paymentDay: 28,
            interestRate: 2.1,
          ),
        ];

        for (final mode in AppThemeMode.values) {
          SharedPreferences.setMockInitialValues({
            'default_currency': 'COP',
            'accounts': accounts.map((a) => json.encode(a.toJson())).toList(),
          });

          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              MyHomePage(onBalanceUpdated: (_) {}),
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Oculta'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'DailyTransactionsScreen y transición de _CollapsibleHeaderDelegate sin overflow',
      (tester) async {
        await setCompactSurface(tester);
        final dataBox = Hive.box<Add_data>('data');
        final txs = List.generate(
          8,
          (i) => Add_data(
            i.isEven ? 'Expenses' : 'Income',
            '${(i + 1) * 450000}',
            DateTime(2026, 11, 16, 9 + i, 30),
            'Compra supermercado mensual detalle extenso $i',
            'Alimentación y Mercado',
            'Cuenta Principal Bancolombia',
            Icons.shopping_cart.codePoint,
            i == 0 ? '3' : '1',
            false,
          ),
        );
        for (final tx in txs) {
          await tester.runAsync(() => dataBox.add(tx));
        }

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              DailyTransactionsScreen(
                dateString: '16/11/2026',
                transactions: txs,
                dailyIncome: 7200000,
                dailyExpense: 5400000,
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);

          // Probar transición parcial y colapso completo del header
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -40),
          );
          await tester.pump(const Duration(milliseconds: 100));
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -240),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'ResponsibilitiesScreen con datos y ResponsibilityListItem sin overflow en 4 temas',
      (tester) async {
        await setCompactSurface(tester);
        final respBox = ResponsibilityService.getBox();
        final regularResp = Responsibility(
          id: 'r-1',
          name: 'Internet Fibra Óptica Empresarial',
          amount: 145000,
          dueDay: 18,
          category: 'servicio',
          frequency: 'mensual',
          isPaid: false,
          iconCode: Icons.wifi.codePoint,
        );
        final cardResp = Responsibility(
          id: 'r-2',
          name: 'Mastercard Platinum Cashback',
          amount: 850000,
          dueDay: 22,
          category: 'tarjeta',
          frequency: 'quincenal',
          isPaid: true,
          cardLimit: 10000000,
          cardBalance: 2450000,
          installments: 6,
          iconCode: Icons.credit_card.codePoint,
        );
        await tester.runAsync(() async {
          await respBox.put(regularResp.safeId, regularResp);
          await respBox.put(cardResp.safeId, cardResp);
        });

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(mode, const ResponsibilitiesScreen()),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);

          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -280),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ResponsibilityListItem(
                      responsibility: regularResp,
                      month: 11,
                      year: 2026,
                      onTap: () {},
                      onEdit: () {},
                      onDelete: () {},
                      onTogglePaid: () {},
                    ),
                    ResponsibilityListItem(
                      responsibility: cardResp,
                      month: 11,
                      year: 2026,
                      precomputedPaidInMonth: 500000,
                      precomputedPending: 350000,
                      onTap: () {},
                      onEdit: () {},
                      onDelete: () {},
                      onTogglePaid: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'AnnualProjectionScreen con datos de múltiples categorías sin overflow ni doble padding',
      (tester) async {
        await setCompactSurface(tester);
        final respBox = ResponsibilityService.getBox();
        await tester.runAsync(() async {
          await respBox.put(
            'ap-1',
            Responsibility(
              id: 'ap-1',
              name: 'Crédito Educativo Universitario Semestral',
              amount: 1850000,
              dueDay: 10,
              category: 'educación',
              frequency: 'mensual',
              isPaid: false,
              iconCode: Icons.school.codePoint,
            ),
          );
          await respBox.put(
            'ap-2',
            Responsibility(
              id: 'ap-2',
              name: 'Arriendo Apartamento Principal',
              amount: 2200000,
              dueDay: 5,
              category: 'vivienda',
              frequency: 'mensual',
              isPaid: false,
              iconCode: Icons.home.codePoint,
            ),
          );
        });

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(mode, const AnnualProjectionScreen()),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'PendingTransactionCard normal y sospechosa sin overflow en 4 temas a 360x640 @ 1.35x',
      (tester) async {
        await setCompactSurface(tester);
        final normalItem = PendingTransactionItem(
          id: 'p-1',
          rawText: 'Compra aprobada por \$ 1.450.000 en Almacenes Éxito',
          comercio: 'Almacenes Éxito Gran Estación Bogotá',
          monto: 1450000,
          fecha: DateTime(2026, 11, 16, 14, 20),
          classification: 'transferencia-propia',
          category: 'Transferencia',
          accountName: 'Cuenta Ahorros Principal',
          destinationAccount: 'Cuenta Nequi Personal',
          confidence: 0.94,
          requiresReview: false,
          autoProcessable: true,
          decisionSource: 'rules',
          createdAt: DateTime(2026, 11, 16, 14, 20),
        );
        final suspiciousItem = PendingTransactionItem(
          id: 'p-2',
          rawText: 'URGENTE verifica tu cuenta en http://ejemplo-invalido.test',
          comercio: 'Alerta de Seguridad Bancaria Urgente',
          monto: 9850000,
          fecha: DateTime(2026, 11, 16, 15, 0),
          classification: 'sospechosa',
          confidence: 0.25,
          requiresReview: true,
          autoProcessable: false,
          flags: const ['anti_fraud_link_detected'],
          decisionSource: 'anti_fraud',
          createdAt: DateTime(2026, 11, 16, 15, 0),
        );

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              Scaffold(
                body: ListView(
                  children: [
                    PendingTransactionCard(
                      item: normalItem,
                      onConfirm: () {},
                      onCorrect: () {},
                      onDiscard: () {},
                    ),
                    PendingTransactionCard(
                      item: suspiciousItem,
                      onConfirm: () {},
                      onCorrect: () {},
                      onDiscard: () {},
                    ),
                  ],
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'FloatingActionMenuScreen y ResponsibilityActionsMenu sin overflow en 4 temas a 360x640 @ 1.35x',
      (tester) async {
        await setCompactSurface(tester);

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(mode, const FloatingActionMenuScreen()),
          );
          await tester.pump(const Duration(milliseconds: 450));
          expect(find.text('Nueva Operación'), findsOneWidget);
          expect(find.byType(SingleChildScrollView), findsWidgets);
          expect(tester.takeException(), isNull);

          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              ResponsibilityActionsMenu(
                onAddResponsibility: () {},
                onPlanIncome: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 450));
          expect(find.text('Acciones'), findsOneWidget);
          expect(find.byType(SingleChildScrollView), findsWidgets);
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'PinCodeScreen sin compresión ni overflow de teclado en 4 temas a 360x640 @ 1.35x',
      (tester) async {
        await setCompactSurface(tester);

        for (final mode in AppThemeMode.values) {
          await tester.pumpWidget(
            wrapCompactViewport(
              mode,
              PinCodeScreen(
                mode: PinMode.setup,
                onCancel: () {},
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 150));

          final digit1Finder = find.bySemanticsLabel('Dígito 1');
          final delFinder = find.bySemanticsLabel('Borrar dígito');
          expect(digit1Finder, findsOneWidget);
          expect(delFinder, findsOneWidget);
          expect(tester.getSize(digit1Finder).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(delFinder).height, greaterThanOrEqualTo(48));
          expect(tester.takeException(), isNull);
        }
      },
    );
  });
}
