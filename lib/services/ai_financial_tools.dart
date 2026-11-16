import 'dart:math' as math;

import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';

/// Intenciones soportadas por el router conversacional de Moneo AI.
enum AiIntent {
  consulta,
  informe,
  decision,
  registro,
  otro,
}

/// Presupuesto estricto de tokens para sesiones Gemma on-device (2048 tokens).
class AiTokenBudget {
  static const int maxContextTokens = 2048;
  static const int maxOutputTokens = 320;
  static const int maxSystemTokens = 380;
  static const int maxRecentTurnsTokens = 700;
  static const int maxRetrievedContextTokens = 480;
  static const int maxCurrentTurnTokens = 168;
  static const int rotationThresholdTokens = 1880;

  /// Estimación conservadora offline (~3.5 caracteres por token en español).
  static int estimateTokens(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return (trimmed.length / 3.5).ceil();
  }

  /// Ajusta [text] al máximo de [maxTokens] respetando límites de línea o palabra.
  static String fitToTokenBudget(String text, int maxTokens) {
    if (maxTokens <= 0) return '';
    if (estimateTokens(text) <= maxTokens) return text;

    final maxChars = (maxTokens * 3.5).floor();
    if (maxChars <= 12) {
      return text.substring(0, math.min(text.length, maxChars));
    }

    final cutoff = math.min(text.length, maxChars - 3);
    var slice = text.substring(0, cutoff);
    final lastNewline = slice.lastIndexOf('\n');
    final lastSpace = slice.lastIndexOf(' ');
    final breakIdx = math.max(lastNewline, lastSpace);
    if (breakIdx > (cutoff * 0.6).floor()) {
      slice = slice.substring(0, breakIdx);
    }
    return '${slice.trimRight()}...';
  }
}

/// Plan de recuperación filtrada generado por [AiQueryRouter].
class AiRoutePlan {
  final AiIntent intent;
  final bool needsFinancialState;
  final bool needsMonthlyReportAggregates;
  final bool needsPurchaseDecision;
  final bool needsVehicleTco;
  final bool needsTransactionQuery;
  final bool needsObligations;
  final bool needsCategories;
  final bool needsAccounts;
  final bool needsCategorySuggestions;

  const AiRoutePlan({
    required this.intent,
    this.needsFinancialState = false,
    this.needsMonthlyReportAggregates = false,
    this.needsPurchaseDecision = false,
    this.needsVehicleTco = false,
    this.needsTransactionQuery = false,
    this.needsObligations = false,
    this.needsCategories = false,
    this.needsAccounts = false,
    this.needsCategorySuggestions = false,
  });
}

