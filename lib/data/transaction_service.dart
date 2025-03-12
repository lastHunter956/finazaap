import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:flutter/material.dart';
import 'dart:collection';
import 'package:intl/intl.dart';

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
  }) async {
    try {
      // 1. Obtener el estado actual de las cuentas
      final prefs = await SharedPreferences.getInstance();
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        print('Error: No se encontraron cuentas');
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
        updated = await _processTransfer(accountName, destinationAccount, amount, accounts);
      } else {
        // Para ingresos y gastos
        bool isIncome = (type == 'Income');
        updated = await _updateAccountBalance(accountName, amount, isIncome, accounts);
      }
      
      // 5. Si se actualizaron cuentas, guardar y actualizar el saldo global
      if (updated) {
        // Serializar y guardar cuentas actualizadas
        List<String> updatedAccountsData = accounts.map((acc) => json.encode(acc)).toList();
        await prefs.setStringList('accounts', updatedAccountsData);
        
        // Actualizar saldo global
        await _updateGlobalBalance(accounts);
        
        return true;
      }
      
      return false;
    } catch (e) {
      print('Error al procesar transacción: $e');
      return false;
    }
  }
  
  // Método para actualizar el saldo de una cuenta específica
  static Future<bool> _updateAccountBalance(
    String accountName, 
    double amount, 
    bool isIncome,
    List<Map<String, dynamic>> accounts
  ) async {
    bool updated = false;
    
    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i]['title'] == accountName) {
        // Obtener el saldo actual (puede estar como String o double)
        double currentBalance = _getBalanceFromData(accounts[i]);
        
        // Actualizar el saldo según la operación
        if (isIncome) {
          currentBalance += amount;
        } else {
          currentBalance -= amount;
        }
        
        // Guardar el nuevo saldo en el mismo formato que estaba
        if (accounts[i]['balance'] is String) {
          accounts[i]['balance'] = currentBalance.toString();
        } else {
          accounts[i]['balance'] = currentBalance;
        }
        
        updated = true;
        print('Cuenta ${accounts[i]['title']} actualizada: $currentBalance');
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
    List<Map<String, dynamic>> accounts
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
      print('Error: No se encontraron las cuentas para la transferencia');
      return false;
    }
    
    // Obtener saldos actuales
    double sourceBalance = _getBalanceFromData(accounts[sourceIndex]);
    double destBalance = _getBalanceFromData(accounts[destIndex]);
    
    // Verificar fondos suficientes
    if (sourceBalance < amount) {
      print('Error: Fondos insuficientes para la transferencia');
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
    
    print('Transferencia procesada: $sourceAccountName -> $destAccountName, Monto: $amount');
    return true;
  }
  
  // Método para revertir una transacción previa
  static Future<void> _revertTransaction(
    Add_data oldTransaction,
    List<Map<String, dynamic>> accounts
  ) async {
    try {
      double amount = double.parse(oldTransaction.amount);
      
      if (oldTransaction.IN == 'Transfer') {
        // Para transferencias
        final parts = oldTransaction.explain.split(' > ');
        if (parts.length == 2) {
          final sourceAccount = parts[0].trim();
          final destAccount = parts[1].trim();
          
          // Revertir: añadir al origen y quitar del destino
          await _updateAccountBalance(sourceAccount, amount, true, accounts);  
          await _updateAccountBalance(destAccount, amount, false, accounts);
        }
      } else {
        // Para ingresos y gastos - invertir operación
        bool wasIncome = oldTransaction.IN == 'Income';
        await _updateAccountBalance(
          oldTransaction.name,
          amount,
          !wasIncome, // Invertir: si era ingreso, ahora restamos; si era gasto, ahora sumamos
          accounts
        );
      }
      
      print('Transacción revertida: ${oldTransaction.IN}, Monto: ${oldTransaction.amount}');
    } catch (e) {
      print('Error al revertir transacción: $e');
      throw e;
    }
  }
  
  // Método para actualizar el saldo global disponible
  static Future<void> _updateGlobalBalance(List<Map<String, dynamic>> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double totalBalance = 0.0;
      
      for (var account in accounts) {
        totalBalance += _getBalanceFromData(account);
      }
      
      await prefs.setDouble('available_balance', totalBalance);
      print('Saldo global actualizado: $totalBalance');
    } catch (e) {
      print('Error actualizando saldo global: $e');
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
  
  // Método para eliminar una transacción y actualizar saldos
  static Future<bool> deleteTransaction(Add_data transaction) async {
    try {
      // Obtener cuentas actuales
      final prefs = await SharedPreferences.getInstance();
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        print('Error: No se encontraron cuentas');
        return false;
      }
      
      List<Map<String, dynamic>> accounts = accountsData.map((acc) => json.decode(acc) as Map<String, dynamic>).toList();
      
      // Revertir efectos según tipo de transacción
      double amount = double.parse(transaction.amount);
      
      if (transaction.IN == 'Transfer') {
        final parts = transaction.explain.split(' > ');
        if (parts.length == 2) {
          final sourceAccount = parts[0].trim();
          final destAccount = parts[1].trim();
          
          // Revertir transferencia
          await _updateAccountBalance(sourceAccount, amount, true, accounts);  // Devuelve dinero a origen
          await _updateAccountBalance(destAccount, amount, false, accounts);  // Quita dinero del destino
        }
      } else {
        // Revertir ingreso/gasto
        bool wasIncome = transaction.IN == 'Income';
        await _updateAccountBalance(
          transaction.name,
          amount,
          !wasIncome, // Si era ingreso, ahora restamos; si era gasto, ahora sumamos
          accounts
        );
      }
      
      // Guardar cuentas actualizadas
      List<String> updatedAccountsData = accounts.map((acc) => json.encode(acc)).toList();
      await prefs.setStringList('accounts', updatedAccountsData);
      
      // Actualizar saldo global
      await _updateGlobalBalance(accounts);
      
      // Eliminar la transacción de Hive
      await transaction.delete();
      
      return true;
    } catch (e) {
      print('Error al eliminar transacción: $e');
      return false;
    }
  }

  // Agregar este método al TransactionService
  static Future<void> updateTransactionsAfterAccountEdit(String oldAccountName, AccountItem newAccount) async {
    try {
      // Crear un nuevo box para asegurar que no hay problemas de caché
      final box = await Hive.openBox<Add_data>('data');
      
      debugPrint('🔄 Iniciando actualización de transacciones: $oldAccountName → ${newAccount.title}');
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

        if (transaction.IN == 'Income' || transaction.IN == 'Expenses') {
          if (transaction.name == oldAccountName) {
            // Actualizar nombre de cuenta
            transaction.name = newAccount.title;
            
            // Actualizar iconCode (asegurarse de que sea válido)
            if (newAccount.icon != null) {
              transaction.iconCode = newAccount.icon.codePoint;
            }
            
            needsUpdate = true;
            debugPrint('✅ Actualizada transacción ${transaction.IN}: ${transaction.explain}');
          }
        } else if (transaction.IN == 'Transfer') {
          List<String> accounts = transaction.explain.split(' > ');
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
              debugPrint('✅ Actualizada transferencia: ${transaction.explain}');
            }
          }
        }

        if (needsUpdate) {
          // IMPORTANTE: Usar put en lugar de putAt para asegurar que la key se mantiene
          await box.put(key, transaction);
          updated++;
        }
      }

      debugPrint('✅ Actualización completada - Se actualizaron $updated transacciones');
      
      // Sincronizar saldos inmediatamente después de actualizar las transacciones
      await syncAccountBalances();
      
    } catch (e) {
      debugPrint('❌ Error al actualizar transacciones: $e');
      rethrow;
    }
  }

  // Método para sincronizar los saldos entre transacciones y cuentas
  static Future<void> syncAccountBalances() async {
    try {
      debugPrint('🔄 Iniciando sincronización de saldos de cuentas...');
      
      // Obtener datos frescos
      final prefs = await SharedPreferences.getInstance();
      final box = await Hive.openBox<Add_data>('data'); // Usar openBox en lugar de box
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        debugPrint('⚠️ No hay cuentas para sincronizar');
        return;
      }
      
      // Depuración adicional
      debugPrint('📊 Transacciones totales: ${box.length}');
      
      // Resto del método...
    } catch (e) {
      debugPrint('❌ Error durante sincronización de saldos: $e');
    }
  }

  static Future<void> verifyDatabaseIntegrity() async {
    try {
      debugPrint('🔍 Verificando integridad de la base de datos...');
      final box = await Hive.openBox<Add_data>('data');
      final prefs = await SharedPreferences.getInstance();
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        debugPrint('⚠️ No hay cuentas para verificar');
        return;
      }
      
      // Extraer nombres de todas las cuentas disponibles
      Set<String> validAccountNames = accountsData
          .map((acc) => (json.decode(acc) as Map<String, dynamic>)['title'] as String)
          .toSet();
          
      debugPrint('📋 Cuentas válidas: ${validAccountNames.join(', ')}');
      
      // Verificar cada transacción para referencias a cuentas inválidas
      int problemsFound = 0;
      for (int i = 0; i < box.length; i++) {
        final transaction = box.getAt(i);
        if (transaction != null) {
          bool hasIssue = false;
          
          if (transaction.IN == 'Income' || transaction.IN == 'Expenses') {
            // Verificar si la cuenta existe
            if (!validAccountNames.contains(transaction.name)) {
              debugPrint('⚠️ Transacción #$i: Cuenta inválida "${transaction.name}"');
              hasIssue = true;
            }
          } else if (transaction.IN == 'Transfer') {
            List<String> parts = transaction.explain.split(' > ');
            if (parts.length == 2) {
              String source = parts[0].trim();
              String destination = parts[1].trim();
              
              if (!validAccountNames.contains(source) || !validAccountNames.contains(destination)) {
                debugPrint('⚠️ Transferencia #$i: Cuenta inválida en "${transaction.explain}"');
                hasIssue = true;
              }
            } else {
              debugPrint('⚠️ Transferencia #$i: Formato inválido "${transaction.explain}"');
              hasIssue = true;
            }
          }
          
          if (hasIssue) {
            problemsFound++;
          }
        }
      }
      
      debugPrint('✅ Verificación completada. Problemas encontrados: $problemsFound');
      
      // Sincronizar saldos para asegurar consistencia
      await syncAccountBalances();
      
    } catch (e) {
      debugPrint('❌ Error durante verificación de integridad: $e');
    }
  }
}