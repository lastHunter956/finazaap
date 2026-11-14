import 'package:finazaap/Screens/add_expense.dart' as add_expense;
import 'package:finazaap/Screens/statistics.dart' as statistics;
import 'package:finazaap/Screens/transfer.dart' as transfer;
import 'package:finazaap/data/models/account_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('L1.5 / T1.1 Unificación de AccountItem', () {
    test('add_expense, transfer y statistics usan el mismo AccountItem canónico', () {
      expect(identical(add_expense.AccountItem, AccountItem), isTrue);
      expect(identical(transfer.AccountItem, AccountItem), isTrue);
      expect(identical(statistics.AccountItem, AccountItem), isTrue);

      final item = AccountItem.fromJson({
        'id': 'acc_1',
        'title': 'Cuenta Ahorros',
        'balance': '100.0',
      });
      final fromAddExpense = add_expense.AccountItem.fromJson(item.toJson());
      final fromTransfer = transfer.AccountItem.fromJson(item.toJson());
      final fromStatistics = statistics.AccountItem.fromJson(item.toJson());

      expect(fromAddExpense.runtimeType, AccountItem);
      expect(fromTransfer.runtimeType, AccountItem);
      expect(fromStatistics.runtimeType, AccountItem);
    });

    test('fromJson, actualización con balanceAsDouble y toJson conservan todos los campos de cuenta', () {
      final fullJson = <String, dynamic>{
        'id': 'acc_visa_1',
        'title': 'Visa Platinum',
        'subtitle': 'Tarjeta de Crédito',
        'balance': '1500000.0',
        'icon': Icons.credit_card.codePoint,
        'iconColor': Colors.purple.value,
        'includeInTotal': false,
        'creditLimit': '5000000.0',
        'cutoffDay': 20,
        'paymentDay': 5,
        'interestRate': 2.35,
      };

      final account = add_expense.AccountItem.fromJson(fullJson);
      expect(account.balanceAsDouble, 1500000.0);

      // Simular actualización de saldo como en add_expense y transfer
      account.balanceAsDouble -= 250000.0;
      final serialized = account.toJson();

      expect(serialized['id'], 'acc_visa_1');
      expect(serialized['title'], 'Visa Platinum');
      expect(serialized['subtitle'], 'Tarjeta de Crédito');
      expect(serialized['balance'], '1250000.0');
      expect(serialized['icon'], Icons.credit_card.codePoint);
      expect(serialized['iconColor'], Colors.purple.value);
      expect(serialized['includeInTotal'], isFalse);
      expect(serialized['creditLimit'], '5000000.0');
      expect(serialized['cutoffDay'], 20);
      expect(serialized['paymentDay'], 5);
      expect(serialized['interestRate'], 2.35);

      // Round-trip adicional vía transfer.AccountItem
      final reloaded = transfer.AccountItem.fromJson(serialized);
      reloaded.balanceAsDouble += 50000.0;
      final reloadedJson = reloaded.toJson();

      expect(reloadedJson['balance'], '1300000.0');
      expect(reloadedJson['id'], 'acc_visa_1');
      expect(reloadedJson['includeInTotal'], isFalse);
      expect(reloadedJson['creditLimit'], '5000000.0');
      expect(reloadedJson['cutoffDay'], 20);
      expect(reloadedJson['paymentDay'], 5);
      expect(reloadedJson['interestRate'], 2.35);
    });

    test('campos opcionales nulos permanecen nulos sin valores inventados', () {
      final minimalJson = <String, dynamic>{
        'title': 'Efectivo',
        'balance': 50000,
      };

      final account = AccountItem.fromJson(minimalJson);
      expect(account.id, isNotEmpty);
      expect(account.creditLimit, isNull);
      expect(account.cutoffDay, isNull);
      expect(account.paymentDay, isNull);
      expect(account.interestRate, isNull);
      expect(account.balance, '50000');
      expect(account.balanceAsDouble, 50000.0);

      final roundTrip = account.toJson();
      expect(roundTrip['id'], account.id);
      expect(roundTrip['creditLimit'], isNull);
      expect(roundTrip['cutoffDay'], isNull);
      expect(roundTrip['paymentDay'], isNull);
      expect(roundTrip['interestRate'], isNull);
    });
  });
}