/// Detector determinista de intención del usuario.
class AiIntentDetector {
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  static AiIntent detect(String userMessage) {
    final norm = normalize(userMessage);
    if (norm.isEmpty) return AiIntent.otro;

    // 1. Registro (crear/sugerir categorías o registrar transacción explícita)
    final isCategoryCreation = _containsAny(norm, [
          'crear',
          'suger',
          'recomen',
          'propon',
          'agregar',
        ]) &&
        _containsAny(norm, ['categoria', 'categorias', 'rubro', 'rubros']);

    final isExplicitRecord = _containsAny(norm, [
          'registra',
          'registrar',
          'anota',
          'anotar',
          'apunta',
          'apuntar',
          'agrega un gasto',
          'agrega un ingreso',
          'recibi ',
          'me pagaron',
          'pague ',
          'gaste ',
        ]) &&
        RegExp(r'\b[0-9]+(?:[.,][0-9]+)?\b').hasMatch(norm);

    if (isCategoryCreation || isExplicitRecord) {
      return AiIntent.registro;
    }

    // 2. Decisión financiera (comprar, financiar, carro/vehículo, crédito)
    if (_containsAny(norm, [
      'me conviene',
      'conviene comprar',
      'deberia comprar',
      'es buena idea',
      'vale la pena',
      'puedo comprar',
      'comprar un carro',
      'comprar carro',
      'comprar auto',
      'comprar un auto',
      'comprar vehiculo',
      'comprar moto',
      'comprar una moto',
      'sacar a cuotas',
      'financiar',
      'viabilidad',
    ])) {
      return AiIntent.decision;
    }

    if (_containsAny(norm, ['comprar', 'compra', 'adquirir']) &&
        RegExp(r'[0-9]+').hasMatch(norm)) {
      return AiIntent.decision;
    }

    // 3. Informe financiero mensual / reporte estructurado
    if (_containsAny(norm, [
      'informe',
      'reporte mensual',
      'reporte financiero',
      'resumen mensual',
      'resumen del mes',
      'resumen financiero',
      'balance mensual',
      'como cerre el mes',
      'como voy este mes',
      'como van mis finanzas',
      'diagnostico financiero',
    ])) {
      return AiIntent.informe;
    }

    // 4. Consulta puntual de transacciones, deudas, saldos, categorías o metas
    if (_containsAny(norm, [
      'gasto',
      'gastos',
      'gaste',
      'ingreso',
      'ingresos',
      'transaccion',
      'transacciones',
      'movimiento',
      'movimientos',
      'promedio',
      'cuanto',
      'suma',
      'total',
      'historial',
      'categoria',
      'categorias',
      'rubro',
      'rubros',
      'obligacion',
      'obligaciones',
      'deuda',
      'deudas',
      'responsabilidad',
      'responsabilidades',
      'saldo',
      'saldos',
      'cuenta',
      'cuentas',
      'ahorro',
      'presupuesto',
      'patrones',
      'habito',
      'meta',
      'metas',
    ])) {
      return AiIntent.consulta;
    }

    return AiIntent.otro;
  }

  static bool _containsAny(String haystack, List<String> needles) {
    for (final n in needles) {
      if (haystack.contains(n)) return true;
    }
    return false;
  }
}

/// Router que selecciona únicamente las herramientas y datos necesarios por intención.
class AiQueryRouter {
  static AiRoutePlan route(String userMessage) {
    final intent = AiIntentDetector.detect(userMessage);
    final norm = AiIntentDetector.normalize(userMessage);

    switch (intent) {
      case AiIntent.registro:
        final isCategoryCreation =
            AiIntentDetector._containsAny(norm, ['categoria', 'categorias', 'rubro', 'rubros']);
        return AiRoutePlan(
          intent: intent,
          needsCategories: true,
          needsAccounts: !isCategoryCreation,
          needsCategorySuggestions: isCategoryCreation,
        );

      case AiIntent.informe:
        return const AiRoutePlan(
          intent: AiIntent.informe,
          needsFinancialState: true,
          needsMonthlyReportAggregates: true,
          needsObligations: true,
        );

      case AiIntent.decision:
        final isVehicle = AiIntentDetector._containsAny(norm, [
          'carro',
          'auto',
          'vehiculo',
          'camioneta',
          'moto',
          'motocicleta',
        ]);
        return AiRoutePlan(
          intent: AiIntent.decision,
          needsFinancialState: true,
          needsPurchaseDecision: true,
          needsVehicleTco: isVehicle,
          needsObligations: true,
        );

      case AiIntent.consulta:
        final asksCategories = AiIntentDetector._containsAny(
          norm,
          ['categoria', 'categorias', 'rubro', 'rubros'],
        );
        final asksObligations = AiIntentDetector._containsAny(
          norm,
          ['obligacion', 'obligaciones', 'deuda', 'deudas', 'responsabilidad', 'responsabilidades', 'pagar', 'pago'],
        );
        final asksAccounts = AiIntentDetector._containsAny(
          norm,
          ['saldo', 'saldos', 'cuenta', 'cuentas', 'dinero'],
        );
        final asksTransactions = AiIntentDetector._containsAny(
          norm,
          [
            'gasto',
            'gastos',
            'gaste',
            'ingreso',
            'ingresos',
            'ingrese',
            'transaccion',
            'transacciones',
            'movimiento',
            'movimientos',
            'promedio',
            'cuanto',
            'suma',
            'total',
            'historial',
          ],
        );
        return AiRoutePlan(
          intent: AiIntent.consulta,
          needsFinancialState: true,
          needsTransactionQuery: asksTransactions,
          needsObligations: asksObligations,
          needsCategories: asksCategories,
          needsAccounts: asksAccounts,
        );

      case AiIntent.otro:
        return const AiRoutePlan(
          intent: AiIntent.otro,
          needsFinancialState: true,
        );
    }
  }
}

