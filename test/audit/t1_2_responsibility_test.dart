import 'dart:io';

import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync('moneo_audit_t1_2_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'COP'});
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

  group('L3.4 Regla de pagado sin 95%/98%/99% y con precisión monetaria', () {
    test('Pago parcial (98% en registerPayment y 95% en processDebtPayment) NO marca pagado', () async {
      final box = Hive.box<Responsibility>('responsibilities');
      await box.add(Responsibility(
        id: 'svc_1',
        name: 'Internet',
        amount: 100000.0,
        dueDay: 15,
        category: 'servicio',
        frequency: 'mensual',
        isPaid: false,
      ));
      await box.add(Responsibility(
        id: 'tc_1',
        name: 'Visa',
        amount: 100000.0,
        dueDay: 15,
        category: 'tarjeta',
        frequency: 'mensual',
        cardBalance: 200000.0,
        isPaid: false,
      ));

      await ResponsibilityService.registerPayment('svc_1', 98000.0, DateTime(2026, 11, 10), false);
      final svc = box.values.firstWhere((r) => r.safeId == 'svc_1');
      expect(svc.isPaid, isFalse);
      expect(svc.isPaidInMonth(11, 2026), isFalse);

      await ResponsibilityService.processDebtPayment(
        'Visa',
        95000.0,
        paymentDate: DateTime(2026, 11, 10),
        targetMonth: 11,
        targetYear: 2026,
      );
      final tc = box.values.firstWhere((r) => r.safeId == 'tc_1');
      expect(tc.lastPaymentDate, isNull);
    });

    test('Deuda cero (0 >= 0) NO se convierte en pago efectivo', () async {
      final box = Hive.box<Responsibility>('responsibilities');
      await box.add(Responsibility(
        id: 'svc_zero',
        name: 'Sin deuda',
        amount: 0.0,
        dueDay: 15,
        category: 'servicio',
        frequency: 'mensual',
        isPaid: false,
      ));

      await ResponsibilityService.registerPayment('svc_zero', 0.0, DateTime(2026, 11, 10), false);
      final svc = box.values.firstWhere((r) => r.safeId == 'svc_zero');
      expect(svc.isPaid, isFalse);
      expect(svc.lastPaymentDate, isNull);
    });

    test('Pago completo y superior al exigible a precisión de moneda (COP 2 dec / CLP 0 dec)', () async {
      final box = Hive.box<Responsibility>('responsibilities');
      await box.add(Responsibility(
        id: 'svc_cop',
        name: 'Agua',
        amount: 100000.0,
        dueDay: 15,
        category: 'servicio',
        frequency: 'mensual',
        isPaid: false,
      ));

      // 1 centavo faltante en COP (2 decimales) sigue siendo parcial
      await ResponsibilityService.registerPayment('svc_cop', 99999.99, DateTime(2026, 11, 10), false);
      var svc = box.values.firstWhere((r) => r.safeId == 'svc_cop');
      expect(svc.isPaid, isFalse);

      // Completar el centavo faltante -> pagado
      await ResponsibilityService.registerPayment('svc_cop', 0.01, DateTime(2026, 11, 11), false);
      svc = box.values.firstWhere((r) => r.safeId == 'svc_cop');
      expect(svc.isPaid, isTrue);

      // En CLP (0 decimales), pago superior al exigible también marca pagado
      SharedPreferences.setMockInitialValues({'default_currency': 'CLP'});
      await PrefsManager.init();
      await CurrencyHelper.loadCurrency();

      await box.add(Responsibility(
        id: 'svc_clp',
        name: 'Gas',
        amount: 10000.0,
        dueDay: 15,
        category: 'servicio',
        frequency: 'mensual',
        isPaid: false,
      ));
      await ResponsibilityService.registerPayment('svc_clp', 12000.0, DateTime(2026, 11, 10), false);
      final clp = box.values.firstWhere((r) => r.safeId == 'svc_clp');
      expect(clp.isPaid, isTrue);
    });
  });

  group('L3.3 Frecuencias: períodos consultados, cambio de año y febrero', () {
    test('Anual, bimestral y trimestral cubren su ciclo con cambio de año y febrero sin marcar sin-pago', () {
      final anual = Responsibility(
        id: 'anual_1',
        name: 'SOAT',
        amount: 600000.0,
        dueDay: 15,
        category: 'seguro',
        frequency: 'anual',
        isPaid: true,
        lastPaymentDate: DateTime(2025, 11, 15),
      );
      expect(anual.isPaidInMonth(11, 2025), isTrue);
      expect(anual.isPaidInMonth(1, 2026), isTrue);
      expect(anual.isPaidInMonth(2, 2026), isTrue);
      expect(anual.isPaidInMonth(10, 2026), isTrue);
      expect(anual.isPaidInMonth(11, 2026), isFalse);

      final bimestral = Responsibility(
        id: 'bim_1',
        name: 'Predial',
        amount: 200000.0,
        dueDay: 10,
        category: 'impuesto',
        frequency: 'bimestral',
        isPaid: true,
        lastPaymentDate: DateTime(2025, 12, 10),
      );
      expect(bimestral.isPaidInMonth(12, 2025), isTrue);
      expect(bimestral.isPaidInMonth(1, 2026), isTrue);
      expect(bimestral.isPaidInMonth(2, 2026), isFalse);

      final trimestral = Responsibility(
        id: 'trim_1',
        name: 'Admin',
        amount: 300000.0,
        dueDay: 10,
        category: 'hogar',
        frequency: 'trimestral',
        isPaid: true,
        lastPaymentDate: DateTime(2025, 11, 10),
      );
      expect(trimestral.isPaidInMonth(11, 2025), isTrue);
      expect(trimestral.isPaidInMonth(1, 2026), isTrue);
      expect(trimestral.isPaidInMonth(2, 2026), isFalse);

      final anualSinPago = Responsibility(
        id: 'anual_unpaid',
        name: 'Impuesto',
        amount: 500000.0,
        dueDay: 15,
        category: 'impuesto',
        frequency: 'anual',
        isPaid: false,
      );
      expect(anualSinPago.isPaidInMonth(2, 2026), isFalse);
    });

    test('Quincenal con un solo pago en febrero NO marca pagado el mes completo', () {
      final quincenal = Responsibility(
        id: 'quin_1',
        name: 'Mercado',
        amount: 100000.0,
        dueDay: 5,
        category: 'hogar',
        frequency: 'quincenal',
        isPaid: true,
        lastPaymentDate: DateTime(2026, 2, 5),
        paymentDates: [DateTime(2026, 2, 5)],
        paidAmountThisMonth: 100000.0,
        lastPaymentMonth: 2,
        lastPaymentYear: 2026,
      );
      expect(quincenal.isPaidInMonth(2, 2026), isFalse);

      final quincenalCompleto = Responsibility(
        id: 'quin_2',
        name: 'Mercado 2',
        amount: 100000.0,
        dueDay: 5,
        category: 'hogar',
        frequency: 'quincenal',
        isPaid: true,
        lastPaymentDate: DateTime(2026, 2, 20),
        paymentDates: [DateTime(2026, 2, 5), DateTime(2026, 2, 20)],
        paidAmountThisMonth: 200000.0,
        lastPaymentMonth: 2,
        lastPaymentYear: 2026,
      );
      expect(quincenalCompleto.isPaidInMonth(2, 2026), isTrue);
    });

    test('Día de vencimiento 31 en febrero no desborda a marzo', () {
      final resp = Responsibility(
        id: 'feb_31',
        name: 'Arriendo',
        amount: 800000.0,
        dueDay: 31,
        category: 'hogar',
        frequency: 'mensual',
      );
      final febDue = resp.getDueDateForMonth(2, 2026);
      expect(febDue, DateTime(2026, 2, 28));

      final leapFebDue = resp.getDueDateForMonth(2, 2024);
      expect(leapFebDue, DateTime(2024, 2, 29));
    });
  });

  group('L3.5 Renombrado de cuenta tarjeta sin duplicación', () {
    test('Renombrar cuenta tarjeta conserva id, historial de pagos y no duplica al sincronizar', () async {
      await ResponsibilityService.createFromAccount(AccountItem(
        title: 'Visa',
        balance: '2000000',
        subtitle: 'Tarjeta de Crédito',
        icon: Icons.credit_card,
        iconColor: Colors.purple,
      ));

      final box = Hive.box<Responsibility>('responsibilities');
      expect(box.length, 1);
      final originalId = box.values.first.safeId;

      await Hive.box<Add_data>('data').add(
        Add_data('Expenses', '300000', DateTime(2026, 11, 5), 'Compra', 'Compras', 'Visa', 0, '2', true),
      );
      await ResponsibilityService.processDebtIncrease('Visa', 300000.0, 2, true, DateTime(2026, 11, 5));
      await ResponsibilityService.registerPayment(originalId, 150000.0, DateTime(2026, 11, 10), false);

      final renamedAccount = AccountItem(
        title: 'Visa Oro',
        balance: '2000000',
        subtitle: 'Tarjeta de Crédito',
        icon: Icons.credit_card,
        iconColor: Colors.amber,
      );
      await ResponsibilityService.updateResponsibilityFromAccount('Visa', renamedAccount);
      await ResponsibilityService.updateResponsibilityFromAccount('Visa', renamedAccount, responsibilityId: originalId);
      // Si se intenta sincronizar nuevamente con el nombre nuevo tras renombrar, no debe duplicar
      await ResponsibilityService.createFromAccount(renamedAccount);

      expect(box.length, 1);
      final updated = box.values.first;
      expect(updated.safeId, originalId);
      expect(updated.safeName, 'Visa Oro');
      expect(updated.paidAmountThisMonth, closeTo(150000.0, 0.01));
      expect(updated.lastPaymentDate, DateTime(2026, 11, 10));
    });
  });
}
