import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'dart:convert';

// Clase utilitaria para operaciones con cuentas
class AccountUtils {
  // Actualizar el saldo de una cuenta
  static Future<void> updateAccountBalance(String accountName, double amount, bool add) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');
    
    if (accountsData != null) {
      List<dynamic> accounts = [];
      bool updated = false;
      
      for (var accountJson in accountsData) {
        final Map<String, dynamic> data = json.decode(accountJson);
        
        // Si es la cuenta que buscamos, actualizar su saldo
        if (data['title'] == accountName) {
          // Convertir balance a double si es necesario
          double currentBalance;
          if (data['balance'] is String) {
            currentBalance = double.tryParse(data['balance']) ?? 0.0;
          } else {
            currentBalance = (data['balance'] is double) ? data['balance'] : 0.0;
          }
          
          // Actualizar el saldo
          if (add) {
            data['balance'] = (currentBalance + amount).toString();
          } else {
            data['balance'] = (currentBalance - amount).toString();
          }
          
          updated = true;
        }
        
        accounts.add(data);
      }
      
      // Si se actualizó alguna cuenta, guardar los cambios
      if (updated) {
        List<String> updatedAccountsData = accounts.map((item) => json.encode(item)).toList();
        await prefs.setStringList('accounts', updatedAccountsData);
      }
    }
  }
  
  // Revertir el efecto de una transacción
  static Future<void> revertTransaction(Add_data transaction) async {
    // Determinar si es una transferencia o una transacción normal
    if (transaction.IN == 'Transfer') {
      // Para transferencias, necesitamos revertir ambos movimientos
      // Reemplazar esta línea:
      final accountsParts = transaction.explain.split(' > ');
      if (accountsParts.length == 2) {
        final sourceAccountName = accountsParts[0];
        final destAccountName = accountsParts[1];
        final amount = double.parse(transaction.amount);
        
        // Revertir transferencia: añadir al origen y restar del destino
        await updateAccountBalance(sourceAccountName, amount, true); // Devolver al origen
        await updateAccountBalance(destAccountName, amount, false); // Quitar del destino
      }
    } else {
      // Para transacciones normales, invertimos el efecto según el tipo
      bool isIncome = transaction.IN == 'Income';
      final amount = double.parse(transaction.amount);
      
      // Si era ingreso, restamos; si era gasto, sumamos
      await updateAccountBalance(
        transaction.name,
        amount,
        !isIncome // Invertir: true→false, false→true
      );
    }
  }
}