/// Parámetros de entrada para el cálculo determinista de TCO de vehículo.
class VehicleTcoInput {
  final double vehiclePrice;
  final bool priceAssumed;
  final double downPaymentPercent;
  final double annualInterestRate;
  final int termMonths;
  final double annualMaintenanceRate;
  final double annualInsuranceRate;
  final double annualTaxRate;
  final double monthlyFuelEstimate;
  final double annualDepreciationRate;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double availableBalance;
  final double currentMonthlyTransportExpense;

  const VehicleTcoInput({
    required this.vehiclePrice,
    this.priceAssumed = false,
    this.downPaymentPercent = 0.20,
    this.annualInterestRate = 0.16,
    this.termMonths = 60,
    this.annualMaintenanceRate = 0.04,
    this.annualInsuranceRate = 0.045,
    this.annualTaxRate = 0.015,
    this.monthlyFuelEstimate = 0.0,
    this.annualDepreciationRate = 0.12,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.availableBalance,
    required this.currentMonthlyTransportExpense,
  });
}

/// Resultado determinista completo del análisis TCO de vehículo.
class VehicleTcoResult {
  final double vehiclePrice;
  final bool priceAssumed;
  final double downPayment;
  final double loanPrincipal;
  final int termMonths;
  final double annualInterestRate;
  final double monthlyLoanPayment;
  final double totalInterest;
  final double monthlyMaintenance;
  final double monthlyInsurance;
  final double monthlyTaxes;
  final double monthlyFuel;
  final double monthlyOperatingCost;
  final double monthlyTco;
  final double estimatedAnnualDepreciation;
  final double estimatedMonthlyDepreciation;
  final double currentMonthlyTransportExpense;
  final double netTransportDelta;
  final double monthlyCashFlowBefore;
  final double monthlyCashFlowAfter;
  final double savingsCapacityBefore;
  final double savingsCapacityAfter;
  final double tcoToIncomeRatioPercent;
  final bool canAffordDownPayment;
  final String verdict; // 'Viable' | 'Precaución' | 'No recomendado'

  const VehicleTcoResult({
    required this.vehiclePrice,
    required this.priceAssumed,
    required this.downPayment,
    required this.loanPrincipal,
    required this.termMonths,
    required this.annualInterestRate,
    required this.monthlyLoanPayment,
    required this.totalInterest,
    required this.monthlyMaintenance,
    required this.monthlyInsurance,
    required this.monthlyTaxes,
    required this.monthlyFuel,
    required this.monthlyOperatingCost,
    required this.monthlyTco,
    required this.estimatedAnnualDepreciation,
    required this.estimatedMonthlyDepreciation,
    required this.currentMonthlyTransportExpense,
    required this.netTransportDelta,
    required this.monthlyCashFlowBefore,
    required this.monthlyCashFlowAfter,
    required this.savingsCapacityBefore,
    required this.savingsCapacityAfter,
    required this.tcoToIncomeRatioPercent,
    required this.canAffordDownPayment,
    required this.verdict,
  });
}

/// Agregado de categoría para informes mensuales.
class CategoryAggregate {
  final String category;
  final double amount;
  final double sharePercent;

  const CategoryAggregate({
    required this.category,
    required this.amount,
    required this.sharePercent,
  });
}

/// Agregados deterministas para informes financieros mensuales.
class MonthlyReportData {
  final DateTime referenceMonth;
  final double availableBalance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double monthlySavings;
  final double savingsRatePercent;
  final double previousMonthIncome;
  final double previousMonthExpenses;
  final double? incomeVariationPercent;
  final double? expenseVariationPercent;
  final List<CategoryAggregate> topExpenseCategories;
  final int pendingObligationsCount;
  final double pendingObligationsAmount;
  final double totalMonthlyObligations;

