import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/services/onboarding_service.dart';

void main() {
  late Directory tempDir;
  late Box<Add_data> dataBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_onboarding_unit_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AdddataAdapter());
    }
    dataBox = await Hive.openBox<Add_data>('data');
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    await dataBox.clear();
  });

  group('OnboardingService', () {
    test('Storage vacío muestra onboarding y no siembra categorías ni cuentas', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final shouldShow = await OnboardingService.shouldShowOnboarding(
        prefsOverride: prefs,
        dataBoxOverride: dataBox,
      );

      expect(shouldShow, isTrue);
      expect(prefs.getStringList(CategoryService.incomeCategoriesKey), isNull);
      expect(prefs.getStringList(CategoryService.expenseCategoriesKey), isNull);
      expect(prefs.getStringList(AccountService.accountsKey), isNull);
    });

    test('Detecta usuario existente con cuentas y marca completed sin alterar datos', () async {
      SharedPreferences.setMockInitialValues({
        AccountService.accountsKey: ['{"title":"Efectivo","balance":"500"}'],
      });
      final prefs = await SharedPreferences.getInstance();

      final shouldShow = await OnboardingService.shouldShowOnboarding(
        prefsOverride: prefs,
        dataBoxOverride: dataBox,
      );

      expect(shouldShow, isFalse);
      expect(prefs.getBool(OnboardingService.completedKey), isTrue);
      expect(prefs.getBool(OnboardingService.skippedKey), isFalse);
      expect(
        prefs.getStringList(AccountService.accountsKey),
        ['{"title":"Efectivo","balance":"500"}'],
      );
    });

    test('Detecta usuario existente con transacciones en Hive sin alterarlas', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await dataBox.add(
        Add_data('Expenses', '12000', DateTime(2026, 11, 1), 'Almuerzo', 'Alimentación', 'Efectivo', 0),
      );

      final shouldShow = await OnboardingService.shouldShowOnboarding(
        prefsOverride: prefs,
        dataBoxOverride: dataBox,
      );

      expect(shouldShow, isFalse);
      expect(prefs.getBool(OnboardingService.completedKey), isTrue);
      expect(dataBox.length, 1);
    });

    test('skipOnboarding marca skipped y completed, y reinicia lastStep', () async {
      SharedPreferences.setMockInitialValues({
        OnboardingService.lastStepKey: 2,
      });
      final prefs = await SharedPreferences.getInstance();

      await OnboardingService.skipOnboarding(prefsOverride: prefs);

      expect(prefs.getBool(OnboardingService.completedKey), isTrue);
      expect(prefs.getBool(OnboardingService.skippedKey), isTrue);
      expect(prefs.getInt(OnboardingService.lastStepKey), 0);
    });

    test('advanceStep y completeOnboarding actualizan estado correctamente', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await OnboardingService.advanceStep(2, prefsOverride: prefs);
      expect(await OnboardingService.getLastStep(prefsOverride: prefs), 2);

      await OnboardingService.completeOnboarding(prefsOverride: prefs);
      expect(prefs.getBool(OnboardingService.completedKey), isTrue);
      expect(prefs.getBool(OnboardingService.skippedKey), isFalse);
      expect(prefs.getInt(OnboardingService.lastStepKey), 0);
    });

    test('saveSelectedCategories y saveFirstAccount no duplican datos existentes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await OnboardingService.saveSelectedCategories(
        expenseCategories: ['Alimentación', 'Transporte'],
        incomeCategories: ['Salario'],
        prefsOverride: prefs,
      );
      await OnboardingService.saveSelectedCategories(
        expenseCategories: ['alimentación', 'Salud'],
        incomeCategories: ['salario', 'Freelance'],
        prefsOverride: prefs,
      );

      expect(
        prefs.getStringList(CategoryService.expenseCategoriesKey),
        ['Alimentación', 'Transporte', 'Salud'],
      );
      expect(
        prefs.getStringList(CategoryService.incomeCategoriesKey),
        ['Salario', 'Freelance'],
      );

      final firstErr = await OnboardingService.saveFirstAccount(
        title: 'Efectivo principal',
        accountType: 'Efectivo',
        initialBalance: 1000,
        prefsOverride: prefs,
      );
      expect(firstErr, isNull);

      final dupErr = await OnboardingService.saveFirstAccount(
        title: 'efectivo principal',
        accountType: 'Efectivo',
        initialBalance: 500,
        prefsOverride: prefs,
      );
      expect(dupErr, 'Ya existe una cuenta con ese nombre');
      expect(prefs.getStringList(AccountService.accountsKey)?.length, 1);
    });
  });
}
