import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/add_date.dart';

/// Resumen agregado inmutable para un mes (`YYYY-MM`), año o acumulado global.
class MonthSummary {
  final int year;
  final int month;
  final String key;
  final double totalIncome;
  final double totalExpenses;
  final double netSavings;
  final int transactionCount;
  final Map<String, double> expensesByCategory;
  final Map<String, double> incomeByCategory;
  final Map<String, double> expensesByAccount;
  final Map<String, double> incomeByAccount;
  final Map<String, int> expenseCategoryIconCodes;
  final Map<String, int> incomeCategoryIconCodes;

  const MonthSummary({
    required this.year,
    required this.month,
    required this.key,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netSavings,
    required this.transactionCount,
    required this.expensesByCategory,
    required this.incomeByCategory,
    required this.expensesByAccount,
    required this.incomeByAccount,
    required this.expenseCategoryIconCodes,
    required this.incomeCategoryIconCodes,
  });

  factory MonthSummary.empty(int year, int month, {String? key}) {
    return MonthSummary(
      year: year,
      month: month,
      key: key ?? MonthlySummaryCache.monthKey(year, month),
      totalIncome: 0.0,
      totalExpenses: 0.0,
      netSavings: 0.0,
      transactionCount: 0,
      expensesByCategory: const {},
      incomeByCategory: const {},
      expensesByAccount: const {},
      incomeByAccount: const {},
      expenseCategoryIconCodes: const {},
      incomeCategoryIconCodes: const {},
    );
  }
}

/// Resumen agregado para una ventana reciente de [days] días.
class RecentDaysSummary {
  final int days;
  final DateTime startDate;
  final DateTime endDate;
  final double totalIncome;
  final double totalExpenses;
  final double netSavings;
  final int transactionCount;
  final Map<String, double> expensesByCategory;
  final Map<String, double> incomeByCategory;

  const RecentDaysSummary({
    required this.days,
    required this.startDate,
    required this.endDate,
    required this.totalIncome,
    required this.totalExpenses,
    required this.netSavings,
    required this.transactionCount,
    required this.expensesByCategory,
    required this.incomeByCategory,
  });
}

class _MutableBucket {
  final int year;
  final int month;
  final String key;
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  int transactionCount = 0;
  final List<Add_data> allTransactions = [];
  final List<Add_data> incomeTransactions = [];
  final List<Add_data> expenseTransactions = [];
  final Map<String, double> expensesByCategory = {};
  final Map<String, double> incomeByCategory = {};
  final Map<String, double> expensesByAccount = {};
  final Map<String, double> incomeByAccount = {};
  final Map<String, int> expenseCategoryIconCodes = {};
  final Map<String, int> incomeCategoryIconCodes = {};

  _MutableBucket(this.year, this.month, this.key);

  void add(Add_data item, double amount, String type, String category, String account) {
    transactionCount++;
    allTransactions.add(item);

    if (type == 'Income') {
      totalIncome += amount;
      incomeTransactions.add(item);
      incomeByCategory[category] = (incomeByCategory[category] ?? 0.0) + amount;
      incomeByAccount[account] = (incomeByAccount[account] ?? 0.0) + amount;
      if (item.safeIconCode > 0 && !incomeCategoryIconCodes.containsKey(category)) {
        incomeCategoryIconCodes[category] = item.safeIconCode;
      }
    } else if (type == 'Expenses') {
      totalExpenses += amount;
      expenseTransactions.add(item);
      expensesByCategory[category] = (expensesByCategory[category] ?? 0.0) + amount;
      expensesByAccount[account] = (expensesByAccount[account] ?? 0.0) + amount;
      if (item.safeIconCode > 0 && !expenseCategoryIconCodes.containsKey(category)) {
        expenseCategoryIconCodes[category] = item.safeIconCode;
      }
    }
  }

  MonthSummary toSummary() {
    return MonthSummary(
      year: year,
      month: month,
      key: key,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netSavings: totalIncome - totalExpenses,
      transactionCount: transactionCount,
      expensesByCategory: Map.unmodifiable(expensesByCategory),
      incomeByCategory: Map.unmodifiable(incomeByCategory),
      expensesByAccount: Map.unmodifiable(expensesByAccount),
      incomeByAccount: Map.unmodifiable(incomeByAccount),
      expenseCategoryIconCodes: Map.unmodifiable(expenseCategoryIconCodes),
      incomeCategoryIconCodes: Map.unmodifiable(incomeCategoryIconCodes),
    );
  }
}

