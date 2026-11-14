import 'dart:convert';
import 'dart:io';

import 'package:finazaap/Screens/responsibilities_screen.dart';
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
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_3c_');
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
          'balance': '2000000.0',
          'icon': Icons.credit_card.codePoint,
          'iconColor': Colors.purple.value,
          'includeInTotal': false,
          'creditLimit': 2000000.0,
        }),
      ],
      'available_balance': 1000000.0,
      'default_currency': 'COP',
    });
    await PrefsManager.init();
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

  Future<void> seedVisaResponsibility({double debt = 0.0, double monthly = 0.0}) async {
    final respBox = Hive.box<Responsibility>('responsibilities');
    await respBox.add(Responsibility(
      id: 'visa_id',
      name: 'Visa',
      amount: monthly,
      dueDay: 25,
      category: 'tarjeta',
      frequency: 'mensual',
      cardLimit: 2000000.0,
      cardBalance: debt,
    ));
  }

  test('L2.1a: compra con TC crea deuda y plan de cuotas una sola vez', () async {
    await seedVisaResponsibility();
    final txDate = DateTime(2026, 11, 5);

    final ok = await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 300000.0,
      accountName: 'Visa',
      isNewTransaction: true,
      installments: 3,
      isInterestFree: true,
      transactionDate: txDate,
    );
    expect(ok, isTrue);

    final resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(300000.0, 0.01));
    expect(resp.installmentPlansJson?.length ?? 0, 1);
    expect(resp.safeAmount, closeTo(100000.0, 0.01));

    final prefs = await PrefsManager.instance;
    expect(prefs.getDouble('available_balance'), closeTo(1000000.0, 0.01));
  });

  test('L2.1 edit: editar compra con TC revierte plan anterior y aplica el nuevo sin duplicar', () async {
    await seedVisaResponsibility();
    final txDate = DateTime(2026, 11, 5);

    await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 300000.0,
      accountName: 'Visa',
      isNewTransaction: true,
      installments: 3,
      isInterestFree: true,
      transactionDate: txDate,
    );
    final oldTx = Add_data('Expenses', '300000', txDate, 'Compra', 'Compras', 'Visa', 0, '3', true);
    await Hive.box<Add_data>('data').add(oldTx);

    final edited = await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 200000.0,
      accountName: 'Visa',
      isNewTransaction: false,
      oldTransaction: oldTx,
      installments: 2,
      isInterestFree: true,
      transactionDate: txDate,
    );
    expect(edited, isTrue);

    final resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(200000.0, 0.01));
    expect(resp.installmentPlansJson?.length ?? 0, 1);
    expect(resp.safeAmount, closeTo(100000.0, 0.01));
  });

  test('L2.1b delete: eliminar compra con TC revierte deuda, plan de cuotas y mensualidad', () async {
    await seedVisaResponsibility();
    final txDate = DateTime(2026, 11, 5);

    await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 300000.0,
      accountName: 'Visa',
      isNewTransaction: true,
      installments: 3,
      isInterestFree: true,
      transactionDate: txDate,
    );
    final tx = Add_data('Expenses', '300000', txDate, 'Compra', 'Compras', 'Visa', 0, '3', true);
    await Hive.box<Add_data>('data').add(tx);

    final deleted = await TransactionService.deleteTransaction(tx);
    expect(deleted, isTrue);

    final resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(0.0, 0.01));
    expect(resp.installmentPlansJson ?? [], isEmpty);
    expect(resp.safeAmount, closeTo(0.0, 0.01));
  });

  test('Transferencia DESDE tarjeta vs pago HACIA tarjeta y equivalencia pago directo', () async {
    await seedVisaResponsibility();

    // Avance desde tarjeta Visa hacia Ahorros (+200k deuda Visa, +200k Ahorros)
    final advanceOk = await TransactionService.processTransaction(
      type: 'Transfer',
      amount: 200000.0,
      accountName: 'Visa',
      destinationAccount: 'Ahorros',
      isNewTransaction: true,
    );
    expect(advanceOk, isTrue);

    var resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(200000.0, 0.01));
    final prefs = await PrefsManager.instance;
    expect(prefs.getDouble('available_balance'), closeTo(1200000.0, 0.01));

    // Pago HACIA tarjeta desde Ahorros (-200k deuda Visa, -200k Ahorros)
    final payOk = await TransactionService.processTransaction(
      type: 'Transfer',
      amount: 200000.0,
      accountName: 'Ahorros',
      destinationAccount: 'Visa',
      isNewTransaction: true,
    );
    expect(payOk, isTrue);

    resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(0.0, 0.01));
    expect(prefs.getDouble('available_balance'), closeTo(1000000.0, 0.01));

    // Equivalencia: pago directo (Income en tarjeta) también reduce cardBalance sin sumar al available_balance
    await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 150000.0,
      accountName: 'Visa',
      isNewTransaction: true,
    );
    await TransactionService.processTransaction(
      type: 'Income',
      amount: 150000.0,
      accountName: 'Visa',
      isNewTransaction: true,
    );
    resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(0.0, 0.01));
    expect(prefs.getDouble('available_balance'), closeTo(1000000.0, 0.01));
  });

  testWidgets('L3.1: pagar tarjeta desde ResponsibilitiesScreen registra Transfer y reduce deuda', (tester) async {
    await tester.runAsync(() async {
      await seedVisaResponsibility(debt: 300000.0, monthly: 300000.0);
      final dataBox = Hive.box<Add_data>('data');
      await dataBox.add(Add_data(
        'Expenses',
        '300000',
        DateTime(2026, 11, 5),
        'Compra',
        'Compras',
        'Visa',
        0,
        '1',
        true,
      ));
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [AppTheme.forMode(AppThemeMode.defaultDark)],
        ),
        home: const ResponsibilitiesScreen(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Visa').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pagar Cuota'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Confirmar'));
    await tester.tap(find.text('Confirmar'));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    final dataBox = Hive.box<Add_data>('data');
    final transfersToVisa = dataBox.values.where(
      (tx) => tx.safeType == 'Transfer' && tx.safeCategory.contains('> Visa'),
    );
    expect(transfersToVisa.length, 1);
    expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(0.0, 0.01));

    final resp = Hive.box<Responsibility>('responsibilities').values.firstWhere((r) => r.safeName == 'Visa');
    expect(resp.cardBalance, closeTo(0.0, 0.01));

    final prefs = await PrefsManager.instance;
    expect(prefs.getDouble('available_balance'), closeTo(700000.0, 0.01));

    // Desmontar widget antes de tearDownAll para liberar listeners de Hive y timers de AlertHelper
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
