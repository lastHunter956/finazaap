import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AccountService {
  static const String accountsKey = 'accounts';
  static const String deletedAccountsKey = 'deleted_accounts';
  
  // Obtener todas las cuentas activas
  static Future<List<Map<String, dynamic>>> getActiveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> allAccounts = prefs.getStringList(accountsKey) ?? [];
    final List<String> deletedAccounts = prefs.getStringList(deletedAccountsKey) ?? [];
    
    // Filtrar para incluir solo cuentas activas (no eliminadas)
    return allAccounts
        .map((acc) => json.decode(acc) as Map<String, dynamic>)
        .where((account) => !deletedAccounts.contains(account['title']))
        .toList();
  }
  
  // Obtener nombres de cuentas eliminadas
  static Future<List<String>> getDeletedAccountNames() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(deletedAccountsKey) ?? [];
  }
  
  // Marcar una cuenta como eliminada (soft delete)
  static Future<void> markAccountAsDeleted(String accountName) async {
    final prefs = await SharedPreferences.getInstance();
    final deletedAccounts = prefs.getStringList(deletedAccountsKey) ?? [];
    
    if (!deletedAccounts.contains(accountName)) {
      deletedAccounts.add(accountName);
      await prefs.setStringList(deletedAccountsKey, deletedAccounts);
      debugPrint('✅ Cuenta "$accountName" marcada como eliminada');
    }
  }
  
  // Verificar si una cuenta está eliminada
  static Future<bool> isAccountDeleted(String accountName) async {
    final deletedAccounts = await getDeletedAccountNames();
    return deletedAccounts.contains(accountName);
  }
}