  const MonthlyReportData({
    required this.referenceMonth,
    required this.availableBalance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.monthlySavings,
    required this.savingsRatePercent,
    required this.previousMonthIncome,
    required this.previousMonthExpenses,
    required this.incomeVariationPercent,
    required this.expenseVariationPercent,
    required this.topExpenseCategories,
    required this.pendingObligationsCount,
    required this.pendingObligationsAmount,
    required this.totalMonthlyObligations,
  });
}

/// Funciones financieras deterministas (sin invención de cifras por IA).
class AiFinancialTools {
  static const double defaultReferenceVehiclePrice = 45000000.0;

  /// Extrae parámetros numéricos opcionales de una consulta de compra de vehículo.
  static VehicleTcoInput extractVehicleInputFromMessage(
    String userMessage, {
    required double monthlyIncome,
    required double monthlyExpenses,
    required double availableBalance,
    required double currentMonthlyTransportExpense,
  }) {
    final norm = AiIntentDetector.normalize(userMessage);
    double? price;
    bool priceAssumed = false;

    final priceMatch = RegExp(
      r'(?:de|por|valor|precio|cuesta|vale)?\s*\$?\s*([0-9][0-9.,]{2,})\s*(millones|m|mil|k)?',
      caseSensitive: false,
    ).firstMatch(norm);

    if (priceMatch != null) {
      final rawDigits = priceMatch.group(1)!.replaceAll('.', '').replaceAll(',', '.');
      final parsed = double.tryParse(rawDigits);
      final unit = priceMatch.group(2)?.toLowerCase();
      if (parsed != null && parsed > 0) {
        if (unit == 'millones' || unit == 'm') {
          price = parsed * 1000000.0;
        } else if (unit == 'mil' || unit == 'k') {
          price = parsed * 1000.0;
        } else {
          price = parsed;
        }
      }
    }

    if (price == null || price <= 0) {
      priceAssumed = true;
      // Si los ingresos parecen estar en moneda de baja denominación (ej. USD < 15000), usar referencia acorde
      price = (monthlyIncome > 0 && monthlyIncome < 15000)
          ? 18000.0
          : defaultReferenceVehiclePrice;
    }

    int termMonths = 60;
    final monthsMatch = RegExp(r'\b([1-9][0-9]?)\s*(meses|mes)\b').firstMatch(norm);
    final yearsMatch = RegExp(r'\b([1-9])\s*(anos|ano)\b').firstMatch(norm);
    if (monthsMatch != null) {
      termMonths = (int.tryParse(monthsMatch.group(1)!) ?? 60).clamp(6, 120);
    } else if (yearsMatch != null) {
      termMonths = ((int.tryParse(yearsMatch.group(1)!) ?? 5) * 12).clamp(12, 120);
    }

    // Estimación base de combustible mensual (~0.5% del valor del vehículo/mes si no se especifica)
    final fuelEstimate = price * 0.005;

    return VehicleTcoInput(
      vehiclePrice: price,
      priceAssumed: priceAssumed,
      termMonths: termMonths,
      monthlyFuelEstimate: fuelEstimate,
      monthlyIncome: monthlyIncome,
      monthlyExpenses: monthlyExpenses,
      availableBalance: availableBalance,
      currentMonthlyTransportExpense: currentMonthlyTransportExpense,
    );
  }

