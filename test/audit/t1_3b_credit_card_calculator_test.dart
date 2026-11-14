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

  group('Semántica financiera CreditCardCalculator y períodos', () {
    test('Mínimo cubierto con deuda total aún pendiente', () async {
      final dataBox = Hive.box<Add_data>('data');
      await dataBox.add(Add_data('Expenses', '600000', DateTime(2026, 11, 5), 'Compra', 'Compras', 'Visa', 0, '6', true));
      final respBox = Hive.box<Responsibility>('responsibilities');
      await respBox.add(Responsibility(
        id: 'visa_min_pending',
        name: 'Visa',
        category: 'tarjeta',
        frequency: 'mensual',
        minimumPayment: 50000.0,
        cardBalance: 600000.0,
      ));

      await dataBox.add(Add_data('Transfer', '50000', DateTime(2026, 11, 10), 'Pago mínimo', 'Ahorros > Visa', ''));
      await ResponsibilityService.registerPayment('visa_min_pending', 50000.0, DateTime(2026, 11, 10), false);

      final updated = respBox.values.firstWhere((r) => r.safeId == 'visa_min_pending');
      expect(updated.isPaid, isTrue);
      expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(550000.0, 0.01));
    });

    test('Período cubierto con cuotas futuras pendientes', () async {
      final dataBox = Hive.box<Add_data>('data');
      await dataBox.add(Add_data('Expenses', '300000', DateTime(2026, 11, 5), 'Compra', 'Compras', 'Visa', 0, '3', true));
      await dataBox.add(Add_data('Transfer', '100000', DateTime(2026, 11, 15), 'Cuota 1', 'Ahorros > Visa', ''));

      expect(CreditCardCalculator.isMonthPaid('Visa', 11, 2026), isTrue);
      expect(CreditCardCalculator.isMonthPaid('Visa', 12, 2026), isFalse);
      expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(200000.0, 0.01));
    });

    test('Pago parcial (95%) no cubre importe exigible en Responsibility.isAmountCovered (isMonthPaid aún usa 0.95)', () async {
      final dataBox = Hive.box<Add_data>('data');
      await dataBox.add(Add_data('Expenses', '300000', DateTime(2026, 11, 5), 'Compra', 'Compras', 'Visa', 0, '3', true));
      await dataBox.add(Add_data('Transfer', '95000', DateTime(2026, 11, 15), 'Pago parcial', 'Ahorros > Visa', ''));

      final quota = CreditCardCalculator.calculateMonthlyPayment('Visa', 11, 2026);
      final paid = CreditCardCalculator.calculatePaidInMonth('Visa', 11, 2026);
      expect(quota, closeTo(100000.0, 0.01));
      expect(paid, closeTo(95000.0, 0.01));
      expect(Responsibility.isAmountCovered(paid, quota), isFalse);
      // Evidencia del umbral 0.95 aún pendiente en CreditCardCalculator.isMonthPaid:
      expect(CreditCardCalculator.isMonthPaid('Visa', 11, 2026), isTrue);
    });

    test('Consulta histórica: calculatePaidInMonth preserva el mes, pero calculateMonthlyPayment depende de deuda actual', () async {
      final dataBox = Hive.box<Add_data>('data');
      await dataBox.add(Add_data('Expenses', '300000', DateTime(2026, 10, 5), 'Compra', 'Compras', 'Visa', 0, '3', true));
      await dataBox.add(Add_data('Transfer', '100000', DateTime(2026, 10, 15), 'Cuota Oct', 'Ahorros > Visa', ''));
      await dataBox.add(Add_data('Transfer', '200000', DateTime(2026, 11, 10), 'Pago total Nov', 'Ahorros > Visa', ''));

      expect(CreditCardCalculator.calculatePaidInMonth('Visa', 10, 2026), closeTo(100000.0, 0.01));
      expect(CreditCardCalculator.calculateTotalDebt('Visa'), closeTo(0.0, 0.01));
      // Limitación documentada: al liquidarse la deuda en Nov, calculateMonthlyPayment(10, 2026) retorna 0.0
      expect(CreditCardCalculator.calculateMonthlyPayment('Visa', 10, 2026), closeTo(0.0, 0.01));
    });
  });
}