/// Caché en memoria O(1) de agregados mensuales, anuales y listas filtradas
/// indexadas por `YYYY-MM` sobre `Hive.box<Add_data>('data')`.
class MonthlySummaryCache {
  static final MonthlySummaryCache instance = MonthlySummaryCache._internal();

  final Box<Add_data>? _explicitBox;
  final List<Add_data>? _staticTransactions;
  final DateTime Function() _nowProvider;

  Box<Add_data>? _boundBox;
  ValueListenable<Box<Add_data>>? _boundListenable;
  VoidCallback? _boxListener;

  bool _dirty = true;
  int _revision = 0;
  int _lastBoxLength = -1;

  Map<String, MonthSummary> _monthSummaries = const {};
  Map<String, List<Add_data>> _monthAllTransactions = const {};
  Map<String, List<Add_data>> _monthIncomeTransactions = const {};
  Map<String, List<Add_data>> _monthExpenseTransactions = const {};

  Map<int, MonthSummary> _yearSummaries = const {};
  Map<int, List<Add_data>> _yearAllTransactions = const {};
  Map<int, List<Add_data>> _yearIncomeTransactions = const {};
  Map<int, List<Add_data>> _yearExpenseTransactions = const {};

  MonthSummary _allTimeSummary = MonthSummary.empty(0, 0, key: 'ALL');
  List<Add_data> _allTransactions = const [];
  List<Add_data> _allIncomeTransactions = const [];
  List<Add_data> _allExpenseTransactions = const [];

  List<int> _availableYears = const [];
  Map<int, Set<int>> _yearToMonths = const {};

  MonthlySummaryCache._internal()
      : _explicitBox = null,
        _staticTransactions = null,
        _nowProvider = DateTime.now;

  /// Crea una instancia vinculada a [box] (o a `Hive.box<Add_data>('data')` si es null).
  MonthlySummaryCache({
    Box<Add_data>? box,
    DateTime Function()? nowProvider,
  })  : _explicitBox = box,
        _staticTransactions = null,
        _nowProvider = nowProvider ?? DateTime.now;

  /// Crea una instancia en memoria sobre [transactions] (útil para pruebas/benchmarks).
  MonthlySummaryCache.fromTransactions(
    List<Add_data> transactions, {
    DateTime Function()? nowProvider,
  })  : _explicitBox = null,
        _staticTransactions = transactions,
        _nowProvider = nowProvider ?? DateTime.now;

  static String monthKey(int year, int month) =>
      '$year-${month.toString().padLeft(2, '0')}';

  int get revision {
    _ensureBuilt();
    return _revision;
  }

  int get totalTransactionCount {
    _ensureBuilt();
    return _allTransactions.length;
  }

  void invalidate() {
    _dirty = true;
  }

  void _onBoxChanged() {
    _dirty = true;
  }

  void _attachBoxIfNeeded(Box<Add_data>? targetBox) {
    if (identical(targetBox, _boundBox)) {
      if (targetBox != null && targetBox.isOpen && targetBox.length != _lastBoxLength) {
        _dirty = true;
      }
      return;
    }

    _detachBox();

    if (targetBox != null && targetBox.isOpen) {
      _boundBox = targetBox;
      _boundListenable = targetBox.listenable();
      _boxListener = _onBoxChanged;
      _boundListenable!.addListener(_boxListener!);
      _dirty = true;
    }
  }

  void _detachBox() {
    if (_boundListenable != null && _boxListener != null) {
      if (_boundBox == null || _boundBox!.isOpen) {
        _boundListenable!.removeListener(_boxListener!);
      }
    }
    _boundBox = null;
    _boundListenable = null;
    _boxListener = null;
  }

  void _ensureBuilt() {
    if (_staticTransactions != null) {
      if (_dirty) {
        _rebuildIndex(_staticTransactions!, boxLength: _staticTransactions!.length);
      }
      return;
    }

    final Box<Add_data>? targetBox = _explicitBox ??
        (Hive.isBoxOpen('data') ? Hive.box<Add_data>('data') : null);

    _attachBoxIfNeeded(targetBox);

    if (targetBox == null || !targetBox.isOpen) {
      if (_dirty) {
        _rebuildIndex(const [], boxLength: 0);
      }
      return;
    }

    if (_dirty || targetBox.length != _lastBoxLength) {
      _rebuildIndex(targetBox.values, boxLength: targetBox.length);
    }
  }

