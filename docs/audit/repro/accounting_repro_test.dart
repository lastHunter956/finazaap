import 'dart:convert';
import 'dart:io';

import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/credit_card_calculator.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Suite de reproducción aislada (Ola 0 - T0.1).
///
/// IMPORTANTE:
/// - Invoca directamente al código productivo real (sin duplicar lógica).
/// - Usa almacenamiento temporal aislado (`Directory.systemTemp` + `SharedPreferences.setMockInitialValues`).
/// - Se mantiene temporalmente en `docs/audit/repro/` (fuera de `test/`) para no contaminar
///   el baseline aprobado mientras los defectos sigan abiertos.
/// - Cada prueba afirma el comportamiento contable esperado; si el defecto existe, falla.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t0_1_');
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

  test('L1.3a esperado: available_balance excluye cuenta con includeInTotal=false', () async {
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
    // Solo Ahorros (1.000.000 - 100.000 = 900.000) debe sumarse; Reserva tiene includeInTotal=false.
    expect(prefs.getDouble('available_balance'), closeTo(900000.0, 0.01));
  });

  test('L1.3b esperado: available_balance excluye cupo de Tarjeta de Crédito', () async {
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
    // El cupo de deuda de una Tarjeta de Crédito (10.000.000) no es dinero líquido disponible.
    expect(prefs.getDouble('available_balance'), closeTo(900000.0, 0.01));
  });

  test('L1.3c esperado (combinado): available_balance excluye includeInTotal=false y cupo TC', () async {
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

  test('L1.4 esperado: eliminar transferencia hacia TC revierte cardBalance y paidAmountThisMonth', () async {
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

  test('L2.4 esperado: cuota mensual es 0.0 si la deuda total de la TC ya fue saldada', () async {
    // Campos de Add_data en Hive:
    // - IN ('Expenses'): compra con tarjeta en cuotas.
    // - amount ('1200000'): capital total de la compra.
    // - installments ('12'): número de cuotas mensuales (100.000/mes).
    // - isInterestFree (true): sin intereses, para aislar el cálculo de capital.
    // - Transfer ('Ahorros > Visa', '1200000'): pago total de la deuda antes del mes siguiente.
    // Por qué el esperado es 0.0: si calculateTotalDebt('Visa') == 0.0 (no queda capital adeudado),
    // cobrar 100.000 mensuales durante los 11 meses restantes exige pagar una deuda inexistente.
    final dataBox = Hive.box<Add_data>('data');
    await dataBox.add(Add_data(
      'Expenses',
      '1200000',
      DateTime(2026, 10, 5),
      'Portátil',
      'Compras',
      'Visa',
      0,
      '12',
      true,
    ));
    await dataBox.add(Add_data(
      'Transfer',
      '1200000',
      DateTime(2026, 10, 20),
      'Pago total',
      'Ahorros > Visa',
      '',
    ));

    final debt = CreditCardCalculator.calculateTotalDebt('Visa');
    expect(debt, closeTo(0.0, 0.01));

    final quotaNextMonth = CreditCardCalculator.calculateMonthlyPayment('Visa', 11, 2026);
    expect(quotaNextMonth, closeTo(0.0, 0.01));
  });

  test('L2.5 esperado: getDynamicQuota es 0.0 cuando la deuda de la TC es 0', () async {
    // Campos de Responsibility:
    // - category ('tarjeta'): obligación dinámica calculada desde Hive ('data').
    // - minimumPayment (50000): cuota mínima configurada cuando existe deuda pendiente.
    // - Al no haber compras en 'data', calculateTotalDebt('Visa') == 0.0 (sin deuda).
    // Por qué el esperado es 0.0: sin saldo adeudado no debe proyectarse pago mínimo mensual.
    final resp = Responsibility(
      id: 'visa_min',
      name: 'Visa',
      category: 'tarjeta',
      frequency: 'mensual',
      minimumPayment: 50000,
    );
    expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(0.0, 0.01));
    expect(resp.getDynamicQuota(11, 2026), closeTo(0.0, 0.01));
  });

  test('L3.2 escenario probado: togglePaidStatus persiste isPaid=true en Hive', () async {
    final respBox = Hive.box<Responsibility>('responsibilities');
    await respBox.add(Responsibility(
      id: 'internet_id',
      name: 'Internet',
      amount: 100000,
      dueDay: 15,
      category: 'servicio',
      frequency: 'mensual',
      isPaid: false,
    ));

    await ResponsibilityService.togglePaidStatus('internet_id');
    final updated = respBox.getAt(0)!;
    expect(updated.isPaid, isTrue);
  });

  test('L1.10 esperado: cleanAmountString en CLP interpreta miles con punto (10.000 -> 10000)', () async {
    final prefs = await PrefsManager.instance;
    await prefs.setString('default_currency', 'CLP');
    await CurrencyHelper.loadCurrency();
    final cleaned = CurrencyHelper.cleanAmountString('10.000');
    expect(double.parse(cleaned), closeTo(10000.0, 0.01));
  });
}
