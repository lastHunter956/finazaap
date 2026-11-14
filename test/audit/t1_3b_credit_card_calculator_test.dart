import 'dart:io';

import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/credit_card_calculator.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_3b_');
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

  test('L2.4: cuota mensual es 0.0 si la deuda total de la TC ya fue saldada', () async {
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

  test('L2.5: getDynamicQuota y getAmountForDate son 0.0 cuando la deuda de la TC es 0', () async {
    final resp = Responsibility(
      id: 'visa_min',
      name: 'Visa',
      category: 'tarjeta',
      frequency: 'mensual',
      minimumPayment: 50000,
    );
    expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(0.0, 0.01));
    expect(resp.getDynamicQuota(11, 2026), closeTo(0.0, 0.01));
    expect(resp.getAmountForDate(11, 2026), closeTo(0.0, 0.01));
  });

  test('Regresión: deuda impaga con intereses conserva cuota amortizada > 0', () async {
    final dataBox = Hive.box<Add_data>('data');
    await dataBox.add(Add_data(
      'Expenses',
      '1200000',
      DateTime(2026, 10, 5),
      'Televisor',
      'Compras',
      'Visa',
      0,
      '12',
      false,
    ));

    final debt = CreditCardCalculator.calculateTotalDebt('Visa');
    expect(debt, closeTo(1200000.0, 0.01));

    final quota = CreditCardCalculator.calculateMonthlyPayment('Visa', 11, 2026, interestRate: 2.5);
    expect(quota, greaterThan(100000.0));
  });

  test('Regresión: deuda impaga con minimumPayment conserva minimumPayment', () async {
    final dataBox = Hive.box<Add_data>('data');
    await dataBox.add(Add_data(
      'Expenses',
      '300000',
      DateTime(2026, 10, 5),
      'Compra',
      'Compras',
      'Visa',
      0,
      '3',
      true,
    ));

    final resp = Responsibility(
      id: 'visa_min_active',
      name: 'Visa',
      category: 'tarjeta',
      frequency: 'mensual',
      minimumPayment: 50000,
    );
    expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(300000.0, 0.01));
    expect(resp.getDynamicQuota(11, 2026), closeTo(50000.0, 0.01));
    expect(resp.getAmountForDate(11, 2026), closeTo(50000.0, 0.01));
  });
}
