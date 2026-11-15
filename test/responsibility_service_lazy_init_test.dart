import 'dart:io';

import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/models/account_item.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('moneo_resp_lazy_init_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ResponsibilityAdapter());
    }
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'updateResponsibilityFromAccount, createFromAccount y deleteResponsibilityByName inicializan la caja si estaba cerrada',
    () async {
      final account = AccountItem(
        title: 'CuentaTestInit',
        subtitle: 'Tarjeta de Crédito',
        icon: Icons.credit_card,
        iconColor: Colors.blue,
        balance: '100000',
        creditLimit: '500000',
        cutoffDay: 15,
        paymentDay: 5,
      );

      // Sin llamar ResponsibilityService.init() explícitamente antes:
      await ResponsibilityService.createFromAccount(account);
      expect(
        ResponsibilityService.getAllResponsibilities()
            .any((r) => r.safeName == 'CuentaTestInit'),
        isTrue,
      );

      final updated = AccountItem(
        title: 'CuentaTestEditada',
        subtitle: 'Tarjeta de Crédito',
        icon: Icons.credit_card,
        iconColor: Colors.blue,
        balance: '120000',
        creditLimit: '500000',
        cutoffDay: 15,
        paymentDay: 5,
      );

      await ResponsibilityService.updateResponsibilityFromAccount(
        'CuentaTestInit',
        updated,
      );
      expect(
        ResponsibilityService.getAllResponsibilities()
            .any((r) => r.safeName == 'CuentaTestEditada'),
        isTrue,
      );

      await ResponsibilityService.deleteResponsibilityByName('CuentaTestEditada');
      expect(
        ResponsibilityService.getAllResponsibilities()
            .any((r) => r.safeName == 'CuentaTestEditada'),
        isFalse,
      );
    },
  );
}
