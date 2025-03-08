import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
    bool add, 
    List<Map<String, dynamic>> accounts
  ) async {
    bool updated = false;
    
    // Buscar explícitamente la cuenta por su nombre
    for (int i = 0; i < accounts.length; i++) {
      if (accounts[i]['title'] == accountName) {
        double currentBalance;
        
        // Extraer el balance actual con manejo adecuado de tipos
        if (accounts[i]['balance'] is String) {
          currentBalance = double.tryParse(accounts[i]['balance']) ?? 0.0;
        } else if (accounts[i]['balance'] is double) {
          currentBalance = accounts[i]['balance'];
        } else if (accounts[i]['balance'] is int) {
          currentBalance = accounts[i]['balance'].toDouble();
        } else {
          currentBalance = 0.0;
        }
        
        // Aplicar la operación según el parámetro add
        if (add) {
          currentBalance += amount;
          print('Sumando $amount a cuenta $accountName: nuevo balance = $currentBalance');
        } else {
          currentBalance -= amount;
          print('Restando $amount de cuenta $accountName: nuevo balance = $currentBalance');
        }
        
        // Preservar el tipo original del balance
        if (accounts[i]['balance'] is String) {
          accounts[i]['balance'] = currentBalance.toString();
        } else {
          accounts[i]['balance'] = currentBalance;
        }
        
        updated = true;
        break; // Salir del bucle una vez encontrada y actualizada la cuenta
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
          
          print('Revirtiendo transferencia: $sourceAccount -> $destAccount, Monto: $amount');
          
          // Revertir: añadir al origen y quitar del destino
          bool sourceUpdated = await _updateAccountBalance(sourceAccount, amount, true, accounts);  
          bool destUpdated = await _updateAccountBalance(destAccount, amount, false, accounts);
          
          if (!sourceUpdated || !destUpdated) {
            print('⚠️ Advertencia: No se pudieron actualizar ambas cuentas en la transferencia');
          }
        }
      } else {
        // Para ingresos y gastos - invertir operación
        bool wasIncome = oldTransaction.IN == 'Income';
        bool updated = await _updateAccountBalance(
          oldTransaction.name,
          amount,
          !wasIncome, // Invertir: si era ingreso, ahora restamos; si era gasto, ahora sumamos
          accounts
        );
        
        if (!updated) {
          print('⚠️ Advertencia: No se pudo actualizar la cuenta ${oldTransaction.name}');
        }
        
        print('Revirtiendo transacción: ${oldTransaction.explain}, Tipo: ${oldTransaction.IN}, Monto: $amount');
      }
    } catch (e) {
      print('❌ Error al revertir transacción: $e');
      throw e;
    }
  }
  
  // Método mejorado para actualizar el balance global
  static Future<void> _updateGlobalBalance(List<Map<String, dynamic>> accounts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      double totalBalance = 0.0;
      
      // Mostrar saldos para depuración
      StringBuffer balanceLog = StringBuffer('Saldos actuales: ');
      
      for (var account in accounts) {
        double balance = _getBalanceFromData(account);
        balanceLog.write('${account['title']}: $balance, ');
        totalBalance += balance;
      }
      
      print(balanceLog.toString());
      
      await prefs.setDouble('available_balance', totalBalance);
      print('Saldo global actualizado: $totalBalance');
    } catch (e) {
      print('Error actualizando saldo global: $e');
    }
  }
  
  // Método auxiliar para obtener el saldo de manera segura
  static double _getBalanceFromData(Map<String, dynamic> data) {
    try {
      if (data['balance'] is String) {
        return double.tryParse(data['balance']) ?? 0.0;
      } else if (data['balance'] is double) {
        return data['balance'];
      } else if (data['balance'] is int) {
        return data['balance'].toDouble();
      }
    } catch (e) {
      print('Error al obtener balance: $e');
    }
    return 0.0;
  }
  
  // Método para eliminar una transacción y actualizar saldos
  static Future<bool> deleteTransaction(Add_data transaction) async {
    try {
      print('⏳ Iniciando eliminación de transacción tipo: ${transaction.IN}');
      
      // Obtener toda la información necesaria para el proceso
      double amount = double.parse(transaction.amount);
      String type = transaction.IN;
      String accountName = transaction.name;
      
      // Obtener las cuentas actuales
      final prefs = await SharedPreferences.getInstance();
      List<String>? accountsData = prefs.getStringList('accounts');
      
      if (accountsData == null) {
        print('❌ Error: No se encontraron cuentas');
        return false;
      }
      
      // Convertir a formato de mapa para manipulación
      List<Map<String, dynamic>> accounts = accountsData
          .map((acc) => json.decode(acc) as Map<String, dynamic>)
          .toList();
      
      // Mostrar saldos ANTES para depuración
      print('📊 BALANCES ANTES DE ELIMINAR:');
      for (var acc in accounts) {
        print('${acc['title']}: ${acc['balance']}');
      }
      
      // CORRECCIÓN CRÍTICA: Invertir correctamente según el tipo de transacción
      bool updated = false;
      
      if (type == 'Transfer') {
        // Para transferencias
        final parts = transaction.explain.split(' > ');
        if (parts.length == 2) {
          final sourceAccountName = parts[0].trim();
          final destAccountName = parts[1].trim();
          
          // 1. Para la cuenta origen: SUMAR el monto (devolver dinero)
          for (int i = 0; i < accounts.length; i++) {
            if (accounts[i]['title'] == sourceAccountName) {
              double currentBalance = _extractBalanceAsDouble(accounts[i]['balance']);
              currentBalance += amount; // SUMAR para devolver el dinero al origen
              accounts[i]['balance'] = _formatBalance(accounts[i]['balance'], currentBalance);
              print('✅ Sumando $amount a $sourceAccountName: nuevo balance = $currentBalance');
              updated = true;
            }
          }
          
          // 2. Para la cuenta destino: RESTAR el monto (quitar dinero recibido)
          for (int i = 0; i < accounts.length; i++) {
            if (accounts[i]['title'] == destAccountName) {
              double currentBalance = _extractBalanceAsDouble(accounts[i]['balance']);
              currentBalance -= amount; // RESTAR para quitar el dinero del destino
              accounts[i]['balance'] = _formatBalance(accounts[i]['balance'], currentBalance);
              print('✅ Restando $amount de $destAccountName: nuevo balance = $currentBalance');
              updated = true;
            }
          }
        }
      } else if (type == 'Income') {
        // Para ingresos: RESTAR el monto (quitar el ingreso)
        for (int i = 0; i < accounts.length; i++) {
          if (accounts[i]['title'] == accountName) {
            double currentBalance = _extractBalanceAsDouble(accounts[i]['balance']);
            currentBalance -= amount; // RESTAR para quitar el ingreso
            accounts[i]['balance'] = _formatBalance(accounts[i]['balance'], currentBalance);
            print('✅ Restando $amount de $accountName: nuevo balance = $currentBalance');
            updated = true;
          }
        }
      } else if (type == 'Expenses') {
        // AQUÍ ESTABA EL ERROR: Para gastos: SUMAR el monto (devolver el gasto)
        for (int i = 0; i < accounts.length; i++) {
          if (accounts[i]['title'] == accountName) {
            double currentBalance = _extractBalanceAsDouble(accounts[i]['balance']);
            currentBalance += amount; // SUMAR para revertir el gasto
            accounts[i]['balance'] = _formatBalance(accounts[i]['balance'], currentBalance);
            print('✅ Sumando $amount a $accountName: nuevo balance = $currentBalance');
            updated = true;
          }
        }
      }
      
      // Guardar cambios si hubo actualizaciones
      if (updated) {
        // Guardar los cambios
        List<String> updatedAccountsData = accounts.map((acc) => json.encode(acc)).toList();
        await prefs.setStringList('accounts', updatedAccountsData);
        
        // Actualizar saldo global
        double totalBalance = 0.0;
        for (var acc in accounts) {
          totalBalance += _extractBalanceAsDouble(acc['balance']);
        }
        await prefs.setDouble('available_balance', totalBalance);
        
        // Mostrar saldos DESPUÉS para verificación
        print('📊 BALANCES DESPUÉS DE ELIMINAR:');
        for (var acc in accounts) {
          print('${acc['title']}: ${acc['balance']}');
        }
        print('Saldo global actualizado: $totalBalance');
      }
      
      // Eliminar la transacción de Hive
      final box = Hive.box<Add_data>('data');
      int transactionIndex = box.values.toList().indexOf(transaction);
      
      if (transactionIndex != -1) {
        final key = box.keyAt(transactionIndex);
        await box.delete(key);
        print('Transacción eliminada de Hive con key: $key');
      } else {
        print('No se encontró la transacción exacta, buscando por propiedades similares...');
        // Intentar encontrar y eliminar por propiedades similares
        for (int i = 0; i < box.length; i++) {
          final item = box.getAt(i);
          if (item != null && 
              item.IN == transaction.IN && 
              item.amount == transaction.amount && 
              item.explain == transaction.explain) {
            await box.deleteAt(i);
            print('Transacción encontrada y eliminada en posición $i');
            transactionIndex = i;
            break;
          }
        }
        
        if (transactionIndex == -1) {
          print('⚠️ No se pudo encontrar la transacción en Hive');
        }
      }
      
      return true;
    } catch (e) {
      print('❌ Error en deleteTransaction: $e');
      return false;
    }
  }

  // Método auxiliar para extraer el balance como double independiente del tipo
  static double _extractBalance(dynamic balanceValue) {
    if (balanceValue is String) {
      return double.tryParse(balanceValue) ?? 0.0;
    } else if (balanceValue is double) {
      return balanceValue;
    } else if (balanceValue is int) {
      return balanceValue.toDouble();
    }
    return 0.0;
  }

  // Método auxiliar para preservar el tipo original del balance
  static dynamic _preserveBalanceType(dynamic originalValue, double newBalance) {
    if (originalValue is String) {
      return newBalance.toString();
    }
    return newBalance;
  }

  // Método auxiliar para extraer el saldo como double, independientemente del formato
  static double _extractBalanceAsDouble(dynamic balance) {
    if (balance is String) {
      return double.tryParse(balance) ?? 0.0;
    } else if (balance is double) {
      return balance;
    } else if (balance is int) {
      return balance.toDouble();
    }
    return 0.0;
  }

  // Método auxiliar para mantener el formato original del saldo
  static dynamic _formatBalance(dynamic originalFormat, double newValue) {
    // Preservar el tipo original (string o number)
    if (originalFormat is String) {
      return newValue.toString();
    }
    return newValue;
  }
}