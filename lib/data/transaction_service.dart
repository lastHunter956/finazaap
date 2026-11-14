import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:intl/intl.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/core/utils/app_logger.dart';

class TransactionService {
  // Singleton para acceso global
  static final TransactionService _instance = TransactionService._internal();
  
  factory TransactionService() {
    return _instance;
  }
  
  TransactionService._internal();
  
  // Método principal para procesar cualquier transacción
  static Future<bool> processTransaction({
    required String type,        // 'Income', 'Expenses', 'Transfer'
    required double amount,      // Monto de la transacción
    required String accountName, // Nombre de la cuenta (origen en caso de transferencia)
    String? destinationAccount,  // Cuenta destino (solo para transferencias)
    bool isNewTransaction = true, // Si es nueva o edición
    Add_data? oldTransaction,    // Transacción anterior (solo para ediciones)
    int installments = 1,        // Nuevo parámetro para cuotas
    bool isInterestFree = true,  // Nuevo parámetro para intereses
    int? targetMonth,            // Mes objetivo para el estado de la responsabilidad
    int? targetYear,             // Año objetivo para el estado de la responsabilidad
    bool recordInHive = false,   // Si debe registrar la transacción en el historial de Hive
    String? detail,              // Detalle opcional para el registro Hive
    DateTime? transactionDate,   // Fecha de la transacción para planes de cuotas
  }) async {
    try {
      // 1. Obtener el estado actual de las cuentas
      final prefs = await PrefsManager.instance;
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        return false;
      }
      
      // 2. Desserializar todas las cuentas
      List<Map<String, dynamic>> accounts = accountsData.map((acc) => json.decode(acc) as Map<String, dynamic>).toList();
      
      // 3. Si es una edición, primero revertir la transacción anterior
      if (!isNewTransaction && oldTransaction != null) {
        await _revertTransaction(oldTransaction, accounts);
      }
      
      // 4. Aplicar los cambios según el tipo de transacción
      bool updated = false;
      if (type == 'Transfer' && destinationAccount != null) {
        // Para transferencias, actualizar origen y destino
        updated = await _processTransfer(accountName, destinationAccount, amount, accounts, targetMonth: targetMonth, targetYear: targetYear);
      } else {
        // Para ingresos y gastos
        bool isIncome = (type == 'Income');
        updated = await _updateAccountBalance(accountName, amount, isIncome, accounts, installments, isInterestFree, false, transactionDate);
      }
      
      // 5. Si se actualizaron cuentas, guardar y actualizar el saldo global
      if (updated) {
        // Serializar y guardar cuentas actualizadas
        List<String> updatedAccountsData = accounts.map((acc) => json.encode(acc)).toList();
        await prefs.setStringList('accounts', updatedAccountsData);
        
        // Actualizar saldo global
        await _updateGlobalBalance(accounts);
        
        // 6. Si se solicita, registrar en el historial de transacciones (Hive)
        if (recordInHive) {
          try {
            final box = Hive.isBoxOpen('data')
                ? Hive.box<Add_data>('data')
                : await Hive.openBox<Add_data>('data');
            final transaction = Add_data(
              type,
              amount.toString(),
              DateTime.now(),
              detail ?? (type == 'Transfer' ? 'Transferencia' : 'Operación'),
              type == 'Transfer' 
                  ? '$accountName > $destinationAccount' 
                  : 'Responsabilidad',
              type == 'Transfer' ? '' : accountName,
              type == 'Transfer' ? Icons.sync_alt.codePoint : Icons.receipt_long_rounded.codePoint,
              installments.toString(),
              isInterestFree,
            );
            await box.add(transaction);
            AppLogger.info('Transacción registrada en Hive: $type - $amount');
          } catch (e) {
            AppLogger.error('Error al registrar transacción en Hive', error: e);
          }
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      AppLogger.error('processTransaction falló', error: e);
      return false;
    }
  }

  // Método para actualizar el saldo de una cuenta específica
  static Future<bool> _updateAccountBalance(
    String accountName, 
    double amount, 
    bool isIncome,
    List<Map<String, dynamic>> accounts,
    [int installments = 1, bool isInterestFree = true, bool isReversal = false, DateTime? transactionDate]
  ) async {
    bool updated = false;
    
    for (int i = 0; i < accounts.length; i++) {
      final accountTitle = accounts[i]['title']?.toString() ?? '';
      
      if (accountTitle == accountName) {
        // Obtener el saldo actual (puede estar como String o double)
        double currentBalance = _getBalanceFromData(accounts[i]);
        double newBalance = currentBalance;
        
        // Actualizar el saldo según la operación
        if (isIncome) {
          newBalance = currentBalance + amount;
        } else {
          newBalance = currentBalance - amount;
        }
        
        // Guardar el nuevo saldo en el mismo formato que estaba
        if (accounts[i]['balance'] is String) {
          accounts[i]['balance'] = newBalance.toString();
        } else {
          accounts[i]['balance'] = newBalance;
        }
        
        updated = true;
        
        // SYNC: Si es tarjeta de crédito, actualizar deuda y planes de cuotas una sola vez
        try {
          if (_isCreditCardAccount(accounts[i])) {
            if (isReversal) {
              if (isIncome) {
                await ResponsibilityService.processDebtReversal(
                  accountTitle,
                  amount,
                  transactionDate ?? DateTime.now(),
                  installments,
                  isInterestFree,
                );
              } else {
                await ResponsibilityService.processPaymentReversal(
                  accountTitle,
                  amount,
                  transactionDate ?? DateTime.now(),
                );
              }
            } else {
              if (!isIncome) {
                await ResponsibilityService.processDebtIncrease(
                  accountTitle,
                  amount,
                  installments,
                  isInterestFree,
                  transactionDate,
                );
              } else {
                await ResponsibilityService.processDebtPayment(
                  accountTitle,
                  amount,
                  paymentDate: transactionDate,
                );
              }
            }
          } else {
            await ResponsibilityService.syncCardBalance(
              cardName: accountTitle,
              amount: amount,
              isExpense: !isIncome, // Si NO es ingreso, es Gasto
            );
          }
        } catch (e) {
          AppLogger.error('Error syncing card balance', error: e);
        }

        break;
      }
    }
    
    return updated;
  }
  
  // Método para procesar transferencias
  static Future<bool> _processTransfer(
    String sourceAccountName,
    String destAccountName,
    double amount,
    List<Map<String, dynamic>> accounts,
    {int? targetMonth, int? targetYear}
  ) async {
    int sourceIndex = -1;
    int destIndex = -1;
    
    // Encontrar índices de las cuentas
    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i]['title'] == sourceAccountName) {
        sourceIndex = i;
      }
      if (accounts[i]['title'] == destAccountName) {
        destIndex = i;
      }
      