  void _rebuildIndex(Iterable<Add_data> items, {required int boxLength}) {
    final Map<String, _MutableBucket> monthBuckets = {};
    final Map<int, _MutableBucket> yearBuckets = {};
    final _MutableBucket allBucket = _MutableBucket(0, 0, 'ALL');
    final Map<int, Set<int>> yearToMonths = {};

    for (final item in items) {
      final date = item.safeDate;
      final year = date.year;
      final month = date.month;
      final key = monthKey(year, month);
      final amount = double.tryParse(item.safeAmount) ?? 0.0;
      final type = item.safeType;
      final category = item.safeCategory.isEmpty ? 'Sin categoría' : item.safeCategory;
      final account = item.safeAccount.isEmpty ? 'Sin cuenta' : item.safeAccount;

      final monthBucket = monthBuckets.putIfAbsent(
        key,
        () => _MutableBucket(year, month, key),
      );
      monthBucket.add(item, amount, type, category, account);

      final yearBucket = yearBuckets.putIfAbsent(
        year,
        () => _MutableBucket(year, 0, year.toString()),
      );
      yearBucket.add(item, amount, type, category, account);

      allBucket.add(item, amount, type, category, account);

      yearToMonths.putIfAbsent(year, () => <int>{}).add(month);
    }

    final Map<String, MonthSummary> monthSummaries = {};
    final Map<String, List<Add_data>> monthAll = {};
    final Map<String, List<Add_data>> monthIncome = {};
    final Map<String, List<Add_data>> monthExpense = {};

    for (final entry in monthBuckets.entries) {
      final b = entry.value;
      monthSummaries[entry.key] = b.toSummary();
      monthAll[entry.key] = List.unmodifiable(b.allTransactions);
      monthIncome[entry.key] = List.unmodifiable(b.incomeTransactions);
      monthExpense[entry.key] = List.unmodifiable(b.expenseTransactions);
    }

    final Map<int, MonthSummary> yearSummaries = {};
    final Map<int, List<Add_data>> yearAll = {};
    final Map<int, List<Add_data>> yearIncome = {};
    final Map<int, List<Add_data>> yearExpense = {};

    for (final entry in yearBuckets.entries) {
      final b = entry.value;
      yearSummaries[entry.key] = b.toSummary();
      yearAll[entry.key] = List.unmodifiable(b.allTransactions);
      yearIncome[entry.key] = List.unmodifiable(b.incomeTransactions);
      yearExpense[entry.key] = List.unmodifiable(b.expenseTransactions);
    }

    final sortedYears = yearToMonths.keys.toList()..sort();
    final Map<int, Set<int>> unmodifiableYearToMonths = {
      for (final entry in yearToMonths.entries)
        entry.key: Set.unmodifiable(entry.value),
    };

    _monthSummaries = Map.unmodifiable(monthSummaries);
    _monthAllTransactions = Map.unmodifiable(monthAll);
    _monthIncomeTransactions = Map.unmodifiable(monthIncome);
    _monthExpenseTransactions = Map.unmodifiable(monthExpense);

    _yearSummaries = Map.unmodifiable(yearSummaries);
    _yearAllTransactions = Map.unmodifiable(yearAll);
    _yearIncomeTransactions = Map.unmodifiable(yearIncome);
    _yearExpenseTransactions = Map.unmodifiable(yearExpense);

    _allTimeSummary = allBucket.toSummary();
    _allTransactions = List.unmodifiable(allBucket.allTransactions);
    _allIncomeTransactions = List.unmodifiable(allBucket.incomeTransactions);
    _allExpenseTransactions = List.unmodifiable(allBucket.expenseTransactions);

    _availableYears = List.unmodifiable(sortedYears);
    _yearToMonths = Map.unmodifiable(unmodifiableYearToMonths);

    _lastBoxLength = boxLength;
    _dirty = false;
    _revision++;
  }

  /// Retorna el resumen agregado para [year]-[month] en O(1).
  MonthSummary getMonthSummary(int year, int month) {
    _ensureBuilt();
    final key = monthKey(year, month);
    return _monthSummaries[key] ?? MonthSummary.empty(year, month, key: key);
  }

  /// Retorna el resumen agregado para todo el año [year] en O(1).
  MonthSummary getYearSummary(int year) {
    _ensureBuilt();
    return _yearSummaries[year] ??
        MonthSummary.empty(year, 0, key: year.toString());
  }

