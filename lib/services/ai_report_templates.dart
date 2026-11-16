import 'package:finazaap/services/ai_financial_tools.dart';
import 'package:finazaap/utils/currency_helper.dart';

/// Plantillas reutilizables para informes y decisiones deterministas.
///
/// Las cifras siempre provienen de [AiFinancialTools]; la IA únicamente redacta
/// el comentario final y una justificación breve sobre los datos exactos.
class AiReportTemplates {
  static const List<String> _monthNames = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  static String _fmt(double value) =>
      '${CurrencyHelper.format(value)} ${CurrencyHelper.currencyCode}';

  static String _fmtSignedPercent(double? value) {
    if (value == null) return 'Sin datos del mes previo';
    final sign = value >= 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(1)}%';
  }

  /// Renderiza el informe mensual estructurado con agregados deterministas.
  static String renderMonthlyReport(
    MonthlyReportData data, {
    String? aiCommentary,
    bool includeCommentaryHeader = true,
  }) {
    final monthLabel =
        '${_monthNames[(data.referenceMonth.month - 1).clamp(0, 11)]} ${data.referenceMonth.year}';

    final buffer = StringBuffer()
      ..writeln('### 📊 Informe Financiero Mensual ($monthLabel)')
      ..writeln()
      ..writeln('**Resumen del mes:**')
      ..writeln('*   **Saldo disponible:** ${_fmt(data.availableBalance)}')
      ..writeln('*   **Ingresos del mes:** ${_fmt(data.monthlyIncome)} (${_fmtSignedPercent(data.incomeVariationPercent)} vs. mes previo)')
      ..writeln('*   **Gastos del mes:** ${_fmt(data.monthlyExpenses)} (${_fmtSignedPercent(data.expenseVariationPercent)} vs. mes previo)')
      ..writeln('*   **Ahorro neto:** ${_fmt(data.monthlySavings)} (Tasa: ${data.savingsRatePercent.toStringAsFixed(1)}%)')
      ..writeln();

    buffer.writeln('**Top categorías de gasto:**');
    if (data.topExpenseCategories.isEmpty) {
      buffer.writeln('*   Sin gastos registrados este mes.');
    } else {
      for (final cat in data.topExpenseCategories) {
        buffer.writeln(
          '*   **${cat.category}:** ${_fmt(cat.amount)} (${cat.sharePercent.toStringAsFixed(1)}%)',
        );
      }
    }
    buffer.writeln();

    buffer
      ..writeln('**Deudas y obligaciones del mes:**')
      ..writeln(
        '*   **Total programado:** ${_fmt(data.totalMonthlyObligations)} | '
        '**Pendiente:** ${_fmt(data.pendingObligationsAmount)} (${data.pendingObligationsCount} pendientes)',
      );

    if (includeCommentaryHeader) {
      buffer
        ..writeln()
        ..writeln('### 💡 Conclusión y Recomendación')
        ..write(aiCommentary?.trim().isNotEmpty == true
            ? aiCommentary!.trim()
            : defaultMonthlyReportCommentary(data));
    }

    return buffer.toString().trimRight();
  }

  /// Comentario determinista de respaldo para el informe mensual.
  static String defaultMonthlyReportCommentary(MonthlyReportData data) {
    if (data.monthlyIncome <= 0 && data.monthlyExpenses <= 0) {
      return 'Aún no hay movimientos suficientes este mes para evaluar tu tendencia. Registra tus ingresos y gastos para generar un diagnóstico completo.';
    }
    if (data.monthlySavings < 0) {
      final top = data.topExpenseCategories.isNotEmpty
          ? data.topExpenseCategories.first.category
          : 'tus categorías principales';
      return 'Este mes presentas déficit de ${_fmt(data.monthlySavings.abs())}. Prioriza recortar gastos en **$top** y cubrir tus ${data.pendingObligationsCount} obligaciones pendientes antes de asumir nuevos compromisos.';
    }
    if (data.savingsRatePercent >= 20) {
      return 'Mantienes una tasa de ahorro saludable (${data.savingsRatePercent.toStringAsFixed(1)}%). Conserva este margen y destina parte del excedente a tus metas o reserva de emergencia.';
    }
    return 'Tu flujo mensual es positivo (${_fmt(data.monthlySavings)}), aunque con margen ajustado (${data.savingsRatePercent.toStringAsFixed(1)}%). Vigila la variación de gastos respecto al mes previo para acercarte al 20% de ahorro.';
  }

  /// Prompt compacto (<= 480 tokens) para que Gemma redacte solo el comentario final del informe.
  static String buildMonthlyReportCommentaryPrompt(MonthlyReportData data) {
    final topCats = data.topExpenseCategories.isEmpty
        ? 'ninguna'
        : data.topExpenseCategories
            .map((c) => '${c.category}: ${_fmt(c.amount)} (${c.sharePercent.toStringAsFixed(0)}%)')
            .join(', ');

    final raw = '[CONTEXTO DE INFORME YA CALCULADO - NO RECALCULAR NI INVENTAR CIFRAS]\n'
        '- Ingresos: ${_fmt(data.monthlyIncome)} (${_fmtSignedPercent(data.incomeVariationPercent)} vs mes previo)\n'
        '- Gastos: ${_fmt(data.monthlyExpenses)} (${_fmtSignedPercent(data.expenseVariationPercent)} vs mes previo)\n'
        '- Ahorro neto: ${_fmt(data.monthlySavings)} (${data.savingsRatePercent.toStringAsFixed(1)}%)\n'
        '- Top categorías: $topCats\n'
        '- Obligaciones pendientes: ${data.pendingObligationsCount} por ${_fmt(data.pendingObligationsAmount)}\n'
        'Instrucción: El usuario ya verá la tabla con estas cifras exactas. '
        'Redacta ÚNICAMENTE un comentario final breve (máximo 3 líneas) y una justificación práctica.';

    return AiTokenBudget.fitToTokenBudget(
      raw,
      AiTokenBudget.maxRetrievedContextTokens,
    );
  }

  /// Renderiza la evaluación determinista de TCO para compra de vehículo.
  static String renderVehicleDecisionReport(
    VehicleTcoResult tco, {
    String? aiCommentary,
    bool includeCommentaryHeader = true,
  }) {
    final badge = tco.verdict == 'Viable'
        ? '✅ **[VIABLE]**'
        : tco.verdict == 'Precaución'
            ? '⚠️ **[PRECAUCIÓN]**'
            : '🚨 **[NO RECOMENDADO]**';

    final priceNote = tco.priceAssumed ? ' *(valor de referencia estimado)*' : '';
    final deltaSign = tco.netTransportDelta >= 0 ? '+' : '';

    final buffer = StringBuffer()
      ..writeln('$badge Análisis TCO de Compra de Vehículo')
      ..writeln()
      ..writeln('*   **Precio considerado:** ${_fmt(tco.vehiclePrice)}$priceNote')
      ..writeln('*   **Cuota inicial (20%):** ${_fmt(tco.downPayment)} (${tco.canAffordDownPayment ? "cubierta por tu saldo" : "supera tu saldo disponible"})')
      ..writeln('*   **Financiación (${tco.termMonths} meses al ${(tco.annualInterestRate * 100).toStringAsFixed(1)}% anual):**')
      ..writeln('    *   Cuota mensual del crédito: **${_fmt(tco.monthlyLoanPayment)}**')
      ..writeln('    *   Interés total estimado: **${_fmt(tco.totalInterest)}**')
      ..writeln('*   **Costos operativos mensuales:** ${_fmt(tco.monthlyOperatingCost)} *(Mantenimiento: ${_fmt(tco.monthlyMaintenance)}, Seguro: ${_fmt(tco.monthlyInsurance)}, Impuestos: ${_fmt(tco.monthlyTaxes)}, Combustible: ${_fmt(tco.monthlyFuel)})*')
      ..writeln('*   **TCO mensual total:** **${_fmt(tco.monthlyTco)}** (${tco.tcoToIncomeRatioPercent.toStringAsFixed(1)}% de tus ingresos)')
      ..writeln('*   **Depreciación estimada:** ${_fmt(tco.estimatedMonthlyDepreciation)}/mes (${_fmt(tco.estimatedAnnualDepreciation)}/año)')
      ..writeln('*   **Comparación vs. transporte actual:** Hoy gastas ~${_fmt(tco.currentMonthlyTransportExpense)}/mes → impacto neto **$deltaSign${_fmt(tco.netTransportDelta)}/mes**')
      ..writeln('*   **Flujo de caja / Capacidad de ahorro:** Antes ${_fmt(tco.monthlyCashFlowBefore)}/mes → Después **${_fmt(tco.monthlyCashFlowAfter)}/mes**');

    if (includeCommentaryHeader) {
      buffer
        ..writeln()
        ..writeln('### 💡 Recomendación')
        ..write(aiCommentary?.trim().isNotEmpty == true
            ? aiCommentary!.trim()
            : defaultVehicleDecisionCommentary(tco));
    }

    return buffer.toString().trimRight();
  }

  /// Comentario determinista de respaldo para TCO de vehículo.
  static String defaultVehicleDecisionCommentary(VehicleTcoResult tco) {
    if (!tco.canAffordDownPayment) {
      return 'Tu saldo disponible no alcanza para la cuota inicial (${_fmt(tco.downPayment)}). Conviene ahorrar primero la inicial antes de comprometer tu flujo de caja.';
    }
    if (tco.monthlyCashFlowAfter < 0) {
      return 'El TCO mensual (${_fmt(tco.monthlyTco)}) supera tu margen de ahorro actual y dejaría tu flujo mensual en negativo (${_fmt(tco.monthlyCashFlowAfter)}). No es recomendable en este momento.';
    }
    if (tco.verdict == 'Precaución') {
      return 'Aunque puedes cubrir la inicial, el vehículo absorbería ${tco.tcoToIncomeRatioPercent.toStringAsFixed(1)}% de tus ingresos y reduciría tu ahorro mensual a ${_fmt(tco.savingsCapacityAfter)}. Evalúa un monto menor o mayor cuota inicial.';
    }
    return 'Tu flujo de caja soporta el TCO mensual (${_fmt(tco.monthlyTco)}) manteniendo ahorro positivo (${_fmt(tco.savingsCapacityAfter)}/mes). Verifica que el seguro y mantenimiento no afecten tus otras metas.';
  }

  /// Prompt compacto (<= 480 tokens) para que Gemma redacte la recomendación sobre TCO exacto.
  static String buildVehicleDecisionCommentaryPrompt(VehicleTcoResult tco) {
    final raw = '[CONTEXTO TCO YA CALCULADO - NO RECALCULAR NI INVENTAR CIFRAS]\n'
        '- Veredicto determinista: ${tco.verdict}\n'
        '- Precio: ${_fmt(tco.vehiclePrice)} | Inicial: ${_fmt(tco.downPayment)} (alcanza: ${tco.canAffordDownPayment ? "sí" : "no"})\n'
        '- Cuota crédito: ${_fmt(tco.monthlyLoanPayment)}/mes | Interés total: ${_fmt(tco.totalInterest)}\n'
        '- TCO mensual total: ${_fmt(tco.monthlyTco)} (${tco.tcoToIncomeRatioPercent.toStringAsFixed(1)}% del ingreso)\n'
        '- Depreciación: ${_fmt(tco.estimatedMonthlyDepreciation)}/mes\n'
        '- Transporte actual: ${_fmt(tco.currentMonthlyTransportExpense)}/mes | Impacto neto: ${_fmt(tco.netTransportDelta)}/mes\n'
        '- Flujo de caja después: ${_fmt(tco.monthlyCashFlowAfter)}/mes\n'
        'Instrucción: El usuario ya verá el desglose exacto arriba. '
        'Explica brevemente (máximo 3-4 líneas) por qué conviene o no según estas cifras exactas.';

    return AiTokenBudget.fitToTokenBudget(
      raw,
      AiTokenBudget.maxRetrievedContextTokens,
    );
  }
}
