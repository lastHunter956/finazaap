import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'dart:convert';
import 'package:hive/hive.dart';

class ResponsibilityService {
  static const String _boxName = 'responsibilities';
  static Box<Responsibility>? _box;

  // Inicializar el box
  static Future<void> init() async {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox<Responsibility>(_boxName);
    } else {
      _box = Hive.box<Responsibility>(_boxName);
    }
  }

  // Obtener el box
  static Box<Responsibility> getBox() {
    if (_box == null || !_box!.isOpen) {
      throw Exception('Responsibility box not initialized. Call ResponsibilityService.init() first.');
    }
    return _box!;
  }

  // Obtener todas las responsabilidades
  static List<Responsibility> getAllResponsibilities() {
    final box = getBox();
    return box.values.toList();
  }

  // Obtener responsabilidades urgentes (próximos 7 días)
  static List<Responsibility> getUrgentPayments({int? month, int? year}) {
    final all = getAllResponsibilities();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;

    return all.where((r) {
      if (r.isPaidInMonth(targetMonth, targetYear)) return false;
      final daysLeft = r.getDaysUntilDue();
      // Solo mostrar urgentes si son para el mes actual o cercano
      return daysLeft >= 0 && daysLeft <= 7;
    }).toList()
      ..sort((a, b) => a.getDaysUntilDue().compareTo(b.getDaysUntilDue()));
  }

  // Filtrar por categoría
  static List<Responsibility> getByCategory(String category) {
    final all = getAllResponsibilities();
    return all.where((r) => r.safeCategory == category).toList();
  }

  // Marcar como pagado/no pagado
  // Marcar como pagado/no pagado
  // Marcar como pagado/no pagado
  // Marcar como pagado/no pagado
  static Future<void> togglePaidStatus(String id, {int? month, int? year}) async {
    final box = getBox();
    try {
      final index = box.values.toList().indexWhere((r) => r.safeId == id);
      if (index == -1) {
        print('⚠️ Responsibility not found for toggle: $id');
        return;
      }
      
      // Use getAt to get the object
      final responsibility = box.getAt(index);
      if (responsibility == null) return;
      
      final wasAlreadyPaid = responsibility.safeIsPaid;
      final willBePaid = !wasAlreadyPaid;
      final now = DateTime.now();
      final targetMonth = month ?? now.month;
      final targetYear = year ?? now.year;
      
      // Construir fecha de pago relativa al mes objetivo
      // Si estamos pagando "Enero", la fecha debe ser Enero (para consistencia)
      // Usamos el día actual o el 1ro si el día actual no existe en ese mes
      DateTime paymentDate;
      try {
        paymentDate = DateTime(targetYear, targetMonth, now.day);
      } catch (e) {
        paymentDate = DateTime(targetYear, targetMonth + 1, 0); // Último día del mes
      }
      
      print('🔄 Toggling $id: $wasAlreadyPaid -> $willBePaid for $targetMonth/$targetYear');

      // Crear copia explícita para asegurar invalidación
      final updated = Responsibility(
        id: responsibility.safeId,
        name: responsibility.safeName,
        amount: responsibility.safeAmount,
        dueDay: responsibility.safeDueDay,
        category: responsibility.safeCategory,
        frequency: responsibility.safeFrequency,
        iconCode: responsibility.safeIconCode,
        isPaid: willBePaid,
        // CLAVE: Si marcamos como pagado, usar la fecha del mes OBJETIVO
        lastPaymentDate: willBePaid ? paymentDate : null,
        cardLimit: responsibility.cardLimit,
        cardBalance: responsibility.cardBalance,
        interestRate: responsibility.interestRate,
        installments: responsibility.installments,
        cutoffDay: responsibility.cutoffDay,
        installmentPlansJson: responsibility.installmentPlansJson,
        minimumPayment: responsibility.minimumPayment,
        paymentDay: responsibility.paymentDay,
        // Tracking del ciclo de pago
        paidAmountThisMonth: willBePaid 
            ? responsibility.getAmountForDate(targetMonth, targetYear)
            : 0.0,
        lastPaymentMonth: targetMonth,
        lastPaymentYear: targetYear,
      );
      
      // Usar putAt para forzar la actualización en Hive
      await box.putAt(index, updated);
      print('✅ Toggled successfully. New state: isPaid=${updated.isPaid}, Date=${updated.lastPaymentDate}');
      
    } catch (e) {
      print('❌ Error updating paid status: $e');
    }
  }

  // Calcular total mensual
  static double calculateMonthlyTotal() {
    final all = getAllResponsibilities();
    return all.fold(0.0, (sum, r) => sum + r.getMonthlyAmount());
  }

  // Calcular pagado vs pendiente en un mes específico
  static Map<String, double> calculatePaidVsPending({int? month, int? year}) {
    final all = getAllResponsibilities();
    final now = DateTime.now();
    final targetMonth = month ?? now.month;
    final targetYear = year ?? now.year;
    
    double paid = 0.0;
    double pending = 0.0;

    for (var r in all) {
      final monthlyAmount = r.getMonthlyAmount();
      if (r.isPaidInMonth(targetMonth, targetYear)) {
        paid += monthlyAmount;
      } else {
        pending += monthlyAmount;
      }
    }

    return {'paid': paid, 'pending': pending};
  }

  // Agregar nueva responsabilidad
  static Future<void> addResponsibility(Responsibility responsibility) async {
    final box = getBox();
    responsibility.id = const Uuid().v4();
    await box.add(responsibility);
  }

  // Actualizar responsabilidad existente
  static Future<void> updateResponsibility(Responsibility responsibility) async {
    final box = getBox();
    final index = box.values.toList().indexWhere((r) => r.safeId == responsibility.safeId);
    if (index == -1) {
      // Si no existe, agregarla
      await box.add(responsibility);
    } else {
      // Actualizar en el índice correcto
      await box.putAt(index, responsibility);
    }
  }

  // Eliminar responsabilidad
  static Future<void> deleteResponsibility(String id) async {
    final box = getBox();
    final responsibility = box.values.firstWhere((r) => r.safeId == id);
    await responsibility.delete();
  }

  // Resetear estados de pago al inicio de mes (llamar manualmente o con scheduler)
  static Future<void> resetMonthlyPayments() async {
    final box = getBox();
    final now = DateTime.now();
    
    for (var responsibility in box.values) {
      // Si fue pagado el mes pasado, resetear
      if (responsibility.safeIsPaid && responsibility.lastPaymentDate != null) {
        final lastPayment = responsibility.lastPaymentDate!;
        if (lastPayment.month != now.month || lastPayment.year != now.year) {
          responsibility.isPaid = false;
          await responsibility.save();
        }
      }
    }
  }

  // --- Crédito / Tarjeta Automation Logic ---

  // Crear responsabilidad automáticamente desde una cuenta
  static Future<void> createFromAccount(AccountItem account) async {
    // Verificar si ya existe una responsabilidad con ese nombre
    final existing = getAllResponsibilities().any((r) => r.safeName == account.title);
    if (existing) return;

    // Calcular el balance inicial (deuda)
    // En las tarjetas, el "balance" que viene del AccountItem suele ser el CUPO TOTAL o DISPONIBLE
    // Si queremos tracking de deuda, necesitamos saber cuánto se ha usado.
    // Asumiremos inicialmente que: Deuda = Limite - Disponible
    // Pero si el usuario ingresó "Cupo Total" y "Saldo Inicial" en el diálogo, 
    // balanceController se usó para 'balance' (que en TC podría ser cupo o disponible).
    // Basado en el diálogo: "Saldo (derecha) -> Cupo total". 
    // Entonces asumimos deuda 0 al inicio si es una cuenta nueva.
    
    // Convertir string balance a double
    double limit = double.tryParse(account.creditLimit ?? account.balance) ?? 0.0;
    
    // Deuda inicial: 0 (o calcular si hay diferencia entre límite y disponible, pero el diálogo solo pide uno)
    double initialDebt = 0.0; 

    await addResponsibility(Responsibility(
      id: const Uuid().v4(),
      name: account.title,
      amount: initialDebt, // La "amount" en responsabilidad de TC representa la DEUDA ACTUAL
      dueDay: account.paymentDay ?? 1,
      category: 'tarjeta',
      frequency: 'mensual',
      isPaid: true, // Si deuda es 0, está "pagada"
      iconCode: account.icon.codePoint,
      cardLimit: limit,
      cardBalance: initialDebt, // Deuda actual
      cutoffDay: account.cutoffDay,
      paymentDay: account.paymentDay,
      interestRate: account.interestRate,
      installments: 1, // Por defecto
    ));
    print('✅ Responsabilidad creada para tarjeta: ${account.title}');
  }

  // Procesar aumento de deuda (Compra con tarjeta)
  static Future<void> processDebtIncrease(String accountName, double amount, [int installments = 1, bool isInterestFree = true, DateTime? transactionDate]) async {
    final box = getBox();
    try {
      // Usar índice para putAt
      final index = box.values.toList().indexWhere((r) => r.safeName == accountName && r.safeCategory == 'tarjeta');
      if (index == -1) {
        print('⚠️ [DEBT_INCREASE] No se encontró responsabilidad para tarjeta: $accountName');
        return;
      }
      
      final responsibility = box.getAt(index);
      if (responsibility == null) {
        print('⚠️ [DEBT_INCREASE] Responsabilidad null en índice $index');
        return;
      }
      
      print('📊 [DEBT_INCREASE] ANTES: $accountName - Deuda: ${responsibility.cardBalance}, Mensual: ${responsibility.safeAmount}');
      
      // 1. Aumentar Deuda Total (Principal)
      double currentDebt = responsibility.cardBalance ?? responsibility.safeAmount; 
      if (responsibility.cardBalance == null) currentDebt = responsibility.safeAmount; 
      
      double newDebt = currentDebt + amount;
      
      // 2. Calcular Cuota Mensual a sumar
      double monthlyIncrease;
      
      if (isInterestFree || installments == 1) {
        monthlyIncrease = amount / installments;
      } else {
        double? rate = responsibility.interestRate;
        if (rate == null || rate == 0) {
           monthlyIncrease = amount / installments;
        } else {
           double i = rate / 100; 
           monthlyIncrease = (amount * i) / (1 - pow(1 + i, -installments));
        }
      }
      
      double currentMonthlyPayment = responsibility.safeAmount;
      double newMonthlyPayment = currentMonthlyPayment + monthlyIncrease;
      
      // LOGICA FECHA DE CORTE
      final txDate = transactionDate ?? DateTime.now();
      DateTime planStartDate = txDate;
      bool isPostCutoff = false;
      
      if (responsibility.cutoffDay != null && txDate.day > responsibility.cutoffDay!) {
          planStartDate = DateTime(planStartDate.year, planStartDate.month + 1, 1);
          isPostCutoff = true;
          newMonthlyPayment = currentMonthlyPayment; // No sumar al mes actual
          print('📅 [DEBT_INCREASE] Compra post-corte. Cuota diferida al próximo mes.');
      }
      
      // Copiar planes existentes y agregar el nuevo
      List<String>? updatedPlans = responsibility.installmentPlansJson != null 
          ? List<String>.from(responsibility.installmentPlansJson!) 
          : [];
      
      final newPlan = jsonEncode({
        'amount': monthlyIncrease,
        'months': installments,
        'total': amount,
        'startDate': planStartDate.toIso8601String(),
        'description': 'Compra credit', 
      });
      updatedPlans.add(newPlan);
      
      // Crear nueva responsabilidad con valores actualizados
      final updated = Responsibility(
        id: responsibility.safeId,
        name: responsibility.safeName,
        amount: newMonthlyPayment,
        dueDay: responsibility.safeDueDay,
        category: responsibility.safeCategory,
        frequency: responsibility.safeFrequency,
        iconCode: responsibility.safeIconCode,
        isPaid: false,
        lastPaymentDate: null, // Nueva compra = ya no pagado
        cardLimit: responsibility.cardLimit,
        cardBalance: newDebt,
        interestRate: responsibility.interestRate,
        installments: responsibility.installments,
        cutoffDay: responsibility.cutoffDay,
        installmentPlansJson: updatedPlans,
        minimumPayment: responsibility.minimumPayment,
        paymentDay: responsibility.paymentDay,
        paidAmountThisMonth: responsibility.paidAmountThisMonth,
        lastPaymentMonth: responsibility.lastPaymentMonth,
        lastPaymentYear: responsibility.lastPaymentYear,
      );
      
      await box.putAt(index, updated);
      print('✅ [DEBT_INCREASE] DESPUÉS: $accountName - Deuda: $newDebt, Mensual: $newMonthlyPayment (Compra: \$$amount, Cuotas: $installments)');
    } catch (e) {
      print('⚠️ [DEBT_INCREASE] Error: $e');
    }
  }


  // Revertir una compra (Eliminar transacción de gasto)
  static Future<void> processDebtReversal(String accountName, double amount, DateTime transactionDate, [int installments = 1, bool isInterestFree = true]) async {
    final box = getBox();
    try {
      // Usar índice para putAt
      final index = box.values.toList().indexWhere((r) => r.safeName == accountName && r.safeCategory == 'tarjeta');
      if (index == -1) {
        print('⚠️ [DEBT_REVERSAL] No se encontró responsabilidad para tarjeta: $accountName');
        return;
      }
      
      final responsibility = box.getAt(index);
      if (responsibility == null) {
        print('⚠️ [DEBT_REVERSAL] Responsabilidad null en índice $index');
        return;
      }
      
      print('📊 [DEBT_REVERSAL] ANTES: $accountName - Deuda: ${responsibility.cardBalance}, Mensual: ${responsibility.safeAmount}');
      
      // 1. Disminuir Deuda Total (Capital)
      double currentDebt = responsibility.cardBalance ?? 0.0; 
      double newDebt = currentDebt - amount;
      if (newDebt < 0) newDebt = 0;
      
      // 2. Calcular monto mensual a restar
      double monthlyDecrease;
      
      if (isInterestFree || installments == 1) {
        monthlyDecrease = amount / installments;
      } else {
        double? rate = responsibility.interestRate;
        if (rate == null || rate == 0) {
           monthlyDecrease = amount / installments; 
        } else {
           double i = rate / 100; 
           monthlyDecrease = (amount * i) / (1 - pow(1 + i, -installments));
        }
      }
      
      double currentMonthlyPayment = responsibility.safeAmount;
      double newMonthlyPayment = currentMonthlyPayment;
      
      // LOGICA FECHA DE CORTE (REVERSAL)
      bool wasAffectingCurrentMonth = true;
      
      if (responsibility.cutoffDay != null && transactionDate.day > responsibility.cutoffDay!) {
          DateTime planStartDate = DateTime(transactionDate.year, transactionDate.month + 1, 1);
          final now = DateTime.now();
          final startMonth = DateTime(planStartDate.year, planStartDate.month);
          final currentMonth = DateTime(now.year, now.month);
          
          if (startMonth.isAfter(currentMonth)) {
             wasAffectingCurrentMonth = false;
             print('📅 [DEBT_REVERSAL] Compra diferida futura. No descontar de mensualidad actual.');
          }
      }
      
      if (wasAffectingCurrentMonth) {
          newMonthlyPayment = currentMonthlyPayment - monthlyDecrease;
          if (newMonthlyPayment < 0) newMonthlyPayment = 0;
      }
      
      // Remover plan de cuotas de la lista
      List<String>? updatedPlans = responsibility.installmentPlansJson != null 
          ? List<String>.from(responsibility.installmentPlansJson!) 
          : [];
      
      // Buscar y remover el plan que coincida (LIFO - último primero)
      for (int i = updatedPlans.length - 1; i >= 0; i--) {
        try {
          final plan = jsonDecode(updatedPlans[i]) as Map<String, dynamic>;
          double planAmount = (plan['amount'] as num?)?.toDouble() ?? 0.0;
          int planMonths = (plan['months'] as num?)?.toInt() ?? 1;
          
          if ((planAmount - monthlyDecrease).abs() < 0.01 && planMonths == installments) {
            updatedPlans.removeAt(i);
            print('📋 [DEBT_REVERSAL] Plan de cuotas removido: \$${planAmount.toStringAsFixed(2)} x $planMonths meses');
            break;
          }
        } catch (e) {
          // Plan malformado, ignorar
        }
      }
      
      // Crear nueva responsabilidad con valores actualizados
      final updated = Responsibility(
        id: responsibility.safeId,
        name: responsibility.safeName,
        amount: newMonthlyPayment,
        dueDay: responsibility.safeDueDay,
        category: responsibility.safeCategory,
        frequency: responsibility.safeFrequency,
        iconCode: responsibility.safeIconCode,
        isPaid: newDebt <= 0,
        lastPaymentDate: responsibility.lastPaymentDate,
        cardLimit: responsibility.cardLimit,
        cardBalance: newDebt,
        interestRate: responsibility.interestRate,
        installments: responsibility.installments,
        cutoffDay: responsibility.cutoffDay,
        installmentPlansJson: updatedPlans,
        minimumPayment: responsibility.minimumPayment,
        paymentDay: responsibility.paymentDay,
        paidAmountThisMonth: responsibility.paidAmountThisMonth,
        lastPaymentMonth: responsibility.lastPaymentMonth,
        lastPaymentYear: responsibility.lastPaymentYear,
      );
      
      await box.putAt(index, updated);
      print('✅ [DEBT_REVERSAL] DESPUÉS: $accountName - Deuda: $newDebt, Mensual: $newMonthlyPayment (Revertido: \$$amount)');
    } catch (e) {
      print('⚠️ [DEBT_REVERSAL] Error: $e');
    }
  }

  // Procesar pago/abono (Pagar la tarjeta)
  // Tipos de pago:
  // - Pago parcial: Abona al ciclo actual pero no cubre la cuota completa
  // - Pago de cuota: Cubre la cuota del mes (marca como pagado)
  // - Pago total: Limpia toda la deuda
  // - Abono a capital: Pago extra que reduce cuotas futuras
  static Future<void> processDebtPayment(String accountName, double amount, {DateTime? paymentDate}) async {
    final box = getBox();
    try {
      final index = box.values.toList().indexWhere((r) => r.safeName == accountName && r.safeCategory == 'tarjeta');
      if (index == -1) {
        print('⚠️ No se encontró responsabilidad para tarjeta: $accountName');
        return;
      }
      
      final responsibility = box.getAt(index);
      if (responsibility == null) return;
      
      final now = paymentDate ?? DateTime.now();
      final currentMonth = now.month;
      final currentYear = now.year;
      
      // 1. Calcular deuda y cuota esperada
      double currentDebt = responsibility.cardBalance ?? responsibility.safeAmount;
      double expectedQuota = responsibility.getAmountForDate(currentMonth, currentYear);
      
      // 2. Verificar si es un nuevo ciclo de pago
      double previousPaidInCycle = 0.0;
      if (responsibility.lastPaymentMonth == currentMonth && responsibility.lastPaymentYear == currentYear) {
        previousPaidInCycle = responsibility.paidAmountThisMonth ?? 0.0;
      }
      
      // 3. Acumular el pago al ciclo actual
      double totalPaidInCycle = previousPaidInCycle + amount;
      
      // 4. Reducir la deuda total (capital)
      double newDebt = currentDebt - amount;
      if (newDebt < 0) newDebt = 0;
      
      // 5. Detectar abono a capital (pago extra)
      double capitalPayment = 0.0;
      if (totalPaidInCycle > expectedQuota && expectedQuota > 0) {
        capitalPayment = totalPaidInCycle - expectedQuota;
        // Si hay capital extra, recalcular las cuotas futuras
        if (capitalPayment > 0.01) {
          responsibility.applyCapitalPayment(capitalPayment);
          print('💰 Abono a Capital detectado: \$${capitalPayment.toStringAsFixed(2)}');
        }
      }
      
      // 6. Crear la responsabilidad actualizada
      final updated = Responsibility(
        id: responsibility.safeId,
        name: responsibility.safeName,
        amount: newDebt <= 0 ? 0 : responsibility.safeAmount,
        dueDay: responsibility.safeDueDay,
        category: responsibility.safeCategory,
        frequency: responsibility.safeFrequency,
        iconCode: responsibility.safeIconCode,
        isPaid: newDebt <= 0,
        // Marcar como pagado si se cubrió la cuota
        lastPaymentDate: (totalPaidInCycle >= expectedQuota * 0.95) ? now : responsibility.lastPaymentDate,
        cardLimit: responsibility.cardLimit,
        cardBalance: newDebt,
        interestRate: responsibility.interestRate,
        installments: responsibility.installments,
        cutoffDay: responsibility.cutoffDay,
        installmentPlansJson: responsibility.installmentPlansJson,
        minimumPayment: responsibility.minimumPayment,
        paymentDay: responsibility.paymentDay,
        // Tracking del ciclo de pago
        paidAmountThisMonth: totalPaidInCycle,
        lastPaymentMonth: currentMonth,
        lastPaymentYear: currentYear,
      );
      
      await box.putAt(index, updated);
      
      String paymentType = totalPaidInCycle >= expectedQuota * 0.95 ? 'CUOTA COMPLETA' : 'PAGO PARCIAL';
      if (newDebt <= 0) paymentType = 'PAGO TOTAL';
      print('✅ $paymentType en $accountName: \$${amount.toStringAsFixed(0)}. Deuda restante: \$${newDebt.toStringAsFixed(0)}');
    } catch (e) {
      print('⚠️ Error al procesar pago de tarjeta: $e');
    }
  }

  // Revertir un pago (cuando se elimina o edita una transferencia a tarjeta)
  static Future<void> processPaymentReversal(String accountName, double amount, DateTime originalPaymentDate) async {
    final box = getBox();
    try {
      final index = box.values.toList().indexWhere((r) => r.safeName == accountName && r.safeCategory == 'tarjeta');
      if (index == -1) return;
      
      final responsibility = box.getAt(index);
      if (responsibility == null) return;
      
      final paymentMonth = originalPaymentDate.month;
      final paymentYear = originalPaymentDate.year;
      
      // 1. Aumentar la deuda (se revierte el pago)
      double currentDebt = responsibility.cardBalance ?? 0.0;
      double newDebt = currentDebt + amount;
      
      // 2. Restar del monto pagado en el ciclo (si corresponde)
      double paidInCycle = 0.0;
      if (responsibility.lastPaymentMonth == paymentMonth && responsibility.lastPaymentYear == paymentYear) {
        paidInCycle = (responsibility.paidAmountThisMonth ?? 0.0) - amount;
        if (paidInCycle < 0) paidInCycle = 0;
      }
      
      // 3. Verificar si ya no cubre la cuota
      double expectedQuota = responsibility.getAmountForDate(paymentMonth, paymentYear);
      DateTime? lastPaymentDate = responsibility.lastPaymentDate;
      if (paidInCycle < expectedQuota * 0.95) {
        // Ya no cubre la cuota, limpiar la fecha de pago si era del mismo mes
        if (lastPaymentDate != null && lastPaymentDate.month == paymentMonth && lastPaymentDate.year == paymentYear) {
          lastPaymentDate = null;
        }
      }
      
      // 4. Crear la responsabilidad actualizada
      final updated = Responsibility(
        id: responsibility.safeId,
        name: responsibility.safeName,
        amount: responsibility.safeAmount,
        dueDay: responsibility.safeDueDay,
        category: responsibility.safeCategory,
        frequency: responsibility.safeFrequency,
        iconCode: responsibility.safeIconCode,
        isPaid: newDebt <= 0,
        lastPaymentDate: lastPaymentDate,
        cardLimit: responsibility.cardLimit,
        cardBalance: newDebt,
        interestRate: responsibility.interestRate,
        installments: responsibility.installments,
        cutoffDay: responsibility.cutoffDay,
        installmentPlansJson: responsibility.installmentPlansJson,
        minimumPayment: responsibility.minimumPayment,
        paymentDay: responsibility.paymentDay,
        paidAmountThisMonth: paidInCycle,
        lastPaymentMonth: responsibility.lastPaymentMonth,
        lastPaymentYear: responsibility.lastPaymentYear,
      );
      
      await box.putAt(index, updated);
      print('🔄 Pago revertido en $accountName: +\$${amount.toStringAsFixed(0)}. Nueva deuda: \$${newDebt.toStringAsFixed(0)}');
    } catch (e) {
      print('⚠️ Error al revertir pago de tarjeta: $e');
    }
  }
  // Eliminar responsabilidad por nombre (Sync con eliminación de cuenta)
  static Future<void> deleteResponsibilityByName(String name) async {
    final box = getBox();
    try {
      final responsibility = box.values.firstWhere((r) => 
        r.safeName.toLowerCase().trim() == name.toLowerCase().trim() && 
        r.safeCategory == 'tarjeta'
      );
      await responsibility.delete();
      print('✅ Responsabilidad eliminada por sync: $name');
    } catch (e) {
      // No existe o no es tarjeta, ignorar
    }
  }

  // Actualizar responsabilidad desde cuenta editada
  static Future<void> updateResponsibilityFromAccount(String oldName, AccountItem newAccount) async {
    final box = getBox();
    try {
      final responsibility = box.values.firstWhere((r) => r.safeName == oldName && r.safeCategory == 'tarjeta');
      
      responsibility.name = newAccount.title;
      responsibility.cardLimit = double.tryParse(newAccount.creditLimit ?? newAccount.balance) ?? 0.0;
      responsibility.cutoffDay = newAccount.cutoffDay;
      responsibility.paymentDay = newAccount.paymentDay;
      responsibility.interestRate = newAccount.interestRate;
      
      // Update icon if changed
      if (newAccount.icon != null) {
        responsibility.iconCode = newAccount.icon.codePoint;
      }

      await responsibility.save();
      print('✅ Responsabilidad actualizada por sync: $oldName -> ${newAccount.title}');
    } catch (e) {
      // No existe, ignorar
    }
  }
}
