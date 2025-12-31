import 'package:hive/hive.dart';
import 'dart:convert';
import 'package:finazaap/data/credit_card_calculator.dart';

part 'responsibility.g.dart';

@HiveType(typeId: 2)
class Responsibility extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String? name;

  @HiveField(2)
  double? amount;

  @HiveField(3)
  int? dueDay; // 1-31

  @HiveField(4)
  String? category; // servicio, membresía, cuota_manejo, préstamo, vivienda, seguros, educación, transporte, ahorro, legal, salud, impuestos, mascotas, otros

  @HiveField(5)
  String? frequency; // mensual, bimestral, trimestral, anual

  @HiveField(6)
  bool? isPaid;

  @HiveField(7)
  DateTime? lastPaymentDate;

  @HiveField(8)
  int? iconCode;

  // Para tarjetas de crédito y préstamos detallados
  @HiveField(9)
  double? cardLimit;

  @HiveField(10)
  double? cardBalance;

  @HiveField(11)
  double? minimumPayment;

  @HiveField(12)
  int? cutoffDay;

  @HiveField(13)
  int? paymentDay;

  @HiveField(14)
  double? interestRate;

  @HiveField(15)
  int? installments;

  @HiveField(16)
  List<String>? installmentPlansJson; // Store as JSON strings

  @HiveField(17)
  double? paidAmountThisMonth; // Monto pagado en el ciclo actual

  @HiveField(18)
  int? lastPaymentMonth; // Mes del último ciclo de pago (para resetear paidAmountThisMonth)

  @HiveField(19)
  int? lastPaymentYear; // Año del último ciclo de pago

  Responsibility({
    this.id,
    this.name,
    this.amount,
    this.dueDay,
    this.category,
    this.frequency,
    this.isPaid,
    this.lastPaymentDate,
    this.iconCode = 0xe3a6,
    this.cardLimit,
    this.cardBalance,
    this.minimumPayment,
    this.cutoffDay,
    this.paymentDay,
    this.interestRate,
    this.installments,
    this.installmentPlansJson,
    this.paidAmountThisMonth,
    this.lastPaymentMonth,
    this.lastPaymentYear,
  });

  // Getters seguros para evitar LateInitializationError y TypeErrors
  String get safeId => id ?? '';
  String get safeName => name ?? 'Sin nombre';
  double get safeAmount => amount ?? 0.0;
  int get safeDueDay => dueDay ?? 1;
  String get safeCategory => category ?? 'servicio';
  String get safeFrequency => frequency ?? 'mensual';
  bool get safeIsPaid => isPaid ?? false;
  int get safeIconCode => iconCode ?? 0xe3a6;

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS DINÁMICOS PARA TARJETAS DE CRÉDITO
  // Estos calculan los valores desde las transacciones en tiempo real
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtiene la deuda total de la tarjeta calculada dinámicamente desde transacciones.
  /// Para tarjetas de crédito, este es el valor correcto y siempre actualizado.
  double get dynamicCardBalance {
    if (safeCategory != 'tarjeta') {
      return cardBalance ?? 0.0; // Para no-tarjetas, usar el valor almacenado
    }
    return CreditCardCalculator.calculateTotalDebt(safeName);
  }
  
  /// Obtiene la cuota mensual calculada dinámicamente desde transacciones.
  /// Considera todos los planes de cuotas activos para el mes actual.
  double get dynamicMonthlyPayment {
    if (safeCategory != 'tarjeta') {
      return safeAmount; // Para no-tarjetas, usar el valor almacenado
    }
    final now = DateTime.now();
    return CreditCardCalculator.calculateMonthlyPayment(
      safeName, 
      now.month, 
      now.year, 
      cutoffDay: cutoffDay
    );
  }
  
  /// Verifica si la cuota del mes está pagada (calculado dinámicamente).
  bool get dynamicIsPaidThisMonth {
    if (safeCategory != 'tarjeta') {
      return isPaidInMonth(DateTime.now().month, DateTime.now().year);
    }
    final now = DateTime.now();
    return CreditCardCalculator.isMonthPaid(
      safeName, 
      now.month, 
      now.year, 
      cutoffDay: cutoffDay
    );
  }
  
  /// Obtiene el monto pagado este mes (dinámico).
  double get dynamicPaidThisMonth {
    if (safeCategory != 'tarjeta') {
      return paidAmountThisMonth ?? 0.0;
    }
    final now = DateTime.now();
    return CreditCardCalculator.calculatePaidInMonth(safeName, now.month, now.year);
  }

  // Calcular cuántos días faltan para vencimiento
  int getDaysUntilDue() {
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    final dDay = safeDueDay;
    
    // Crear fecha de vencimiento para este mes
    DateTime dueDate;
    try {
      dueDate = DateTime(currentYear, currentMonth, dDay);
    } catch (e) {
      // Si el día no existe en este mes (ej: 31 en febrero), usar último día del mes
      dueDate = DateTime(currentYear, currentMonth + 1, 0);
    }
    
    // Si ya pasó este mes, calcular para el próximo
    final today = DateTime(now.year, now.month, now.day);
    if (dueDate.isBefore(today)) {
      try {
        dueDate = DateTime(currentYear, currentMonth + 1, dDay);
      } catch (e) {
        dueDate = DateTime(currentYear, currentMonth + 2, 0);
      }
    }
    
    return dueDate.difference(today).inDays;
  }

  // Obtener el monto mensual equivalente según frecuencia
  double getMonthlyAmount() {
    final amt = safeAmount;
    switch (safeFrequency) {
      case 'mensual':
        return amt;
      case 'bimestral':
        return amt / 2;
      case 'trimestral':
        return amt / 3;
      case 'anual':
        return amt / 12;
      default:
        return amt;
    }
  }

  // Helper para manejar planes de cuotas
  List<Map<String, dynamic>> get installmentPlans {
    if (installmentPlansJson == null) return [];
    return installmentPlansJson!.map((str) => jsonDecode(str) as Map<String, dynamic>).toList();
  }

  void addInstallmentPlan(Map<String, dynamic> plan) {
    if (installmentPlansJson == null) installmentPlansJson = [];
    installmentPlansJson!.add(jsonEncode(plan));
  }
  
  void removeInstallmentPlan(double monthlyAmount, int months) {
    if (installmentPlansJson == null) return;
    
    // Buscar el último plan que coincida (LIFO)
    int indexToRemove = -1;
    final plans = installmentPlans;
    
    for (int i = plans.length - 1; i >= 0; i--) {
      // Comparación aproximada para doubles
      double planAmount = plans[i]['amount'] ?? 0.0;
      int planMonths = plans[i]['months'] ?? 1;
      
      if ((planAmount - monthlyAmount).abs() < 0.01 && planMonths == months) {
        indexToRemove = i;
        break;
      }
    }
    
    if (indexToRemove != -1) {
      installmentPlansJson!.removeAt(indexToRemove);
    }
  }

  // Abono a capital: recálculo proporcional de cuotas
  void applyCapitalPayment(double capitalAmount) {
    if (capitalAmount <= 0) return;

    final currentBalance = cardBalance ?? 0.0;
    // Si el abono es mayor al saldo total, limpiamos todo
    if (capitalAmount >= currentBalance - 0.01) {
       amount = 0;
       installmentPlansJson = [];
       return;
    }

    // Calcular factor de reducción
    // Factor = (DeudaTotal - Abono) / DeudaTotal
    // Ej: Deuda 1M, Abono 500k -> Factor 0.5. Las cuotas bajan a la mitad.
    final reductionFactor = (currentBalance - capitalAmount) / currentBalance;
    
    // 1. Reducir cuotas de planes activos
    if (installmentPlansJson != null && installmentPlansJson!.isNotEmpty) {
      final plans = installmentPlans;
      List<String> updatedPlans = [];
      
      for (var plan in plans) {
        double oldAmount = (plan['amount'] as num).toDouble();
        double newAmount = oldAmount * reductionFactor;
        plan['amount'] = newAmount;
        updatedPlans.add(jsonEncode(plan));
      }
      installmentPlansJson = updatedPlans;
    }

    // 2. Reducir 'amount' base (Legacy debt monthly payment)
    if (amount != null) {
      amount = amount! * reductionFactor;
    }
  }

  // Obtener monto para una fecha específica (Calendario)
  // Para tarjetas de crédito: CALCULA DINÁMICAMENTE desde transacciones
  double getAmountForDate(int month, int year) {
    // Para responsabilidades que NO son tarjetas, usar lógica legacy
    if (safeCategory != 'tarjeta') return getMonthlyAmount();
    
    // ═══════════════════════════════════════════════════════════════════
    // TARJETAS DE CRÉDITO: CÁLCULO DINÁMICO DESDE TRANSACCIONES
    // El CreditCardCalculator es la ÚNICA fuente de verdad
    // ═══════════════════════════════════════════════════════════════════
    
    // 1. Calcular la cuota mensual para el mes/año solicitado
    double monthlyPayment = CreditCardCalculator.calculateMonthlyPayment(
      safeName, 
      month, 
      year, 
      cutoffDay: cutoffDay
    );
    
    // 2. Si hay cuota mensual calculada, devolverla
    if (monthlyPayment > 0) {
      return monthlyPayment;
    }
    
    // 3. Si no hay cuotas activas para ese mes, devolver la deuda total
    // (Esto maneja el caso de deudas de cuota única o ya finalizadas)
    double totalDebt = CreditCardCalculator.calculateTotalDebt(safeName);
    return totalDebt;
  }

  // Determinar urgencia (para color coding)
  String getUrgencyLevel() {
    if (safeIsPaid) return 'paid';
    
    final daysLeft = getDaysUntilDue();
    if (daysLeft <= 2) return 'urgent'; // Rojo
    if (daysLeft <= 7) return 'upcoming'; // Amarillo
    return 'normal'; // Gris
  }

  // Verificar si está pagado en un mes específico
  bool isPaidInMonth(int month, int year) {
    // CASO 1: Tiene fecha de último pago que coincide con el mes/año consultado
    if (lastPaymentDate != null && lastPaymentDate!.month == month && lastPaymentDate!.year == year) {
      return true;
    }
    
    // CASO 2: TARJETAS DE CRÉDITO - Lógica especial
    if (safeCategory == 'tarjeta') {
      // Si no hay deuda, está al día
      if (cardBalance != null && cardBalance! <= 0) return true;
      
      // Si no hay cuota que pagar este mes, está al día
      final expectedQuota = getAmountForDate(month, year);
      if (expectedQuota <= 0) return true;
      
      // Verificar pagos parciales del ciclo actual
      if (lastPaymentMonth == month && lastPaymentYear == year) {
        final paid = paidAmountThisMonth ?? 0.0;
        // Se considera pagado si se cubrió al menos 95% de la cuota (margen para redondeos)
        if (paid >= expectedQuota * 0.95) return true;
      }
    }

    return false;
  }
  
  // Obtener monto pagado en el ciclo actual
  double getPaidAmountInCycle(int month, int year) {
    if (lastPaymentMonth == month && lastPaymentYear == year) {
      return paidAmountThisMonth ?? 0.0;
    }
    return 0.0;
  }
  
  // Obtener monto pendiente por pagar este ciclo
  double getRemainingQuota(int month, int year) {
    final expected = getAmountForDate(month, year);
    final paid = getPaidAmountInCycle(month, year);
    return (expected - paid).clamp(0.0, double.infinity);
  }
}
