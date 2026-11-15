import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/transaction_service.dart';

/// Servicio de estado y persistencia incremental para el onboarding inicial.
///
/// Opera 100% localmente sobre `SharedPreferences` y `Hive`, sin siembra automática
/// ni llamadas de red.
class OnboardingService {
  OnboardingService._();

  static const String completedKey = 'onboarding_completed';
  static const String skippedKey = 'onboarding_skipped';
  static const String lastStepKey = 'onboarding_last_step';
  static const int totalSteps = 5;

  /// Evalúa si debe mostrarse el onboarding al iniciar la app.
  ///
  /// - Si `onboarding_completed` es `true`, retorna `false`.
  /// - Si `onboarding_completed` nunca fue establecido (`null`) y ya existen datos
  ///   reales (cuentas, categorías o movimientos en Hive `'data'`), marca
  ///   `onboarding_completed = true` sin alterar ni borrar datos y retorna `false`.
  /// - En caso contrario, retorna `true`.
  static Future<bool> shouldShowOnboarding({
    SharedPreferences? prefsOverride,
    Box<Add_data>? dataBoxOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final storedCompleted = prefs.getBool(completedKey);
    if (storedCompleted == true) {
      return false;
    }

    if (storedCompleted == null) {
      final hasExistingData = await _hasExistingUserData(
        prefs: prefs,
        dataBoxOverride: dataBoxOverride,
      );
      if (hasExistingData) {
        await prefs.setBool(completedKey, true);
        await prefs.setBool(skippedKey, false);
        await prefs.setInt(lastStepKey, 0);
        return false;
      }
    }

    return true;
  }

  static Future<bool> _hasExistingUserData({
    required SharedPreferences prefs,
    Box<Add_data>? dataBoxOverride,
  }) async {
    final accounts = prefs.getStringList(AccountService.accountsKey) ?? [];
    if (accounts.isNotEmpty) return true;

    final deletedAccounts =
        prefs.getStringList(AccountService.deletedAccountsKey) ?? [];
    if (deletedAccounts.isNotEmpty) return true;

    final incomeCategories =
        prefs.getStringList(CategoryService.incomeCategoriesKey) ?? [];
    if (incomeCategories.isNotEmpty) return true;

    final expenseCategories =
        prefs.getStringList(CategoryService.expenseCategoriesKey) ?? [];
    if (expenseCategories.isNotEmpty) return true;

    if (dataBoxOverride != null && dataBoxOverride.isOpen) {
      if (dataBoxOverride.isNotEmpty) return true;
    } else if (Hive.isBoxOpen('data')) {
      final box = Hive.box<Add_data>('data');
      if (box.isNotEmpty) return true;
    }

    return false;
  }

  /// Retorna el último paso confirmado (`0..4`).
  static Future<int> getLastStep({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final step = prefs.getInt(lastStepKey) ?? 0;
    return step.clamp(0, totalSteps - 1);
  }

  /// Retorna si el usuario omitió el onboarding previamente.
  static Future<bool> wasSkipped({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    return prefs.getBool(skippedKey) ?? false;
  }

  /// Guarda el avance al siguiente paso tras confirmación explícita.
  static Future<void> advanceStep(
    int nextStep, {
    SharedPreferences? prefsOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    await prefs.setInt(lastStepKey, nextStep.clamp(0, totalSteps - 1));
  }

  /// Marca el onboarding como omitido sin crear datos no confirmados.
  static Future<void> skipOnboarding({SharedPreferences? prefsOverride}) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    await prefs.setBool(skippedKey, true);
    await prefs.setBool(completedKey, true);
    await prefs.setInt(lastStepKey, 0);
  }

  /// Marca el onboarding como finalizado tras completar el resumen final.
  static Future<void> completeOnboarding({
    SharedPreferences? prefsOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    await prefs.setBool(completedKey, true);
    await prefs.setBool(skippedKey, false);
    await prefs.setInt(lastStepKey, 0);
  }

  /// Persiste de forma idempotente solo las categorías seleccionadas o creadas
  /// por el usuario, fusionando con las existentes sin duplicar.
  static Future<void> saveSelectedCategories({
    required List<String> expenseCategories,
    required List<String> incomeCategories,
    SharedPreferences? prefsOverride,
  }) async {
    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    await _mergeCategoryList(
      prefs: prefs,
      key: CategoryService.expenseCategoriesKey,
      incoming: expenseCategories,
    );
    await _mergeCategoryList(
      prefs: prefs,
      key: CategoryService.incomeCategoriesKey,
      incoming: incomeCategories,
    );
  }

  static Future<void> _mergeCategoryList({
    required SharedPreferences prefs,
    required String key,
    required List<String> incoming,
  }) async {
    final cleanedIncoming = incoming
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (cleanedIncoming.isEmpty) return;

    final existing = prefs.getStringList(key) ?? [];
    final existingLower = existing.map((e) => e.toLowerCase()).toSet();
    final merged = List<String>.from(existing);

    for (final cat in cleanedIncoming) {
      if (existingLower.add(cat.toLowerCase())) {
        merged.add(cat);
      }
    }

    await prefs.setStringList(key, merged);
  }

  /// Crea y persiste una cuenta si cumple validaciones y no existe duplicado.
  /// Retorna `null` si tuvo éxito, o un mensaje de error en español si falló.
  static Future<String?> saveFirstAccount({
    required String title,
    required String accountType,
    required double initialBalance,
    int? iconCodePoint,
    int? colorValue,
    SharedPreferences? prefsOverride,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      return 'Por favor ingresa un nombre para la cuenta';
    }
    if (trimmedTitle.contains(' > ')) {
      return 'El nombre no puede contener " > "';
    }
    if (initialBalance < 0) {
      return 'El saldo inicial no puede ser negativo';
    }

    final prefs = prefsOverride ?? await SharedPreferences.getInstance();
    final rawAccounts = prefs.getStringList(AccountService.accountsKey) ?? [];
    final deletedNames =
        (prefs.getStringList(AccountService.deletedAccountsKey) ?? [])
            .map((e) => e.toLowerCase())
            .toSet();

    for (final raw in rawAccounts) {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final existingTitle = (decoded['title'] ?? '').toString();
      if (!deletedNames.contains(existingTitle.toLowerCase()) &&
          existingTitle.toLowerCase() == trimmedTitle.toLowerCase()) {
        return 'Ya existe una cuenta con ese nombre';
      }
    }

    final isCreditCard = accountType == 'Tarjeta de crédito';
    final accountMap = <String, dynamic>{
      'icon': iconCodePoint ?? _defaultIconForAccountType(accountType),
      'title': trimmedTitle,
      'subtitle': accountType,
      'balance': initialBalance.toString(),
      'iconColor': colorValue ?? const Color(0xFF4F8EF7).toARGB32(),
      'includeInTotal': !isCreditCard,
      'creditLimit': isCreditCard ? initialBalance.toString() : null,
    };

    rawAccounts.add(json.encode(accountMap));
    await prefs.setStringList(AccountService.accountsKey, rawAccounts);
    return null;
  }

  static int _defaultIconForAccountType(String accountType) {
    switch (accountType) {
      case 'Efectivo':
        return Icons.payments_outlined.codePoint;
      case 'Tarjeta de crédito':
        return Icons.credit_card_outlined.codePoint;
      case 'Billetera digital':
        return Icons.smartphone_outlined.codePoint;
      default:
        return Icons.account_balance_outlined.codePoint;
    }
  }

  /// Registra el primer ingreso o gasto real confirmado por el usuario.
  /// Retorna `null` si tuvo éxito, o un mensaje de error en español si falló.
  static Future<String?> recordFirstTransaction({
    required String type, // 'Income' o 'Expenses'
    required double amount,
    required String accountTitle,
    required String category,
    required DateTime date,
    String detail = '',
    Box<Add_data>? dataBoxOverride,
  }) async {
    if (amount <= 0) {
      return 'El monto debe ser mayor a 0';
    }
    if (accountTitle.trim().isEmpty || category.trim().isEmpty) {
      return 'Por favor selecciona cuenta y categoría';
    }

    final success = await TransactionService.processTransaction(
      type: type,
      amount: amount,
      accountName: accountTitle,
      isNewTransaction: true,
      transactionDate: date,
    );

    if (!success) {
      return 'No se pudo actualizar el saldo de la cuenta';
    }

    final box = dataBoxOverride ?? Hive.box<Add_data>('data');
    final transaction = Add_data(
      type,
      amount.toString(),
      date,
      detail.trim(),
      category.trim(),
      accountTitle.trim(),
      type == 'Income'
          ? Icons.arrow_downward_rounded.codePoint
          : Icons.arrow_upward_rounded.codePoint,
    );
    await box.add(transaction);
    return null;
  }
}
