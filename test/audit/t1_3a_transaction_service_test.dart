import 'dart:convert';
import 'dart:io';

import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_3a_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsManager.init();

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
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('L1.3a: available_balance excluye cuenta con includeInTotal=false', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setStringList('accounts', [
      json.encode({
        'title': 'Ahorros',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '1000000',
        'includeInTotal': true,
      }),
      json.encode({
        'title': 'Reserva',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '5000000',
        'includeInTotal': false,
      }),
    ]);

    final ok = await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 100000,
      accountName: 'Ahorros',
      isNewTransaction: true,
      recordInHive: false,
    );
    expect(ok, isTrue);
    expect(prefs.getDouble('available_balance'), closeTo(900000.0, 0.01));
  });

  test('L1.3b: available_balance excluye cupo de Tarjeta de Crédito', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setStringList('accounts', [
      json.encode({
        'title': 'Ahorros',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '1000000',
        'includeInTotal': true,
      }),
      json.encode({
        'title': 'Visa',
        'subtitle': 'Tarjeta de Crédito',
        'balance': '10000000',
        'creditLimit': '10000000',
        'includeInTotal': true,
      }),
    ]);

    final ok = await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 100000,
      accountName: 'Ahorros',
      isNewTransaction: true,
      recordInHive: false,
    );
    expect(ok, isTrue);
    expect(prefs.getDouble('available_balance'), closeTo(900000.0, 0.01));
  });

  test('L1.3c (combinado): available_balance excluye includeInTotal=false y cupo TC', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setStringList('accounts', [
      json.encode({
        'title': 'Ahorros',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '1000000',
        'includeInTotal': true,
      }),
      json.encode({
        'title': 'Reserva',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '5000000',
        'includeInTotal': false,
      }),
      json.encode({
        'title': 'Visa',
        'subtitle': 'Tarjeta de Crédito',
        'balance': '10000000',
        'creditLimit': '10000000',
        'includeInTotal': true,
      }),
    ]);

    final ok = await TransactionService.processTransaction(
      type: 'Expenses',
      amount: 100000,
      accountName: 'Ahorros',
      isNewTransaction: true,
      recordInHive: false,
    );
    expect(ok, isTrue);
    expect(prefs.getDouble('available_balance'), closeTo(900000.0, 0.01));
  });

  test('L1.4: eliminar transferencia hacia TC revierte cardBalance y paidAmountThisMonth', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setStringList('accounts', [
      json.encode({
        'title': 'Ahorros',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '1000000',
        'includeInTotal': true,
      }),
      json.encode({
        'title': 'Visa',
        'subtitle': 'Tarjeta de Crédito',
        'balance': '4500000',
        'creditLimit': '5000000',
        'includeInTotal': false,
      }),
    ]);

    final respBox = Hive.box<Responsibility>('responsibilities');
    await respBox.add(Responsibility(
      id: 'visa_id',
      name: 'Visa',
      category: 'tarjeta',
      frequency: 'mensual',
      cardLimit: 5000000,
      cardBalance: 500000,
      paidAmountThisMonth: 0,
      isPaid: false,
    ));

    final now = DateTime(2026, 11, 10);
    final ok = await TransactionService.processTransaction(
      type: 'Transfer',
      amount: 200000,
      accountName: 'Ahorros',
      destinationAccount: 'Visa',
      isNewTransaction: true,
      recordInHive: false,
      targetMonth: now.month,
      targetYear: now.year,
    );
    expect(ok, isTrue);

    final dataBox = Hive.box<Add_data>('data');
    final tx = Add_data('Transfer', '200000', now, 'Pago Visa', 'Ahorros > Visa', '');
    await dataBox.add(tx);

    final deleted = await TransactionService.deleteTransaction(tx);
    expect(deleted, isTrue);

    final respAfter = respBox.getAt(0)!;
    expect(respAfter.cardBalance, closeTo(500000.0, 0.01));
    expect(respAfter.paidAmountThisMonth ?? 0.0, closeTo(0.0, 0.01));
  });

  test('Regresión normal: cuentas incluidas y transferencia entre cuentas líquidas', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setStringList('accounts', [
      json.encode({
        'title': 'Ahorros',
        'subtitle': 'Cuenta de Ahorros',
        'balance': '1000000',
        'includeInTotal': true,
      }),
      json.encode({
        'title': 'Nequi',
        'subtitle': 'Billetera Digital',
        'balance': '500000',
        'includeInTotal': true,
      }),
    ]);

    final now = DateTime(2026, 11, 10);
    final ok = await TransactionService.processTransaction(
      type: 'Transfer',
      amount: 300000,
      accountName: 'Ahorros',
      destinationAccount: 'Nequi',
      isNewTransaction: true,
      recordInHive: false,
      targetMonth: now.month,
      targetYear: now.year,
    );
    expect(ok, isTrue);
    expect(prefs.getDouble('available_balance'), closeTo(1500000.0, 0.01));

    final dataBox = Hive.box<Add_data>('data');
    final tx = Add_data('Transfer', '300000', now, 'Envío', 'Ahorros > Nequi', '');
    await dataBox.add(tx);

    final deleted = await TransactionService.deleteTransaction(tx);
    expect(deleted, isTrue);

    final decoded = prefs
        .getStringList('accounts')!
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList();
    expect(double.parse(decoded[0]['balance'].toString()), closeTo(1000000.0, 0.01));
    expect(double.parse(decoded[1]['balance'].toString()), closeTo(500000.0, 0.01));
    expect(prefs.getDouble('available_balance'), closeTo(1500000.0, 0.01));
  });
}