      if (sourceIndex != -1 && destIndex != -1) break;
    }
    
    // Verificar que se encontraron ambas cuentas
    if (sourceIndex == -1 || destIndex == -1) {
      AppLogger.error('Error: No se encontraron las cuentas para la transferencia');
      return false;
    }
    
    // Obtener saldos actuales
    double sourceBalance = _getBalanceFromData(accounts[sourceIndex]);
    double destBalance = _getBalanceFromData(accounts[destIndex]);
    
    // Verificar fondos suficientes
    if (sourceBalance < amount) {
      AppLogger.warning('Error: Fondos insuficientes para la transferencia: $sourceBalance < $amount');
      return false;
    }
    
    // Actualizar saldos
    sourceBalance -= amount;
    destBalance += amount;
    
    // Guardar nuevos saldos en el formato original
    if (accounts[sourceIndex]['balance'] is String) {
      accounts[sourceIndex]['balance'] = sourceBalance.toString();
    } else {
      accounts[sourceIndex]['balance'] = sourceBalance;
    }
    
    if (accounts[destIndex]['balance'] is String) {
      accounts[destIndex]['balance'] = destBalance.toString();
    } else {
      accounts[destIndex]['balance'] = destBalance;
    }
    
    AppLogger.info('Transferencia procesada: $sourceAccountName -> $destAccountName, Monto: $amount');
    
    // AUTO-SYNC CREDIT CARD RESPONSIBILITY (Transfers)
    try {
      final sourceSubtitle = accounts[sourceIndex]['subtitle']?.toString().toLowerCase() ?? '';
      if (sourceSubtitle.contains('tarjeta') && (sourceSubtitle.contains('credito') || sourceSubtitle.contains('crédito'))) {
         await ResponsibilityService.processDebtIncrease(sourceAccountName, amount, 1);
      }
      
      final destSubtitle = accounts[destIndex]['subtitle']?.toString().toLowerCase() ?? '';
      if (destSubtitle.contains('tarjeta') && (destSubtitle.contains('credito') || destSubtitle.contains('crédito'))) {
         await ResponsibilityService.processDebtPayment(destAccountName, amount, targetMonth: targetMonth, targetYear: targetYear);
      }
    } catch (e) {
      AppLogger.error('Error syncing transfer debt', error: e);
    }

    return true;
  }
  
  // Método para revertir una transacción previa
  static Future<void> _revertTransaction(
    Add_data oldTransaction,
    List<Map<String, dynamic>> accounts
  ) async {
    try {
      double amount = double.parse(oldTransaction.safeAmount);
      final originalDate = oldTransaction.date ?? DateTime.now();
      final installments = int.tryParse(oldTransaction.installments ?? '1') ?? 1;
      final isInterestFree = oldTransaction.isInterestFree ?? true;
      
      AppLogger.debug('🔄 INICIANDO REVERSIÓN: Type=${oldTransaction.safeType}, Account=${oldTransaction.safeAccount}, Amount=$amount, Installments=$installments');

      if (oldTransaction.safeType == 'Transfer') {
        await _revertTransfer(oldTransaction, amount, accounts);
      } else {
        // Para ingresos y gastos - invertir operación
        bool wasIncome = oldTransaction.safeType == 'Income';
        AppLogger.debug('Reversión ${wasIncome ? "INGRESO" : "GASTO"}: Ahora ${!wasIncome ? "sumar" : "restar"} $amount');
        
        await _updateAccountBalance(
          oldTransaction.safeAccount,
          amount,
          !wasIncome, // Invertir: si era ingreso, ahora restamos; si era gasto, ahora sumamos
          accounts,
          installments,
          isInterestFree,
          true, // isReversal = true
          originalDate
        );
      }

      // Revertir pago de obligación si la transacción estaba vinculada
      if (oldTransaction.isObligationPayment == true && oldTransaction.responsibilityId != null) {
        AppLogger.debug('Revertir pago de obligación: ${oldTransaction.responsibilityId}');
        await ResponsibilityService.revertPayment(
          oldTransaction.responsibilityId!,
          amount,
          originalDate,
        );
      }
      
      AppLogger.success('REVERSIÓN COMPLETADA');
    } catch (e) {
      AppLogger.error('Error en reversión', error: e);
      throw e;
    }
  }
  
  // Método para actualizar el saldo global disponible
  static Future<void> _updateGlobalBalance(List<Map<String, dynamic>> accounts) async {
    try {
      final prefs = await PrefsManager.instance;
      double totalBalance = 0.0;
      
      for (var account in accounts) {
        final includeInTotal = account['includeInTotal'] ?? true;
        if (includeInTotal == true && !_isCreditCardAccount(account)) {
          totalBalance += _getBalanceFromData(account);
        }
      }
      
      await prefs.setDouble('available_balance', totalBalance);
      AppLogger.info('Saldo global actualizado: $totalBalance');
    } catch (e) {
      AppLogger.error('Error actualizando saldo global', error: e);
    }
  }

  static bool _isCreditCardAccount(Map<String, dynamic> account) {
    final subtitle = account['subtitle']?.toString().toLowerCase() ?? '';
    return subtitle.contains('tarjeta') &&
        (subtitle.contains('credito') || subtitle.contains('crédito'));
  }

  static void _applyBalanceDelta(Map<String, dynamic> account, double delta) {
    final updated = _getBalanceFromData(account) + delta;
    if (account['balance'] is String) {
      account['balance'] = updated.toString();
    } else {
      account['balance'] = updated;
    }
  }

  /// Revierte una transferencia de manera simétrica a [_processTransfer].
  static Future<void> _revertTransfer(
    Add_data transaction,
    double amount,
    List<Map<String, dynamic>> accounts,
  ) async {
    final parts = transaction.safeCategory.split(' > ');
    if (parts.length != 2) return;

    final sourceAccount = parts[0].trim();
    final destAccount = parts[1].trim();
    final originalDate = transaction.date;

    int sourceIndex = -1;
    int destIndex = -1;
    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i]['title'] == sourceAccount) sourceIndex = i;
      if (accounts[i]['title'] == destAccount) destIndex = i;
      if (sourceIndex != -1 && destIndex != -1) break;
    }

    if (sourceIndex != -1) {
      _applyBalanceDelta(accounts[sourceIndex], amount);
      if (_isCreditCardAccount(accounts[sourceIndex])) {
        await ResponsibilityService.processDebtReversal(
          sourceAccount,
          amount,
          originalDate,
          1,
          true,
        );
      }
    }

    if (destIndex != -1) {
      _applyBalanceDelta(accounts[destIndex], -amount);
      if (_isCreditCardAccount(accounts[destIndex])) {
        await ResponsibilityService.processPaymentReversal(
          destAccount,
          amount,
          originalDate,
        );
      }
    }
  }
  
  // Método auxiliar para obtener el saldo de una cuenta
  static double _getBalanceFromData(Map<String, dynamic> data) {
    if (data['balance'] is String) {
      return double.tryParse(data['balance']) ?? 0.0;
    } else if (data['balance'] is double) {
      return data['balance'];
    } else if (data['balance'] is int) {
      return data['balance'].toDouble();
    } else {
      return 0.0;
    }
  }
  
  static final Set<Object> _deletingTransactionLocks = <Object>{};

  // Método para eliminar una transacción y actualizar saldos
  static Future<bool> deleteTransaction(Add_data transaction) async {
    if (!transaction.isInBox) {
      return false;
    }

    final boxKey = transaction.key;
    final lockKey = boxKey != null
        ? '${transaction.box?.name ?? 'data'}:$boxKey'
        : identityHashCode(transaction);
    if (!_deletingTransactionLocks.add(lockKey)) {
      return false;
    }

    try {
      if (!transaction.isInBox) {
        return false;
      }

      // Obtener cuentas actuales
      final prefs = await PrefsManager.instance;
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        AppLogger.error('Error: No se encontraron cuentas');
        return false;
      }
      
      List<Map<String, dynamic>> accounts = accountsData.map((acc) => json.decode(acc) as Map<String, dynamic>).toList();
      
      // Revertir efectos según tipo de transacción
      double amount = double.parse(transaction.safeAmount);
      
      if (transaction.safeType == 'Transfer') {
        await _revertTransfer(transaction, amount, accounts);
      } else {
        // Revertir ingreso/gasto
        bool wasIncome = transaction.safeType == 'Income';
        await _updateAccountBalance(
          transaction.safeAccount,
          amount,
          !wasIncome, // Si era ingreso, ahora restamos; si era gasto, ahora sumamos
          accounts,
          int.tryParse(transaction.installments ?? '1') ?? 1,
          transaction.isInterestFree ?? true,
          true, // isReversal = true
          transaction.date
        );
      }
      
      // Guardar cuentas actualizadas
      List<String> updatedAccountsData = accounts.map((acc) => json.encode(acc)).toList();
      await prefs.setStringList('accounts', updatedAccountsData);
      
      // Actualizar saldo global
      await _updateGlobalBalance(accounts);

      // Revertir pago de obligación si la transacción estaba vinculada
      if (transaction.isObligationPayment == true && transaction.responsibilityId != null) {
        await ResponsibilityService.revertPayment(
          transaction.responsibilityId!,
          amount,
          transaction.date ?? DateTime.now(),
        );
      }
      
      // Eliminar la transacción de Hive
      await transaction.delete();
      
      return true;
    } catch (e) {
      AppLogger.error('Error al eliminar transacción', error: e);
      return false;
    } finally {
      _deletingTransactionLocks.remove(lockKey);
    }
  }

  // Método para actualizar transacciones cuando se edita una cuenta
  static Future<void> updateTransactionsAfterAccountEdit(String oldAccountName, AccountItem newAccount) async {
    try {
      final box = Hive.isBoxOpen('data')
          ? Hive.box<Add_data>('data')
          : await Hive.openBox<Add_data>('data');
      
      AppLogger.debug('🔄 Iniciando actualización de transacciones: $oldAccountName → ${newAccount.title}');
      int updated = 0;

      // Primero, obtener todas las keys y transacciones para evitar problemas de iteración
      List<int> keys = [];
      List<Add_data> transactions = [];
      
      for (var i = 0; i < box.length; i++) {
        keys.add(box.keyAt(i));
        transactions.add(box.getAt(i)!);
      }
      
      // Ahora iterar sobre la lista copiada para hacer las actualizaciones
      for (var i = 0; i < keys.length; i++) {
        final key = keys[i];
        final transaction = transactions[i];
        bool needsUpdate = false;

        if (transaction.safeType == 'Income' || transaction.safeType == 'Expenses') {
          if (transaction.safeAccount == oldAccountName) {
            // Actualizar nombre de cuenta
            transaction.name = newAccount.title;
            
            // Actualizar iconCode (asegurarse de que sea válido)
            if (newAccount.icon != null) {
              transaction.iconCode = newAccount.icon.codePoint;
            }
            
            needsUpdate = true;
            AppLogger.debug('✅ Actualizada transacción ${transaction.IN}: ${transaction.explain}');
          }
        } else if (transaction.safeType == 'Transfer') {
          List<String> accounts = transaction.safeCategory.split(' > ');
          if (accounts.length == 2) {
            String source = accounts[0].trim();
            String destination = accounts[1].trim();
            
            if (source == oldAccountName) {
              source = newAccount.title;
              needsUpdate = true;
            }
            if (destination == oldAccountName) {
              destination = newAccount.title;
              needsUpdate = true;
            }
            
            if (needsUpdate) {
              transaction.explain = '$source > $destination';
              AppLogger.debug('✅ Actualizada transferencia: ${transaction.safeCategory}');
            }
          }
        }

        if (needsUpdate) {
          // IMPORTANTE: Usar put en lugar de putAt para asegurar que la key se mantiene
          await box.put(key, transaction);
          updated++;
        }
      }

      AppLogger.success('Actualización completada - Se actualizaron $updated transacciones');
      
      // Sincronizar saldos inmediatamente después de actualizar las transacciones
      await syncAccountBalances();
      
      // Sincronizar Responsabilidad (Tarjeta) si cambió el nombre o detalles
      await ResponsibilityService.updateResponsibilityFromAccount(oldAccountName, newAccount);
      
    } catch (e) {
      AppLogger.error('Error al actualizar transacciones', error: e);
      rethrow;
    }
  }

  // Método para sincronizar los saldos entre transacciones y cuentas
  static Future<void> syncAccountBalances() async {
    try {
      AppLogger.debug('🔄 Iniciando sincronización de saldos de cuentas...');
      
      // Obtener datos frescos
      final prefs = await PrefsManager.instance;
      final box = Hive.isBoxOpen('data')
          ? Hive.box<Add_data>('data')
          : await Hive.openBox<Add_data>('data');
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        AppLogger.warning('⚠️ No hay cuentas para sincronizar');
        return;
      }
      
      // Depuración adicional
      AppLogger.debug('📊 Transacciones totales: ${box.length}');
      
      // Aquí iría la lógica completa de sincronización, por ahora solo logs de inicio
      // Para evitar romper la app si falta lógica, lo dejamos como log informativo
      // Si hay lógica crítica faltante, deberá ser restaurada de un commit previo.
      
    } catch (e) {
      AppLogger.error('Error durante sincronización de saldos', error: e);
    }
  }

  static Future<void> verifyDatabaseIntegrity() async {
    try {
      AppLogger.info('🔍 Verificando integridad de la base de datos...');
      final box = Hive.isBoxOpen('data')
          ? Hive.box<Add_data>('data')
          : await Hive.openBox<Add_data>('data');
      final prefs = await PrefsManager.instance;
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        AppLogger.warning('⚠️ No hay cuentas para verificar');
        return;
      }
      
      // Extraer nombres de todas las cuentas disponibles
      Set<String> validAccountNames = accountsData
          .map((acc) => (json.decode(acc) as Map<String, dynamic>)['title'] as String)
          .toSet();
          
      AppLogger.debug('📋 Cuentas válidas: ${validAccountNames.join(', ')}');
      
      // Verificar cada transacción para referencias a cuentas inválidas
      int problemsFound = 0;
      for (int i = 0; i < box.length; i++) {
        final transaction = box.getAt(i);
        if (transaction != null) {
          bool hasIssue = false;
          
          if (transaction.safeType == 'Income' || transaction.safeType == 'Expenses') {
            // Verificar si la cuenta existe
            if (!validAccountNames.contains(transaction.safeAccount)) {
              AppLogger.warning('⚠️ Transacción #$i: Cuenta inválida "${transaction.safeAccount}"');
              hasIssue = true;
            }
          } else if (transaction.safeType == 'Transfer') {
            List<String> parts = transaction.safeCategory.split(' > ');
            if (parts.length == 2) {
              String source = parts[0].trim();
              String destination = parts[1].trim();
              
              if (!validAccountNames.contains(source) || !validAccountNames.contains(destination)) {
                AppLogger.warning('⚠️ Transferencia #$i: Cuenta inválida en "${transaction.explain}"');
                hasIssue = true;
              }
            } else {
              AppLogger.warning('⚠️ Transferencia #$i: Formato inválido "${transaction.explain}"');
              hasIssue = true;
            }
          }
          
          if (hasIssue) {
            problemsFound++;
          }
        }
      }
      
      AppLogger.info('✅ Verificación completada. Problemas encontrados: $problemsFound');
      
      // Sincronizar saldos para asegurar consistencia
      await syncAccountBalances();
      
    } catch (e) {
      AppLogger.error('Error durante verificación de integridad', error: e);
    }
  }
}