  /// Retorna el resumen global de todas las transacciones en O(1).
  MonthSummary getAllTimeSummary() {
    _ensureBuilt();
    return _allTimeSummary;
  }

  /// Retorna las transacciones de [year]-[month] en O(1).
  /// [typeFilter] puede ser `'Income'`, `'Expenses'` o `null` para todas.
  List<Add_data> getTransactionsForMonth(
    int year,
    int month, {
    String? typeFilter,
  }) {
    _ensureBuilt();
    final key = monthKey(year, month);
    if (typeFilter == 'Income') {
      return _monthIncomeTransactions[key] ?? const [];
    }
    if (typeFilter == 'Expenses') {
      return _monthExpenseTransactions[key] ?? const [];
    }
    return _monthAllTransactions[key] ?? const [];
  }

  /// Retorna las transacciones del año [year] en O(1).
  List<Add_data> getTransactionsForYear(
    int year, {
    String? typeFilter,
  }) {
    _ensureBuilt();
    if (typeFilter == 'Income') {
      return _yearIncomeTransactions[year] ?? const [];
    }
    if (typeFilter == 'Expenses') {
      return _yearExpenseTransactions[year] ?? const [];
    }
    return _yearAllTransactions[year] ?? const [];
  }

  /// Retorna todas las transacciones (opcionalmente filtradas por [typeFilter]) en O(1).
  List<Add_data> getAllTransactions({String? typeFilter}) {
    _ensureBuilt();
    if (typeFilter == 'Income') {
      return _allIncomeTransactions;
    }
    if (typeFilter == 'Expenses') {
      return _allExpenseTransactions;
    }
    return _allTransactions;
  }

  /// Retorna la lista ordenada de años con al menos una transacción en O(1).
  List<int> getAvailableYears() {
    _ensureBuilt();
    return _availableYears;
  }

  /// Retorna el conjunto de meses disponibles para [year] en O(1).
  Set<int> getAvailableMonthsForYear(int year) {
    _ensureBuilt();
    return _yearToMonths[year] ?? const {};
  }

  /// Retorna el mapa completo `año -> meses disponibles` en O(1).
  Map<int, Set<int>> getYearToMonthsMap() {
    _ensureBuilt();
    return _yearToMonths;
  }

  /// Retorna el resumen de los últimos [days] días consultando solo los buckets `YYYY-MM`
  /// que intersectan la ventana temporal.
  RecentDaysSummary getRecentDaysSummary(
    int days, {
    DateTime? referenceDate,
  }) {
    _ensureBuilt();
    final safeDays = days < 1 ? 1 : days;
    final now = referenceDate ?? _nowProvider();
    final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    final startDate = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: safeDays - 1));

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    int transactionCount = 0;
    final Map<String, double> expensesByCategory = {};
    final Map<String, double> incomeByCategory = {};

    DateTime cursor = DateTime(startDate.year, startDate.month, 1);
    final DateTime endMonth = DateTime(endDate.year, endDate.month, 1);

    while (!cursor.isAfter(endMonth)) {
      final key = monthKey(cursor.year, cursor.month);
      final monthItems = _monthAllTransactions[key];
      if (monthItems != null) {
        for (final item in monthItems) {
          final date = item.safeDate;
          if (date.isBefore(startDate) || date.isAfter(endDate)) {
            continue;
          }
          transactionCount++;
          final amount = double.tryParse(item.safeAmount) ?? 0.0;
          final category =
              item.safeCategory.isEmpty ? 'Sin categoría' : item.safeCategory;
          if (item.safeType == 'Income') {
            totalIncome += amount;
            incomeByCategory[category] =
                (incomeByCategory[category] ?? 0.0) + amount;
          } else if (item.safeType == 'Expenses') {
            totalExpenses += amount;
            expensesByCategory[category] =
                (expensesByCategory[category] ?? 0.0) + amount;
          }
        }
      }
      cursor = DateTime(cursor.year, cursor.month + 1, 1);
    }

    return RecentDaysSummary(
      days: safeDays,
      startDate: startDate,
      endDate: endDate,
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      netSavings: totalIncome - totalExpenses,
      transactionCount: transactionCount,
      expensesByCategory: Map.unmodifiable(expensesByCategory),
      incomeByCategory: Map.unmodifiable(incomeByCategory),
    );
  }

  /// Libera los listeners de Hive (solo para instancias no-singleton).
  void dispose() {
    _detachBox();
  }
}
