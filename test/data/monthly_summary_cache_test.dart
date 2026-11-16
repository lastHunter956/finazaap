import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/monthly_summary_cache.dart';

void main() {
  late Directory tempDir;
  late Box<Add_data> box;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_cache_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    box = await Hive.openBox<Add_data>('data_cache_test');
  });

  setUp(() async {
    await box.clear();
  });

  tearDownAll(() async {
    if (box.isOpen) {
      await box.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('MonthlySummaryCache - Hive integration', () {
    test('retorna resumen vacío cuando la caja no tiene transacciones', () {
      final cache = MonthlySummaryCache(box: box);
      addTearDown(cache.dispose);

      final summary = cache.getMonthSummary(2026, 11);
      expect(summary.key, '2026-11');
      expect(summary.totalIncome, 0.0);
      expect(summary.totalExpenses, 0.0);
      expect(summary.netSavings, 0.0);
      expect(summary.transactionCount, 0);
      expect(summary.expensesByCategory, isEmpty);
      expect(cache.getAvailableYears(), isEmpty);
      expect(cache.getTransactionsForMonth(2026, 11), isEmpty);
    });

    test('indexa por YYYY-MM ingresos, gastos, transferencias, categorías y cuentas', () async {
      await box.addAll([
        Add_data('Income', '2000', DateTime(2026, 10, 5), 'Nómina', 'Salario', 'Banco A', 10),
        Add_data('Expenses', '350.5', DateTime(2026, 10, 12), 'Mercado', 'Comida', 'Tarjeta B', 20),
        Add_data('Expenses', '149.5', DateTime(2026, 10, 20), 'Cena', 'Comida', 'Efectivo', 20),
        Add_data('Transfer', '500', DateTime(2026, 10, 25), 'Ahorro', 'Banco A > Banco C', 'Banco A', 30),
        Add_data('Income', '100', DateTime(2026, 11, 1), 'Reembolso', 'Otros', 'Banco A', 11),
      ]);

      final cache = MonthlySummaryCache(box: box);
      addTearDown(cache.dispose);

      final oct = cache.getMonthSummary(2026, 10);
      expect(oct.key, '2026-10');
      expect(oct.totalIncome, closeTo(2000.0, 0.001));
      expect(oct.totalExpenses, closeTo(500.0, 0.001));
      expect(oct.netSavings, closeTo(1500.0, 0.001));
      expect(oct.transactionCount, 4);
      expect(oct.expensesByCategory['Comida'], closeTo(500.0, 0.001));
      expect(oct.incomeByCategory['Salario'], closeTo(2000.0, 0.001));
      expect(oct.expensesByAccount['Tarjeta B'], closeTo(350.5, 0.001));
      expect(oct.expensesByAccount['Efectivo'], closeTo(149.5, 0.001));
      expect(oct.incomeByAccount['Banco A'], closeTo(2000.0, 0.001));

      expect(cache.getTransactionsForMonth(2026, 10).length, 4);
      expect(cache.getTransactionsForMonth(2026, 10, typeFilter: 'Income').length, 1);
      expect(cache.getTransactionsForMonth(2026, 10, typeFilter: 'Expenses').length, 2);

      expect(cache.getAvailableYears(), [2026]);
      expect(cache.getAvailableMonthsForYear(2026), {10, 11});
    });

    test('se invalida automáticamente al agregar, editar o eliminar en Hive', () async {
      final cache = MonthlySummaryCache(box: box);
      addTearDown(cache.dispose);

      expect(cache.getMonthSummary(2026, 11).totalExpenses, 0.0);
      final rev0 = cache.revision;

      await box.add(Add_data('Expenses', '120', DateTime(2026, 11, 2), 'Café', 'Comida', 'Efectivo'));
      // Dar tiempo al microtask/listener de Hive si aplica
      await Future<void>.delayed(Duration.zero);

      expect(cache.getMonthSummary(2026, 11).totalExpenses, 120.0);
      final rev1 = cache.revision;
      expect(rev1, greaterThan(rev0));

      await box.putAt(0, Add_data('Expenses', '220', DateTime(2026, 11, 2), 'Café+', 'Comida', 'Efectivo'));
      await Future<void>.delayed(Duration.zero);

      expect(cache.getMonthSummary(2026, 11).totalExpenses, 220.0);
      expect(cache.revision, greaterThan(rev1));

      await box.deleteAt(0);
      await Future<void>.delayed(Duration.zero);

      expect(cache.getMonthSummary(2026, 11).totalExpenses, 0.0);
    });

    test('getRecentDaysSummary calcula ventana temporal cruzando cambio de mes', () async {
      await box.addAll([
        Add_data('Expenses', '50', DateTime(2026, 10, 29, 10, 0), 'Bus', 'Transporte', 'Efectivo'),
        Add_data('Expenses', '80', DateTime(2026, 11, 1, 12, 0), 'Almuerzo', 'Comida', 'Efectivo'),
        Add_data('Income', '300', DateTime(2026, 11, 2, 9, 0), 'Freelance', 'Trabajo', 'Banco A'),
        Add_data('Expenses', '999', DateTime(2026, 10, 15, 9, 0), 'Antiguo', 'Otros', 'Banco A'),
      ]);

      final cache = MonthlySummaryCache(box: box);
      addTearDown(cache.dispose);

      final recent = cache.getRecentDaysSummary(
        7,
        referenceDate: DateTime(2026, 11, 2, 18, 0),
      );

      expect(recent.totalIncome, closeTo(300.0, 0.001));
      expect(recent.totalExpenses, closeTo(130.0, 0.001));
      expect(recent.netSavings, closeTo(170.0, 0.001));
      expect(recent.transactionCount, 3);
      expect(recent.expensesByCategory['Transporte'], 50.0);
      expect(recent.expensesByCategory['Comida'], 80.0);
    });
  });

  group('MonthlySummaryCache - Benchmark sintético 5.000+ transacciones', () {
    test('5.500 transacciones: equivalencia exacta y lectura O(1) vs escaneo lineal', () {
      const totalItems = 5500;
      final transactions = List<Add_data>.generate(totalItems, (i) {
        final year = 2022 + (i % 5); // 2022..2026
        final month = (i % 12) + 1;
        final day = (i % 28) + 1;
        final isIncome = i % 4 == 0;
        final isTransfer = i % 15 == 0 && !isIncome;
        final type = isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'Expenses');
        final amount = ((i % 200) + 10).toString();
        final category = isIncome ? 'Salario' : 'Cat_${i % 8}';
        final account = 'Cuenta_${i % 4}';
        return Add_data(type, amount, DateTime(year, month, day), 'Det $i', category, account);
      });

      final cache = MonthlySummaryCache.fromTransactions(transactions);

      // Calentamiento (construye índice en una sola pasada O(N))
      final initialSummary = cache.getMonthSummary(2026, 11);
      expect(cache.totalTransactionCount, totalItems);

      // Verificación de exactitud contra escaneo lineal para 2026-11
      double expectedIncome = 0.0;
      double expectedExpenses = 0.0;
      int expectedCount = 0;
      for (final item in transactions) {
        if (item.safeDate.year == 2026 && item.safeDate.month == 11) {
          expectedCount++;
          final amt = double.tryParse(item.safeAmount) ?? 0.0;
          if (item.safeType == 'Income') expectedIncome += amt;
          if (item.safeType == 'Expenses') expectedExpenses += amt;
        }
      }
      expect(initialSummary.totalIncome, closeTo(expectedIncome, 0.001));
      expect(initialSummary.totalExpenses, closeTo(expectedExpenses, 0.001));
      expect(initialSummary.netSavings, closeTo(expectedIncome - expectedExpenses, 0.001));
      expect(initialSummary.transactionCount, expectedCount);

      // Medición sintética en memoria: 1.000 consultas O(1) vs 1.000 escaneos lineales O(N)
      const queries = 1000;
      final swCache = Stopwatch()..start();
      double cacheAcc = 0.0;
      for (int q = 0; q < queries; q++) {
        final m = (q % 12) + 1;
        final s = cache.getMonthSummary(2026, m);
        cacheAcc += s.netSavings;
      }
      swCache.stop();

      final swLinear = Stopwatch()..start();
      double linearAcc = 0.0;
      for (int q = 0; q < queries; q++) {
        final m = (q % 12) + 1;
        double inc = 0.0;
        double exp = 0.0;
        for (final item in transactions) {
          if (item.safeDate.year == 2026 && item.safeDate.month == m) {
            final amt = double.tryParse(item.safeAmount) ?? 0.0;
            if (item.safeType == 'Income') inc += amt;
            if (item.safeType == 'Expenses') exp += amt;
          }
        }
        linearAcc += (inc - exp);
      }
      swLinear.stop();

      expect(cacheAcc, closeTo(linearAcc, 0.01));
      // Las 1.000 lecturas O(1) deben ser claramente más rápidas que 1.000 escaneos lineales
      expect(swCache.elapsedMicroseconds, lessThan(swLinear.elapsedMicroseconds));
    });
  });
}
