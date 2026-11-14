import 'package:hive/hive.dart';
import 'dart:convert';
import 'dart:math';
import 'package:finazaap/data/credit_card_calculator.dart';
import 'package:finazaap/utils/currency_helper.dart';

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

  @HiveField(20)
  List<DateTime>? paymentDates; // Historial de fechas pagadas (para diario/semanal)

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
    this.paymentDates,
  });

  // Getters seguros para evitar LateInitializationError y TypeErrors
  String get safeId => id ?? '';
  String get safeName => name ?? 'Sin nombre';
  double get safeAmount => amount ?? 0.0;
  int get safeDueDay => dueDay ?? 1;
  String get safeCategory => category ?? 'servicio';
  String get safeFrequency => frequency ?? 'mensual';
  bool get safeIsPaid {
    if (safeFrequency == 'diario') {
       if (lastPaymentDate == null) return false;
       final now = DateTime.now();
       return lastPaymentDate!.year == now.year && 
              lastPaymentDate!.month == now.month && 
              lastPaymentDate!.day == now.day;
    }
    if (safeFrequency == 'semanal') {
       if (lastPaymentDate == null) return false;
       final now = DateTime.now();
       final diff = now.difference(lastPaymentDate!).inDays;
       if (diff > 7) return false;
       final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
       final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
       return !lastPaymentDate!.isBefore(startOfWeekDate);
    }
    return isPaid ?? false;
  }
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
    return getDynamicQuota(now.month, now.year);
  }

  /// Compara si [paid] cubre [expected] a la precisión decimal de la moneda activa.
  /// Nunca liquida deuda cero (expected <= 0) ni usa porcentajes arbitrarios.
  static bool isAmountCovered(double paid, double expected) {
    final decimals = CurrencyHelper.getFormatter().maximumFractionDigits;
    final scale = pow(10, decimals).toDouble();
    final expectedUnits = (expected * scale).round();
    if (expectedUnits <= 0) return false;
    final paidUnits = (paid * scale).round();
    return paidUnits >= expectedUnits;
  }

  /// Calcula la cuota dinámica para un mes y año específicos
  double getDynamicQuota(int month, int year) {
    if (safeCategory != 'tarjeta') {
      return safeAmount;
    }
    if (CreditCardCalculator.calculateTotalDebt(safeName) <= 0) {
      return 0.0;
    }
    // FIX: Priorizar minimumPayment (Cuota Fija Manual) si existe
    if (minimumPayment != null && minimumPayment! > 0) {
      return minimumPayment!;
    }
    
    return CreditCardCalculator.calculateMonthlyPayment(
      safeName, 
      month, 
      year, 
      cutoffDay: cutoffDay,
      interestRate: interestRate,
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
    final today = DateTime(now.year, now.month, now.day);
    
    // 1. DIARIO
    if (safeFrequency == 'diario') {
       bool paidToday = lastPaymentDate != null && 
           lastPaymentDate!.day == now.day &&
           lastPaymentDate!.month == now.month &&
           lastPaymentDate!.year == now.year;
       return paidToday ? 1 : 0;
    }
    
    // 2. SEMANAL
    if (safeFrequency == 'semanal') {
       // dueDay se asume 1 (Lun) a 7 (Dom)
       int targetWeekday = safeDueDay; 
       int daysToAdd = (targetWeekday - now.weekday + 7) % 7;
       
       if (daysToAdd == 0) {
          // Es hoy. Si ya pagó, es la próxima semana.
          bool paidToday = lastPaymentDate != null && 
             lastPaymentDate!.day == now.day &&
             lastPaymentDate!.month == now.month &&
             lastPaymentDate!.year == now.year;
          if (paidToday) daysToAdd = 7;
       }
       return daysToAdd;
    }
    
    // 3. QUINCENAL
    if (safeFrequency == 'quincenal') {
       int d1 = safeDueDay;
       int d2 = d1 + 15;
       
       // Generar candidatos para este mes y el próximo (ajustando días al fin de mes, ej. febrero)
       List<DateTime> candidates = [];
       for (int m = 0; m <= 1; m++) {
         final base = DateTime(now.year, now.month + m, 1);
         final lastDay = DateTime(base.year, base.month + 1, 0).day;
         candidates.add(DateTime(base.year, base.month, d1.clamp(1, lastDay)));
         candidates.add(DateTime(base.year, base.month, d2.clamp(1, lastDay)));
       }
       candidates.sort();
       
       // Buscar el primero que sea Hoy o después
       for (var d in candidates) {
         // Normalizar a medianoche
         final dDate = DateTime(d.year, d.month, d.day);
         if (dDate.isBefore(today)) continue;
         
         if (dDate.isAtSameMomentAs(today)) {
             // Es hoy. Si ya pagó, buscar el siguiente.
            bool paidToday = lastPaymentDate != null && 
               lastPaymentDate!.day == now.day &&
               lastPaymentDate!.month == now.month &&
               lastPaymentDate!.year == now.year;
            if (paidToday) continue; 
            return 0;
         }
         return dDate.difference(today).inDays;
       }
       return 15; // Fallback
    }

    // 4. MENSUAL / OTROS (Lógica original con ajuste real de fin de mes en febrero)
    final currentMonth = now.month;
    final currentYear = now.year;

    DateTime dueDate = getDueDateForMonth(currentMonth, currentYear);

    // Si ya pasó este mes, calcular para el próximo
    if (dueDate.isBefore(today)) {
      dueDate = getDueDateForMonth(currentMonth + 1, currentYear);
    }

    // Si ya está pagado en este ciclo mensual, mostrar vencimiento del próximo mes
    if (isPaidInMonth(now.month, now.year) && dueDate.month == now.month) {
      dueDate = getDueDateForMonth(currentMonth + 1, currentYear);
    }

    return dueDate.difference(today).inDays;
  }

  /// Retorna la fecha de vencimiento de [month]/[year] ajustando días > último día del mes (ej. 31 en febrero).
  DateTime getDueDateForMonth(int month, int year) {
    final normalized = DateTime(year, month, 1);
    final lastDay = DateTime(normalized.year, normalized.month + 1, 0).day;
    return DateTime(normalized.year, normalized.month, safeDueDay.clamp(1, lastDay));
  }

  // Obtener el monto mensual equivalente según frecuencia
  double getMonthlyAmount() {
    final amt = safeAmount;
    switch (safeFrequency) {
      case 'diario':
        return amt * 30;
      case 'semanal':
        return amt * 4;
      case 'quincenal':
        return amt * 2;
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

  // Obtener el monto anual equivalente según frecuencia
  double getAnnualAmount() {
    final amt = safeAmount;
    switch (safeFrequency) {
      case 'diario':
        return amt * 365;
      case 'semanal':
        return amt * 52;
      case 'quincenal':
        return amt * 24;
      case 'mensual':
        return amt * 12;
      case 'bimestral':
        return amt * 6;
      case 'trimestral':
        return amt * 4;
      case 'anual':
        return amt;
      default:
        return amt * 12;
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
    // Para responsabilidades que NO son tarjetas, usar lógica legado
    if (safeCategory != 'tarjeta' && safeCategory != 'préstamo') return getMonthlyAmount();
    if (safeCategory == 'tarjeta') return getDynamicQuota(month, year);
    
    // CASO CORRECTIVO: Si tiene un pago mínimo definido, esa es la "cuota" prioritaria
    if (minimumPayment != null && minimumPayment! > 0) {
      return minimumPayment!;
    }

    // Para Tarjetas y Préstamos, usar la misma lógica que la visualización de cuota
    return getDynamicQuota(month, year);
  }

  // Determinar urgencia (para color coding)
  String getUrgencyLevel() {
    // Usar chequeo dinámico para el estado "Pagado"
    if (safeCategory == 'tarjeta') {
      if (CreditCardCalculator.isMonthPaid(safeName, DateTime.now().month, DateTime.now().year, cutoffDay: cutoffDay)) {
        return 'paid';
      }
    } else if (safeIsPaid) {
      return 'paid';
    }
    
    final daysLeft = getDaysUntilDue();
    if (daysLeft <= 2) return 'urgent'; // Rojo
    if (daysLeft <= 7) return 'upcoming'; // Amarillo
    return 'normal'; // Gris
  }

  // Verificar si está pagado en un mes específico
  bool isPaidInMonth(int month, int year) {
    final List<DateTime> recordedDates = <DateTime>[
      if (paymentDates != null) ...paymentDates!,
      if (lastPaymentDate != null) lastPaymentDate!,
    ];

    // 1. Frecuencias multi-mes: cubren N meses desde el mes de pago registrado
    final int? multiMonthSpan = switch (safeFrequency) {
      'bimestral' => 2,
      'trimestral' => 3,
      'anual' => 12,
      _ => null,
    };
    if (multiMonthSpan != null) {
      for (final p in recordedDates) {
        final diffMonths = (year - p.year) * 12 + (month - p.month);
        if (diffMonths >= 0 && diffMonths < multiMonthSpan) {
          if (lastPaymentMonth == p.month &&
              lastPaymentYear == p.year &&
              paidAmountThisMonth != null &&
              safeAmount > 0 &&
              !isAmountCovered(paidAmountThisMonth!, safeAmount)) {
            continue;
          }
          return true;
        }
      }
      return false;
    }

    // 2. Frecuencias cortas (diario / semanal / quincenal): consultar el período pedido
    if (safeFrequency == 'diario' || safeFrequency == 'semanal' || safeFrequency == 'quincenal') {
      final int distinctDaysInMonth = recordedDates
          .where((p) => p.year == year && p.month == month)
          .map((p) => p.day)
          .toSet()
          .length;

      final int requiredOccurrences = switch (safeFrequency) {
        'diario' => DateTime(year, month + 1, 0).day,
        'semanal' => 4,
        'quincenal' => 2,
        _ => 1,
      };
      if (distinctDaysInMonth >= requiredOccurrences) {
        return true;
      }

      if (lastPaymentMonth == month &&
          lastPaymentYear == year &&
          paidAmountThisMonth != null &&
          isAmountCovered(paidAmountThisMonth!, getMonthlyAmount())) {
        return true;
      }
      return false;
    }

    // 3. Tarjetas de crédito: dinámica desde transacciones o pago completo registrado en el mes
    if (safeCategory == 'tarjeta') {
      if (lastPaymentDate != null && lastPaymentDate!.month == month && lastPaymentDate!.year == year) {
        return true;
      }
      return CreditCardCalculator.isMonthPaid(
        safeName,
        month,
        year,
        cutoffDay: cutoffDay,
      );
    }

    // 4. Mensual / otros
    final bool hasDateInMonth = recordedDates.any((p) => p.year == year && p.month == month);
    if (!hasDateInMonth) {
      return false;
    }
    if (lastPaymentMonth == month && lastPaymentYear == year && paidAmountThisMonth != null) {
      final expected = getAmountForDate(month, year);
      if (expected > 0) {
        return isAmountCovered(paidAmountThisMonth!, expected);
      }
    }
    return true;
  }

  // Verificar si está pagado en una fecha específica (incluyendo Día)
  bool isPaidOnDate(DateTime date) {
    
    // 1. Verificar en historial de fechas (lo más preciso)
    if (paymentDates != null) {
      // Normalizar fecha input
      final target = DateTime(date.year, date.month, date.day);
      
      // Buscar coincidencia exacta
      for (var p in paymentDates!) {
        if (p.year == target.year && p.month == target.month && p.day == target.day) {
          return true;
        }
      }
    }
    
    // 2. Fallback a lógica legacy si no hay historial
    if (safeFrequency == 'mensual' || safeFrequency == 'bimestral' || safeFrequency == 'trimestral' || safeFrequency == 'anual') {
      return isPaidInMonth(date.month, date.year);
    }
    
    if (safeFrequency == 'semanal') {
      if (lastPaymentDate == null) return false;
      final target = DateTime(date.year, date.month, date.day);
      final startOfWeek = target.subtract(Duration(days: target.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      final last = DateTime(lastPaymentDate!.year, lastPaymentDate!.month, lastPaymentDate!.day);
      return !last.isBefore(startOfWeek) && !last.isAfter(endOfWeek);
    }

    if (safeFrequency == 'quincenal') {
      if (lastPaymentDate == null) return false;
      if (lastPaymentDate!.year != date.year || lastPaymentDate!.month != date.month) return false;
      return (lastPaymentDate!.day <= 15) == (date.day <= 15);
    }

    // 3. Fallback Legacy para diario (solo mira última fecha)
    if (safeFrequency == 'diario') {
       if (lastPaymentDate == null) return false;
       return lastPaymentDate!.year == date.year && 
              lastPaymentDate!.month == date.month && 
              lastPaymentDate!.day == date.day;
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
