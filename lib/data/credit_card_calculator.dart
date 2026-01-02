import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para calcular datos de tarjetas de crédito dinámicamente desde transacciones.
/// Esta es la ÚNICA fuente de verdad para deudas de tarjetas de crédito.
class CreditCardCalculator {
  
  /// Obtiene el box de transacciones
  static Box<Add_data> _getTransactionBox() {
    return Hive.box<Add_data>('data');
  }
  
  /// Calcula la deuda total de una tarjeta de crédito desde las transacciones.
  /// Suma todos los gastos y resta todos los pagos/ingresos.
  static double calculateTotalDebt(String cardName) {
    try {
      final box = _getTransactionBox();
      double totalDebt = 0.0;
      int txCount = 0;
      
      for (var tx in box.values) {
        final amount = double.tryParse(tx.safeAmount) ?? 0.0;
        
        // 1. Caso estándar: Ingreso/Gasto directo en la cuenta
        if (tx.safeAccount == cardName) {
          if (tx.safeType == 'Expenses') {
            totalDebt += amount;
          } else if (tx.safeType == 'Income') {
            totalDebt -= amount;
          }
        } 
        // 2. Caso Transferencia: Verificar si la tarjeta es origen o destino
        else if (tx.safeType == 'Transfer') {
          final explain = tx.safeCategory; // "Origen > Destino"
          final parts = explain.split(' > ');
          if (parts.length == 2) {
            final source = parts[0].trim();
            final dest = parts[1].trim();
            
            if (source == cardName) {
              // Transferencia DESDE la tarjeta = Gasto/Avance = Aumenta deuda
              totalDebt += amount;
            } else if (dest == cardName) {
              // Transferencia HACIA la tarjeta = Pago = Disminuye deuda
              totalDebt -= amount;
            }
          }
        }
      }
      
      
      // La deuda no puede ser negativa
      return totalDebt < 0 ? 0 : totalDebt;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Calcula la cuota mensual para un mes específico basado en los planes de cuotas activos.
  /// @param cardName Nombre de la tarjeta
  /// @param month Mes a calcular (1-12)
  /// @param year Año a calcular
  /// @param cutoffDay Día de corte de la tarjeta (opcional)
  /// @param interestRate Tasa de interés mensual (opcional, para cálculos con interés)
  static double calculateMonthlyPayment(String cardName, int month, int year, {int? cutoffDay, double? interestRate}) {
    try {
      final box = _getTransactionBox();
      double monthlyPayment = 0.0;
      int activeInstallments = 0;
      
      for (var tx in box.values) {
        if (tx.safeAccount == cardName && tx.safeType == 'Expenses') {
          final amount = double.tryParse(tx.safeAmount) ?? 0.0;
          final installments = int.tryParse(tx.installments ?? '1') ?? 1;
          final isInterestFree = tx.isInterestFree ?? true;
          final txDate = tx.datetime ?? DateTime.now();
          
          // Calcular la cuota mensual de esta compra
          double monthlyQuota;
          
          if (isInterestFree || installments == 1) {
            // Sin interés: cuota simple (monto / cuotas)
            monthlyQuota = amount / installments;
          } else {
            // CON INTERÉS: Fórmula de amortización
            // Cuota = P * [r(1+r)^n] / [(1+r)^n - 1]
            // Donde P = principal, r = tasa mensual, n = número de cuotas
            double rate = (interestRate ?? 2.0) / 100; // Default 2% mensual si no se especifica
            if (rate > 0) {
              double factor = pow(1 + rate, installments).toDouble();
              monthlyQuota = amount * (rate * factor) / (factor - 1);
            } else {
              monthlyQuota = amount / installments;
            }
          }
          
          // Determinar cuándo empezó a cobrarse esta compra
          DateTime startDate = txDate;
          if (cutoffDay != null && txDate.day > cutoffDay) {
            // Compra post-corte: empieza el mes siguiente
            startDate = DateTime(txDate.year, txDate.month + 1, 1);
          }
          
          // Calcular cuántos meses han pasado desde el inicio
          int monthsSinceStart = _monthsDifference(startDate, DateTime(year, month, 1));
          
          // Verificar si esta cuota aplica para el mes consultado
          if (monthsSinceStart >= 0 && monthsSinceStart < installments) {
            monthlyPayment += monthlyQuota;
            activeInstallments++;
          }
        }
      }
      
      
      return monthlyPayment;
    } catch (e) {
      return 0.0;
    }
  }
  
  /// Calcula los meses de diferencia entre dos fechas
  static int _monthsDifference(DateTime from, DateTime to) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }
  
  /// Obtiene un resumen completo de una tarjeta de crédito
  static Map<String, dynamic> getCardSummary(String cardName, {int? cutoffDay}) {
    final now = DateTime.now();
    final totalDebt = calculateTotalDebt(cardName);
    final monthlyPayment = calculateMonthlyPayment(cardName, now.month, now.year, cutoffDay: cutoffDay);
    
    return {
      'totalDebt': totalDebt,
      'monthlyPayment': monthlyPayment,
      'calculatedAt': now,
    };
  }
  
  /// Verifica si hay transacciones pendientes para una tarjeta en un mes
  static bool hasPendingPayment(String cardName, int month, int year, {int? cutoffDay}) {
    final monthlyPayment = calculateMonthlyPayment(cardName, month, year, cutoffDay: cutoffDay);
    return monthlyPayment > 0;
  }
  
  /// Calcula el total pagado en un mes específico
  static double calculatePaidInMonth(String cardName, int month, int year) {
    try {
      final box = _getTransactionBox();
      double totalPaid = 0.0;
      
      for (var tx in box.values) {
        final txDate = tx.datetime;
        if (txDate == null || txDate.month != month || txDate.year != year) continue;
        
        final amount = double.tryParse(tx.safeAmount) ?? 0.0;

        // 1. Ingreso directo
        if (tx.safeAccount == cardName && tx.safeType == 'Income') {
          totalPaid += amount;
        }
        // 2. Transferencia a la tarjeta
        else if (tx.safeType == 'Transfer') {
          final explain = tx.safeCategory;
          final parts = explain.split(' > ');
          if (parts.length == 2 && parts[1].trim() == cardName) {
            totalPaid += amount;
          }
        }
      }
      
      return totalPaid;
    } catch (e) {
      print('⚠️ [CreditCardCalculator] Error calculando pagado en mes: $e');
      return 0.0;
    }
  }
  
  /// Verifica si la cuota del mes está pagada
  static bool isMonthPaid(String cardName, int month, int year, {int? cutoffDay}) {
    final monthlyPayment = calculateMonthlyPayment(cardName, month, year, cutoffDay: cutoffDay);
    final paidAmount = calculatePaidInMonth(cardName, month, year);
    
    // Consideramos pagado si se pagó al menos 95% de la cuota
    return paidAmount >= monthlyPayment * 0.95;
  }
  
  /// Verifica si una tarjeta de crédito es "huérfana" (su cuenta fue eliminada del administrador)
  /// Usa SharedPreferences para verificar si la cuenta aún existe
  static Future<bool> isAccountOrphaned(String cardName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) return true; // No hay cuentas, es huérfana
      
      // Buscar si existe una cuenta con ese nombre
      for (var accountJson in accountsData) {
        try {
          final account = jsonDecode(accountJson) as Map<String, dynamic>;
          if (account['title'] == cardName) {
            return false; // La cuenta existe, no es huérfana
          }
        } catch (e) {
          continue;
        }
      }
      
      return true; // No se encontró la cuenta, es huérfana
    } catch (e) {
      print('⚠️ [CreditCardCalculator] Error verificando cuenta huérfana: $e');
      return false; // En caso de error, asumir que no es huérfana
    }
  }
  
  /// Versión síncrona usando cache (para uso en builders)
  static bool isAccountOrphanedSync(String cardName, List<String>? accountsData) {
    if (accountsData == null) return true;
    
    for (var accountJson in accountsData) {
      try {
        final account = jsonDecode(accountJson) as Map<String, dynamic>;
        if (account['title'] == cardName) {
          return false;
        }
      } catch (e) {
        continue;
      }
    }
    
    return true;
  }
}
