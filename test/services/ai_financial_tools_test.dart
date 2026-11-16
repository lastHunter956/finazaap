import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/services/ai_financial_tools.dart';
import 'package:finazaap/services/ai_report_templates.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiIntentDetector & AiQueryRouter', () {
    test('detecta las 5 intenciones principales correctamente', () {
      expect(AiIntentDetector.detect('¿Cuánto gasté en comida este mes?'), AiIntent.consulta);
      expect(AiIntentDetector.detect('Dame mi informe mensual financiero'), AiIntent.informe);
      expect(AiIntentDetector.detect('¿Me conviene comprar un carro de 40 millones?'), AiIntent.decision);
      expect(AiIntentDetector.detect('Registra un gasto de 25000 en almuerzo'), AiIntent.registro);
      expect(AiIntentDetector.detect('Hola, ¿cómo estás?'), AiIntent.otro);
    });

    test('router selecciona recuperación filtrada sin volcar toda la base', () {
      final informePlan = AiQueryRouter.route('Genera mi reporte mensual');
      expect(informePlan.intent, AiIntent.informe);
      expect(informePlan.needsFinancialState, isTrue);
      expect(informePlan.needsMonthlyReportAggregates, isTrue);
      expect(informePlan.needsObligations, isTrue);
      expect(informePlan.needsTransactionQuery, isFalse);
      expect(informePlan.needsCategories, isFalse);

      final vehiclePlan = AiQueryRouter.route('¿Me conviene comprar un carro?');
      expect(vehiclePlan.intent, AiIntent.decision);
      expect(vehiclePlan.needsVehicleTco, isTrue);
      expect(vehiclePlan.needsPurchaseDecision, isTrue);
      expect(vehiclePlan.needsTransactionQuery, isFalse);
    });
  });

  group('AiTokenBudget', () {
    test('respeta el límite de tokens al truncar texto largo', () {
      final longText = List.filled(200, 'palabra').join(' ');
      final fitted = AiTokenBudget.fitToTokenBudget(
        longText,
        AiTokenBudget.maxSystemTokens,
      );
      expect(
        AiTokenBudget.estimateTokens(fitted),
        lessThanOrEqualTo(AiTokenBudget.maxSystemTokens),
      );
      expect(fitted, endsWith('...'));
    });
  });

  group('AiFinancialTools - TCO Vehículo & Informe Mensual', () {
    test('calcula TCO determinista completo de vehículo y comparación de transporte', () {
      final result = AiFinancialTools.calculateVehicleTco(
        const VehicleTcoInput(
          vehiclePrice: 20000,
          downPaymentPercent: 0.20,
          annualInterestRate: 0.12,
          termMonths: 48,
          monthlyFuelEstimate: 150,
          monthlyIncome: 4000,
          monthlyExpenses: 2200,
          availableBalance: 6000,
          currentMonthlyTransportExpense: 200,
        ),
      );

      // Inicial = 4000, Principal = 16000 al 1% mensual por 48 meses => ~421.34
      expect(result.downPayment, closeTo(4000, 0.01));
      expect(result.loanPrincipal, closeTo(16000, 0.01));
      expect(result.monthlyLoanPayment, closeTo(421.34, 0.5));
      expect(result.totalInterest, closeTo((result.monthlyLoanPayment * 48) - 16000, 0.5));
      expect(result.monthlyOperatingCost, greaterThan(150));
      expect(result.monthlyTco, closeTo(result.monthlyLoanPayment + result.monthlyOperatingCost, 0.01));
      expect(result.estimatedAnnualDepreciation, closeTo(2400, 0.01));
      expect(result.netTransportDelta, closeTo(result.monthlyTco - 200, 0.01));
      expect(result.canAffordDownPayment, isTrue);
      expect(result.verdict, isIn(['Viable', 'Precaución']));
    });

    test('estima gasto mensual de transporte solo en ventana móvil de 60 días', () {
      final now = DateTime(2026, 11, 16);
      final txs = [
        Add_data('Expenses', '120', now.subtract(const Duration(days: 10)), 'Uber', 'Transporte', 'Efectivo', 0),
        Add_data('Expenses', '80', now.subtract(const Duration(days: 40)), 'Gasolina', 'Transporte', 'Efectivo', 0),
        // Fuera de ventana de 60 días: debe ignorarse
        Add_data('Expenses', '5000', now.subtract(const Duration(days: 120)), 'Uber viejo', 'Transporte', 'Efectivo', 0),
      ];

      final avgMonthly = AiFinancialTools.estimateMonthlyTransportExpense(
        txs,
        now: now,
        windowDays: 60,
      );
      // 200 en 60 días (2 meses) => 100/mes
      expect(avgMonthly, closeTo(100.0, 0.01));
    });

    test('computa agregados del informe mensual y renderiza plantilla', () {
      final now = DateTime(2026, 11, 16);
      final prev = DateTime(2026, 10, 10);
      final txs = [
        Add_data('Income', '3000', now, 'Salario', 'Salario', 'Banco', 0),
        Add_data('Expenses', '900', now, 'Renta', 'Vivienda', 'Banco', 0),
        Add_data('Expenses', '300', now, 'Mercado', 'Alimentación', 'Banco', 0),
        Add_data('Income', '2500', prev, 'Salario', 'Salario', 'Banco', 0),
        Add_data('Expenses', '1000', prev, 'Renta', 'Vivienda', 'Banco', 0),
      ];
      final obligations = [
        Responsibility(
          id: 'r1',
          name: 'Internet',
          amount: 100,
          dueDay: 20,
          category: 'Servicios',
          frequency: 'Mensual',
        ),
      ];

      final report = AiFinancialTools.computeMonthlyReport(
        transactions: txs,
        obligations: obligations,
        availableBalance: 5000,
        now: now,
      );

      expect(report.monthlyIncome, 3000);
      expect(report.monthlyExpenses, 1200);
      expect(report.monthlySavings, 1800);
      expect(report.incomeVariationPercent, closeTo(20.0, 0.01));
      expect(report.expenseVariationPercent, closeTo(20.0, 0.01));
      expect(report.topExpenseCategories.first.category, 'Vivienda');
      expect(report.pendingObligationsCount, 1);
      expect(report.pendingObligationsAmount, 100);

      final rendered = AiReportTemplates.renderMonthlyReport(report);
      expect(rendered, contains('Informe Financiero Mensual'));
      expect(rendered, contains('Vivienda'));
      expect(rendered, contains('Conclusión y Recomendación'));
    });
  });
}
