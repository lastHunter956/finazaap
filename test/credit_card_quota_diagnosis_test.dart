import 'dart:io';

import 'package:finazaap/data/credit_card_calculator.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Box<Add_data> dataBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_cc_diag_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    dataBox = await Hive.openBox<Add_data>('data');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await dataBox.clear();
    SharedPreferences.setMockInitialValues({'default_currency': 'COP'});
    await CurrencyHelper.loadCurrency();
  });

  test(
      'Diagnóstico cuota en cero: compra post-corte (día 15 con corte día 5) inicia cobro el mes siguiente según regla existente',
      () async {
    const cardName = 'TarjetaAuditPostCorte';
    await dataBox.add(
      Add_data(
        'Expenses',
        '60000',
        DateTime(2026, 11, 15),
        'CompraTC',
        'Compras',
        cardName,
        0,
        '3',
        true,
      ),
    );

    expect(CreditCardCalculator.calculateTotalDebt(cardName), 60000.0);

    // En noviembre 2026 (mes de la compra post-corte), la cuota exigible es 0.0
    expect(
      CreditCardCalculator.calculateMonthlyPayment(
        cardName,
        11,
        2026,
        cutoffDay: 5,
      ),
      0.0,
    );

    // En diciembre 2026 comienza la primera de las 3 cuotas (20.000)
    expect(
      CreditCardCalculator.calculateMonthlyPayment(
        cardName,
        12,
        2026,
        cutoffDay: 5,
      ),
      closeTo(20000.0, 0.01),
    );
  });

  test(
      'Diagnóstico cuota activa: compra pre-corte (día 4 con corte día 5) cobra primera cuota en el mismo mes',
      () async {
    const cardName = 'TarjetaAuditPreCorte';
    await dataBox.add(
      Add_data(
        'Expenses',
        '60000',
        DateTime(2026, 11, 4),
        'CompraTCPreCorte',
        'Compras',
        cardName,
        0,
        '3',
        true,
      ),
    );

    expect(
      CreditCardCalculator.calculateMonthlyPayment(
        cardName,
        11,
        2026,
        cutoffDay: 5,
      ),
      closeTo(20000.0, 0.01),
    );
  });

  test('formatWithCodeIfAmbiguous añade código ISO en símbolos ambiguos como \$',
      () async {
    final cop = CurrencyHelper.formatWithCodeIfAmbiguous(50000, 'COP');
    final usd = CurrencyHelper.formatWithCodeIfAmbiguous(50, 'USD');
    final eurFromCop = CurrencyHelper.formatWithCodeIfAmbiguous(50, 'EUR');

    expect(cop, endsWith(' COP'));
    expect(usd, endsWith(' USD'));
    expect(eurFromCop, endsWith(' EUR'));

    SharedPreferences.setMockInitialValues({'default_currency': 'EUR'});
    await CurrencyHelper.loadCurrency();
    final eurNative = CurrencyHelper.formatWithCodeIfAmbiguous(50, 'EUR');
    expect(eurNative.endsWith(' EUR'), isFalse);
  });
}
