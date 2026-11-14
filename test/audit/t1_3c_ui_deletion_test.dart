import 'dart:convert';
import 'dart:io';

import 'package:finazaap/Screens/daily_transactions.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/credit_card_calculator.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/transaction_service.dart';
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
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_3c_del_');
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
          'id': 'acc_ahorros',
          'title': 'Ahorros',
          'subtitle': 'Cuenta Bancaria',
          'balance': '1000000.0',
          'icon': Icons.account_balance.codePoint,
          'iconColor': Colors.blue.value,
          'includeInTotal': true,
        }),
        jsonEncode({
          'id': 'acc_nequi',
          'title': 'Nequi',
          'subtitle': 'Billetera',
          'balance': '500000.0',
          'icon': Icons.phone_android.codePoint,
          'iconColor': Colors.purple.value,
          'includeInTotal': true,
        }),
        jsonEncode({
          'id': 'acc_visa',
          'title': 'Visa',
          'subtitle': 'Tarjeta de Crédito',
          'balance': '2000000.0',
          'icon': Icons.credit_card.codePoint,
          'iconColor': Colors.orange.value,
          'includeInTotal': false,
          'creditLimit': '2000000.0',
          'cutoffDay': 20,
          'paymentDay': 5,
        }),
      ],
      'available_balance': 1500000.0,
      'total_balance': 1500000.0,
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

  Future<Map<String, double>> readAccountBalances() async {
    final prefs = await PrefsManager.instance;
    final list = prefs.getStringList('accounts') ?? [];
    final result = <String, double>{};
    for (final raw in list) {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      result[map['title'] as String] = double.parse(map['balance'].toString());
    }
    return result;
  }

  Widget wrapWithApp(Widget child) {
    return MaterialApp(
      theme: ThemeData.dark().copyWith(
        extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
      ),
      home: child,
    );
  }

  Future<void> deleteViaDailyTransactionsUI(
    WidgetTester tester,
    Finder itemFinder, {
    bool confirm = true,
  }) async {
    await tester.tap(itemFinder);
    await tester.pumpAndSettle();

    final deleteOption = find.text('Eliminar').last;
    await tester.ensureVisible(deleteOption);
    await tester.tap(deleteOption);
    await tester.pumpAndSettle();

    if (confirm) {
      await tester.runAsync(() async {
        await tester.tap(find.text('Eliminar').last);
        await Future<void>.delayed(const Duration(milliseconds: 150));
      });
    } else {
      await tester.tap(find.text('Cancelar').last);
    }
    await tester.pumpAndSettle();
  }

  Future<void> cleanupWidgetTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  void setMobileViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  group('L1.1 DailyTransactionsScreen - Eliminación contable', () {
    testWidgets('cancelar confirmación de eliminación no modifica nada', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 10, 0);
      await tester.runAsync(() async {
        await TransactionService.processTransaction(
          type: 'Income',
          amount: 200000,
          accountName: 'Ahorros',
        );
        // Add_data(IN, amount, datetime, explain/detail, name/category, account, iconCode)
        final tx = Add_data(
          'Income',
          '200000',
          date,
          'Nómina mayo',
          'Salario',
          'Ahorros',
          Icons.work.codePoint,
        );
        await Hive.box<Add_data>('data').add(tx);
      });

      final txs = Hive.box<Add_data>('data').values.toList();
      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: txs,
        dailyIncome: 200000,
        dailyExpense: 0,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.text('Salario - Nómina mayo'),
        confirm: false,
      );

      final balances = await readAccountBalances();
      expect(balances['Ahorros'], 1200000.0);
      expect(Hive.box<Add_data>('data').length, 1);
      await cleanupWidgetTree(tester);
    });

    testWidgets('eliminar ingreso revierte su efecto una sola vez', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 10, 0);
      await tester.runAsync(() async {
        await TransactionService.processTransaction(
          type: 'Income',
          amount: 250000,
          accountName: 'Ahorros',
        );
        await Hive.box<Add_data>('data').add(Add_data(
          'Income',
          '250000',
          date,
          'Bono',
          'Salario',
          'Ahorros',
          Icons.work.codePoint,
        ));
      });

      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: Hive.box<Add_data>('data').values.toList(),
        dailyIncome: 250000,
        dailyExpense: 0,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.text('Salario - Bono'),
      );

      final balances = await readAccountBalances();
      expect(balances['Ahorros'], 1000000.0);
      expect(Hive.box<Add_data>('data').length, 0);
      final prefs = await PrefsManager.instance;
      expect(prefs.getDouble('available_balance'), 1500000.0);
      await cleanupWidgetTree(tester);
    });

    testWidgets('eliminar gasto revierte su efecto una sola vez', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 11, 0);
      await tester.runAsync(() async {
        await TransactionService.processTransaction(
          type: 'Expenses',
          amount: 120000,
          accountName: 'Ahorros',
        );
        await Hive.box<Add_data>('data').add(Add_data(
          'Expenses',
          '120000',
          date,
          'Mercado',
          'Comida',
          'Ahorros',
          Icons.fastfood.codePoint,
        ));
      });

      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: Hive.box<Add_data>('data').values.toList(),
        dailyIncome: 0,
        dailyExpense: 120000,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.text('Comida - Mercado'),
      );

      final balances = await readAccountBalances();
      expect(balances['Ahorros'], 1000000.0);
      expect(Hive.box<Add_data>('data').length, 0);
      await cleanupWidgetTree(tester);
    });

    testWidgets('eliminar transferencia revierte ambos lados una sola vez', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 12, 0);
      await tester.runAsync(() async {
        await TransactionService.processTransaction(
          type: 'Transfer',
          amount: 300000,
          accountName: 'Ahorros',
          destinationAccount: 'Nequi',
        );
        await Hive.box<Add_data>('data').add(Add_data(
          'Transfer',
          '300000',
          date,
          'Transferencia',
          'Ahorros > Nequi',
          'Ahorros',
          Icons.sync_alt.codePoint,
        ));
      });

      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: Hive.box<Add_data>('data').values.toList(),
        dailyIncome: 0,
        dailyExpense: 0,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.textContaining('Ahorros > Nequi').first,
      );

      final balances = await readAccountBalances();
      expect(balances['Ahorros'], 1000000.0);
      expect(balances['Nequi'], 500000.0);
      expect(Hive.box<Add_data>('data').length, 0);
      await cleanupWidgetTree(tester);
    });

    testWidgets('con dos transacciones idénticas elimina solo la seleccionada por key persistida', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 14, 0);
      late dynamic firstKey;
      late dynamic secondKey;
      await tester.runAsync(() async {
        await TransactionService.processTransaction(
          type: 'Expenses',
          amount: 50000,
          accountName: 'Ahorros',
        );
        await TransactionService.processTransaction(
          type: 'Expenses',
          amount: 50000,
          accountName: 'Ahorros',
        );
        final box = Hive.box<Add_data>('data');
        firstKey = await box.add(Add_data(
          'Expenses',
          '50000',
          date,
          'Duplicado',
          'Café',
          'Ahorros',
          Icons.local_cafe.codePoint,
        ));
        secondKey = await box.add(Add_data(
          'Expenses',
          '50000',
          date,
          'Duplicado',
          'Café',
          'Ahorros',
          Icons.local_cafe.codePoint,
        ));
      });

      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: Hive.box<Add_data>('data').values.toList(),
        dailyIncome: 0,
        dailyExpense: 100000,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.text('Café - Duplicado').at(1),
      );

      final box = Hive.box<Add_data>('data');
      expect(box.length, 1);
      expect(box.containsKey(firstKey), isTrue);
      expect(box.containsKey(secondKey), isFalse);

      final balances = await readAccountBalances();
      expect(balances['Ahorros'], 950000.0);
      await cleanupWidgetTree(tester);
    });

    testWidgets('eliminar compra con tarjeta en cuotas revierte deuda y cupo de TC', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 15, 0);
      await tester.runAsync(() async {
        await Hive.box<Responsibility>('responsibilities').add(Responsibility(
          id: 'visa_id',
          name: 'Visa',
          amount: 0,
          dueDay: 5,
          category: 'tarjeta',
          frequency: 'mensual',
          cardBalance: 0,
        ));
        await TransactionService.processTransaction(
          type: 'Expenses',
          amount: 600000,
          accountName: 'Visa',
          installments: 3,
          isInterestFree: true,
          transactionDate: date,
        );
        await Hive.box<Add_data>('data').add(Add_data(
          'Expenses',
          '600000',
          date,
          'Electrodoméstico',
          'Compras',
          'Visa',
          Icons.shopping_bag.codePoint,
          '3',
          true,
        ));
      });

      expect(CreditCardCalculator.calculateTotalDebt('Visa'), 600000.0);

      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: Hive.box<Add_data>('data').values.toList(),
        dailyIncome: 0,
        dailyExpense: 600000,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.text('Compras - Electrodoméstico'),
      );

      final balances = await readAccountBalances();
      expect(balances['Visa'], 2000000.0);
      expect(CreditCardCalculator.calculateTotalDebt('Visa'), 0.0);
      expect(CreditCardCalculator.calculateMonthlyPayment('Visa', date.month, date.year), 0.0);
      final resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
      expect(resp.cardBalance, 0.0);
      expect(resp.installmentPlans, isEmpty);
      expect(Hive.box<Add_data>('data').length, 0);
      await cleanupWidgetTree(tester);
    });

    testWidgets('segundo intento sobre transacción ya eliminada no produce doble reversión', (tester) async {
      setMobileViewport(tester);
      final date = DateTime(2026, 5, 10, 16, 0);
      late Add_data tx;
      await tester.runAsync(() async {
        await TransactionService.processTransaction(
          type: 'Expenses',
          amount: 80000,
          accountName: 'Ahorros',
        );
        tx = Add_data(
          'Expenses',
          '80000',
          date,
          'Transporte',
          'Movilidad',
          'Ahorros',
          Icons.directions_bus.codePoint,
        );
        await Hive.box<Add_data>('data').add(tx);
      });

      await tester.pumpWidget(wrapWithApp(DailyTransactionsScreen(
        dateString: '10/05/2026',
        transactions: Hive.box<Add_data>('data').values.toList(),
        dailyIncome: 0,
        dailyExpense: 80000,
      )));
      await tester.pumpAndSettle();

      await deleteViaDailyTransactionsUI(
        tester,
        find.text('Movilidad - Transporte'),
      );

      expect(tx.isInBox, isFalse);
      final balancesAfterFirst = await readAccountBalances();
      expect(balancesAfterFirst['Ahorros'], 1000000.0);
      await cleanupWidgetTree(tester);
    });
  });
}