  /// Calcula de forma determinista el TCO, cuota, interés, depreciación y flujo de caja.
  static VehicleTcoResult calculateVehicleTco(VehicleTcoInput input) {
    final price = math.max(0.0, input.vehiclePrice);
    final downPayment = price * input.downPaymentPercent.clamp(0.0, 0.9);
    final loanPrincipal = math.max(0.0, price - downPayment);
    final term = math.max(1, input.termMonths);
    final monthlyRate = math.max(0.0, input.annualInterestRate) / 12.0;

    double monthlyLoanPayment;
    if (loanPrincipal == 0) {
      monthlyLoanPayment = 0.0;
    } else if (monthlyRate == 0) {
      monthlyLoanPayment = loanPrincipal / term;
    } else {
      final factor = math.pow(1 + monthlyRate, term).toDouble();
      monthlyLoanPayment = loanPrincipal * (monthlyRate * factor) / (factor - 1);
    }

    final totalPaid = monthlyLoanPayment * term;
    final totalInterest = math.max(0.0, totalPaid - loanPrincipal);

    final monthlyMaintenance = (price * input.annualMaintenanceRate) / 12.0;
    final monthlyInsurance = (price * input.annualInsuranceRate) / 12.0;
    final monthlyTaxes = (price * input.annualTaxRate) / 12.0;
    final monthlyFuel = input.monthlyFuelEstimate > 0
        ? input.monthlyFuelEstimate
        : price * 0.005;
    final monthlyOperatingCost =
        monthlyMaintenance + monthlyInsurance + monthlyTaxes + monthlyFuel;
    final monthlyTco = monthlyLoanPayment + monthlyOperatingCost;

    final estimatedAnnualDepreciation = price * input.annualDepreciationRate;
    final estimatedMonthlyDepreciation = estimatedAnnualDepreciation / 12.0;

    final cashFlowBefore = input.monthlyIncome - input.monthlyExpenses;
    final netTransportDelta = monthlyTco - input.currentMonthlyTransportExpense;
    final cashFlowAfter = cashFlowBefore - netTransportDelta;

    final savingsBefore = math.max(0.0, cashFlowBefore);
    final savingsAfter = cashFlowAfter;
    final tcoToIncomeRatio =
        input.monthlyIncome > 0 ? (monthlyTco / input.monthlyIncome) * 100.0 : 100.0;
    final canAffordDownPayment = input.availableBalance >= downPayment;

    String verdict;
    if (!canAffordDownPayment || cashFlowAfter < 0 || tcoToIncomeRatio > 35.0) {
      verdict = 'No recomendado';
    } else if (tcoToIncomeRatio > 20.0 ||
        (savingsBefore > 0 && savingsAfter < savingsBefore * 0.4)) {
      verdict = 'Precaución';
    } else {
      verdict = 'Viable';
    }

    return VehicleTcoResult(
      vehiclePrice: price,
      priceAssumed: input.priceAssumed,
      downPayment: downPayment,
      loanPrincipal: loanPrincipal,
      termMonths: term,
      annualInterestRate: input.annualInterestRate,
      monthlyLoanPayment: monthlyLoanPayment,
      totalInterest: totalInterest,
      monthlyMaintenance: monthlyMaintenance,
      monthlyInsurance: monthlyInsurance,
      monthlyTaxes: monthlyTaxes,
      monthlyFuel: monthlyFuel,
      monthlyOperatingCost: monthlyOperatingCost,
      monthlyTco: monthlyTco,
      estimatedAnnualDepreciation: estimatedAnnualDepreciation,
      estimatedMonthlyDepreciation: estimatedMonthlyDepreciation,
      currentMonthlyTransportExpense: input.currentMonthlyTransportExpense,
      netTransportDelta: netTransportDelta,
      monthlyCashFlowBefore: cashFlowBefore,
      monthlyCashFlowAfter: cashFlowAfter,
      savingsCapacityBefore: savingsBefore,
      savingsCapacityAfter: savingsAfter,
      tcoToIncomeRatioPercent: tcoToIncomeRatio,
      canAffordDownPayment: canAffordDownPayment,
      verdict: verdict,
    );
  }

  /// Calcula el gasto mensual promedio en transporte en una ventana móvil de 30-90 días.
  static double estimateMonthlyTransportExpense(
    Iterable<Add_data> transactions, {
    DateTime? now,
    int windowDays = 60,
  }) {
    final ref = now ?? DateTime.now();
    final clampedDays = windowDays.clamp(30, 90);
    final cutoff = ref.subtract(Duration(days: clampedDays));

    const transportKeywords = [
      'transporte',
      'gasolina',
      'combustible',
      'uber',
      'didi',
      'taxi',
      'bus',
      'metro',
      'peaje',
      'parqueadero',
      'soat',
      'mecanico',
      'carro',
      'moto',
    ];

    double total = 0.0;
    for (final tx in transactions) {
      if (tx.safeType != 'Expenses') continue;
      if (tx.safeDate.isBefore(cutoff)) continue;
      final catNorm = AiIntentDetector.normalize(tx.safeCategory);
      final detNorm = AiIntentDetector.normalize(tx.safeDetail);
      final isTransport = transportKeywords.any(
        (kw) => catNorm.contains(kw) || detNorm.contains(kw),
      );
      if (isTransport) {
        total += double.tryParse(tx.safeAmount) ?? 0.0;
      }
    }

    final months = clampedDays / 30.0;
    return months > 0 ? total / months : total;
  }

