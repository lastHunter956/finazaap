import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class CategoryService {
  // Claves para las categorías en SharedPreferences
  static const String incomeCategoriesKey = 'income_categories';
  static const String expenseCategoriesKey = 'expense_categories';
  
  // Nuevas claves para categorías eliminadas (soft delete)
  static const String deletedIncomeCategoriesKey = 'deleted_income_categories';
  static const String deletedExpenseCategoriesKey = 'deleted_expense_categories';
  
  // Obtener lista de categorías activas
  static Future<List<String>> getCategories(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'Income' ? incomeCategoriesKey : expenseCategoriesKey;
    
    // Obtener todas las categorías guardadas
    final allCategories = prefs.getStringList(key) ?? [];
    
    // Obtener las categorías eliminadas
    final deletedCategories = await getDeletedCategories(type);
    
    // Filtrar las categorías activas (excluyendo las eliminadas)
    return allCategories.where((category) => !deletedCategories.contains(category)).toList();
  }
  
  // Obtener lista de categorías eliminadas
  static Future<List<String>> getDeletedCategories(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'Income' ? deletedIncomeCategoriesKey : deletedExpenseCategoriesKey;
    return prefs.getStringList(key) ?? [];
  }
  
  // Guardar lista de categorías
  static Future<void> saveCategories(String type, List<String> categories) async {
    final prefs = await SharedPreferences.getInstance();
    final key = type == 'Income' ? incomeCategoriesKey : expenseCategoriesKey;
    
    // Eliminar duplicados antes de guardar
    final uniqueCategories = categories.toSet().toList();
    await prefs.setStringList(key, uniqueCategories);
    debugPrint('💾 Guardadas ${uniqueCategories.length} categorías de $type');
  }
  
  // MÉTODO CLAVE: Editar una categoría y actualizar todas las transacciones
  static Future<bool> editCategory(String type, String oldName, String newName) async {
    try {
      // 1. Obtener lista actual de categorías
      final categories = await getCategories(type);
      
      // 2. Reemplazar la categoría si existe
      final index = categories.indexOf(oldName);
      if (index >= 0) {
        categories[index] = newName;
      } else {
        // Si no existe, añadirla (caso poco común)
        categories.add(newName);
      }
      
      // 3. Guardar la lista actualizada
      await saveCategories(type, categories);
      
      // 4. IMPORTANTE: Actualizar todas las transacciones que usan esta categoría
      await updateTransactionsWithCategory(type, oldName, newName);
      
      return true;
    } catch (e) {
      debugPrint('❌ Error al editar categoría: $e');
      return false;
    }
  }
  
  // MÉTODO CLAVE: Soft delete para categoría (marcar como eliminada)
  static Future<bool> deleteCategory(String type, String categoryName) async {
    try {
      // 1. Obtener listas actuales
      final prefs = await SharedPreferences.getInstance();
      final activeKey = type == 'Income' ? incomeCategoriesKey : expenseCategoriesKey;
      final deletedKey = type == 'Income' ? deletedIncomeCategoriesKey : deletedExpenseCategoriesKey;
      
      List<String> activeCategories = prefs.getStringList(activeKey) ?? [];
      List<String> deletedCategories = prefs.getStringList(deletedKey) ?? [];
      
      // 2. Verificar si existe y moverla a la lista de eliminadas
      if (activeCategories.contains(categoryName)) {
        // Eliminar de activas
        activeCategories.remove(categoryName);
        await prefs.setStringList(activeKey, activeCategories);
        
        // Añadir a eliminadas (si no existe ya)
        if (!deletedCategories.contains(categoryName)) {
          deletedCategories.add(categoryName);
          await prefs.setStringList(deletedKey, deletedCategories);
        }
        
        debugPrint('✅ Categoría "$categoryName" marcada como eliminada');
      } else {
        debugPrint('⚠️ Categoría "$categoryName" no encontrada para eliminar');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error al eliminar categoría: $e');
      return false;
    }
  }
  
  // Método para actualizar transacciones con una categoría cambiada
  static Future<void> updateTransactionsWithCategory(
    String type, // 'Income' o 'Expenses' 
    String oldCategory, 
    String newCategory
  ) async {
    try {
      final box = await Hive.openBox<Add_data>('data');
      int updatedCount = 0;
      
      // Obtener todas las keys para evitar problemas durante la iteración
      List<int> keys = [];
      for (var i = 0; i < box.length; i++) {
        keys.add(box.keyAt(i));
      }
      
      // Actualizar las transacciones
      for (var key in keys) {
        final transaction = box.get(key);
        
        // Solo actualizar transacciones del tipo correcto con la categoría específica
        if (transaction != null && 
            transaction.IN == type && 
            transaction.explain == oldCategory) {
          
          transaction.explain = newCategory;
          await box.put(key, transaction);
          updatedCount++;
        }
      }
      
      debugPrint('✅ Actualizadas $updatedCount transacciones de $oldCategory a $newCategory');
    } catch (e) {
      debugPrint('❌ Error al actualizar transacciones con categoría: $e');
      rethrow;
    }
  }
  
  // Limpieza de categorías duplicadas
  static Future<void> cleanupCategories() async {
    try {
      debugPrint('🧹 Iniciando limpieza y sincronización de categorías...');
      final prefs = await SharedPreferences.getInstance();
      
      // Limpiar duplicados en categorías activas
      for (final key in [incomeCategoriesKey, expenseCategoriesKey]) {
        final categories = prefs.getStringList(key) ?? [];
        final uniqueCategories = categories.toSet().toList();
        
        if (uniqueCategories.length < categories.length) {
          final removed = categories.length - uniqueCategories.length;
          debugPrint('🧹 Eliminando $removed categorías duplicadas en $key');
          await prefs.setStringList(key, uniqueCategories);
        }
      }
      
      // Limpiar duplicados en categorías eliminadas
      for (final key in [deletedIncomeCategoriesKey, deletedExpenseCategoriesKey]) {
        final categories = prefs.getStringList(key) ?? [];
        final uniqueCategories = categories.toSet().toList();
        
        if (uniqueCategories.length < categories.length) {
          await prefs.setStringList(key, uniqueCategories);
        }
      }
      
      // Sincronizar con las categorías en AccountsScreen
      await _syncCategoriesToUI(prefs);
      
      debugPrint('✅ Limpieza y sincronización completada');
    } catch (e) {
      debugPrint('❌ Error durante limpieza: $e');
    }
  }

  // Nuevo método para sincronizar categorías con la UI
  static Future<void> _syncCategoriesToUI(SharedPreferences prefs) async {
    try {
      // Sincronizar categorías de ingresos
      List<String>? incomeCategories = prefs.getStringList(incomeCategoriesKey);
      List<Map<String, dynamic>> ingresos = [];
      
      if (incomeCategories != null) {
        List<String>? ingresosData = prefs.getStringList('ingresos') ?? [];
        ingresos = ingresosData.map((item) => json.decode(item) as Map<String, dynamic>).toList();
        
        // Asegurarse que todas las categorías en SharedPreferences existan en la UI
        Set<String> uiCategories = Set.from(ingresos.map((item) => item['text']));
        
        for (String category in incomeCategories) {
          if (!uiCategories.contains(category)) {
            // Añadir a la UI si no existe
            ingresos.add({
              'text': category,
              'icon': Icons.attach_money.codePoint, // Icono por defecto
              'color': Colors.blue.value, // Color por defecto
            });
          }
        }
        
        // Guardar los cambios
        prefs.setStringList('ingresos', ingresos.map((item) => json.encode(item)).toList());
      }
      
      // Sincronizar categorías de gastos
      List<String>? expenseCategories = prefs.getStringList(expenseCategoriesKey);
      List<Map<String, dynamic>> gastos = [];
      
      if (expenseCategories != null) {
        List<String>? gastosData = prefs.getStringList('gastos') ?? [];
        gastos = gastosData.map((item) => json.decode(item) as Map<String, dynamic>).toList();
        
        // Asegurarse que todas las categorías en SharedPreferences existan en la UI
        Set<String> uiCategories = Set.from(gastos.map((item) => item['text']));
        
        for (String category in expenseCategories) {
          if (!uiCategories.contains(category)) {
            // Añadir a la UI si no existe
            gastos.add({
              'text': category,
              'icon': Icons.shopping_cart.codePoint, // Icono por defecto
              'color': Colors.red.value, // Color por defecto
            });
          }
        }
        
        // Guardar los cambios
        prefs.setStringList('gastos', gastos.map((item) => json.encode(item)).toList());
      }
    } catch (e) {
      debugPrint('❌ Error durante sincronización de categorías con UI: $e');
    }
  }

  // Verificar si una categoría está eliminada
  static Future<bool> isCategoryDeleted(String type, String categoryName) async {
    final deletedCategories = await getDeletedCategories(type);
    return deletedCategories.contains(categoryName);
  }
  
  // Verificar si una transacción tiene referencias eliminadas
  static Future<Map<String, bool>> checkForDeletedReferences(Add_data transaction) async {
    final result = {'hasDeletedCategory': false, 'hasDeletedAccount': false};
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Verificar cuenta eliminada
      List<String>? accountsData = prefs.getStringList('accounts') ?? [];
      List<String> accountNames = accountsData
          .map((data) => (json.decode(data) as Map<String, dynamic>)['title'] as String)
          .toList();
      
      // Verificar cuenta principal en todas las transacciones
      if (!accountNames.contains(transaction.name)) {
        result['hasDeletedAccount'] = true;
      }
      
      // 2. Verificar categoría eliminada (solo para ingresos/gastos)
      if (transaction.IN == 'Income' || transaction.IN == 'Expenses') {
        final categoriesKey = transaction.IN == 'Income' 
            ? incomeCategoriesKey 
            : expenseCategoriesKey;
            
        List<String> categories = prefs.getStringList(categoriesKey) ?? [];
        
        // Si la categoría no está en la lista activa pero la transacción la usa
        if (!categories.contains(transaction.explain)) {
          result['hasDeletedCategory'] = true;
        }
      }
      // 3. Para transferencias, verificar ambas cuentas
      else if (transaction.IN == 'Transfer') {
        final parts = transaction.explain.split(' > ');
        if (parts.length == 2) {
          final sourceAccount = parts[0].trim();
          final destAccount = parts[1].trim();
          
          if (!accountNames.contains(sourceAccount) || 
              !accountNames.contains(destAccount)) {
            result['hasDeletedAccount'] = true;
          }
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Error verificando referencias eliminadas: $e');
      return result;
    }
  }
}