  /// Calcula agregados deterministas del mes actual vs. mes previo y obligaciones.
  static MonthlyReportData computeMonthlyReport({
    required Iterable<Add_data> transactions,
    required List<Responsibility> obligations,
    required double availableBalance,
    DateTime? now,
    int topCategoriesLimit = 4,
  }) {
    final ref = now ?? DateTime.now();
    final prevMonth = DateTime(ref.year, ref.month - 1, 1);

    double currentIncome = 0.0;
    double currentExpenses = 0.0;
    double prevIncome = 0.0;
    double prevExpenses = 0.0;
    final Map<String, double> currentCategoryExpenses = {};

    for (final tx in transactions) {
      final d = tx.safeDate;
      final amt = double.tryParse(tx.safeAmount) ?? 0.0;
      final isCurrentMonth = d.year == ref.year && d.month == ref.month;
      final isPrevMonth = d.year == prevMonth.year && d.month == prevMonth.month;

      if (isCurrentMonth) {
        if (tx.safeType == 'Income') {
          currentIncome += amt;
        } else if (tx.safeType == 'Expenses') {
          currentExpenses += amt;
          final cat = tx.safeCategory.isNotEmpty ? tx.safeCategory : 'Otros';
          currentCategoryExpenses[cat] = (currentCategoryExpenses[cat] ?? 0.0) + amt;
        }
      } else if (isPrevMonth) {
        if (tx.safeType == 'Income') {
          prevIncome += amt;
        } else if (tx.safeType == 'Expenses') {
          prevExpenses += amt;
        }
      }
    }

    final monthlySavings = currentIncome - currentExpenses;
    final savingsRate =
        currentIncome > 0 ? (monthlySavings / currentIncome) * 100.0 : 0.0;

    final double? incomeVar = prevIncome > 0
        ? ((currentIncome - prevIncome) / prevIncome) * 100.0
        : null;
    final double? expenseVar = prevExpenses > 0
        ? ((currentExpenses - prevExpenses) / prevExpenses) * 100.0
        : null;

    final sortedCats = currentCategoryExpenses.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCats = sortedCats.take(topCategoriesLimit).map((e) {
      final share = currentExpenses > 0 ? (e.value / currentExpenses) * 100.0 : 0.0;
      return CategoryAggregate(
        category: e.key,
        amount: e.value,
        sharePercent: share,
      );
    }).toList();

    int pendingCount = 0;
    double pendingAmount = 0.0;
    double totalMonthlyObs = 0.0;
    for (final r in obligations) {
      final expected = r.getAmountForDate(ref.month, ref.year);
      final paid = r.getPaidAmountInCycle(ref.month, ref.year);
      totalMonthlyObs += expected;
      if (!r.isPaidInMonth(ref.month, ref.year)) {
        pendingCount++;
        pendingAmount += math.max(0.0, expected - paid);
      }
    }

    return MonthlyReportData(
      referenceMonth: DateTime(ref.year, ref.month, 1),
      availableBalance: availableBalance,
      monthlyIncome: currentIncome,
      monthlyExpenses: currentExpenses,
      monthlySavings: monthlySavings,
      savingsRatePercent: savingsRate,
      previousMonthIncome: prevIncome,
      previousMonthExpenses: prevExpenses,
      incomeVariationPercent: incomeVar,
      expenseVariationPercent: expenseVar,
      topExpenseCategories: topCats,
      pendingObligationsCount: pendingCount,
      pendingObligationsAmount: pendingAmount,
      totalMonthlyObligations: totalMonthlyObs,
    );
  }
}
