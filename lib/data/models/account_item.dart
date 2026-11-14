import 'package:flutter/material.dart';
import 'package:finazaap/utils/app_icons.dart';

class AccountItem {
  String id;
  IconData icon;
  String title;
  String subtitle;
  String balance;
  Color iconColor;
  bool includeInTotal;

  // New fields for Credit Cards
  String? creditLimit;
  int? cutoffDay;
  int? paymentDay;
  double? interestRate;

  AccountItem({
    String? id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.iconColor,
    this.includeInTotal = true,
    this.creditLimit,
    this.cutoffDay,
    this.paymentDay,
    this.interestRate,
  }) : this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  double get balanceAsDouble => double.tryParse(balance) ?? 0.0;
  set balanceAsDouble(double value) => balance = value.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'icon': icon.codePoint,
        'title': title,
        'subtitle': subtitle,
        'balance': balance,
        'iconColor': iconColor.value,
        'includeInTotal': includeInTotal,
        'creditLimit': creditLimit,
        'cutoffDay': cutoffDay,
        'paymentDay': paymentDay,
        'interestRate': interestRate,
      };

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    final dynamic rawIcon = json['icon'];
    final int iconCode = rawIcon is int
        ? rawIcon
        : (rawIcon is String ? (int.tryParse(rawIcon) ?? Icons.account_balance_wallet.codePoint) : Icons.account_balance_wallet.codePoint);

    final dynamic rawColor = json['iconColor'];
    final int colorValue = rawColor is int
        ? rawColor
        : (rawColor is String ? (int.tryParse(rawColor) ?? Colors.blue.value) : Colors.blue.value);

    return AccountItem(
      id: json['id']?.toString(),
      icon: AppIcons.getIcon(iconCode),
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      balance: json['balance']?.toString() ?? '0.0',
      iconColor: Color(colorValue),
      includeInTotal: json['includeInTotal'] ?? true,
      creditLimit: json['creditLimit']?.toString(),
      cutoffDay: json['cutoffDay'] is num ? (json['cutoffDay'] as num).toInt() : int.tryParse(json['cutoffDay']?.toString() ?? ''),
      paymentDay: json['paymentDay'] is num ? (json['paymentDay'] as num).toInt() : int.tryParse(json['paymentDay']?.toString() ?? ''),
      interestRate: json['interestRate'] != null ? (json['interestRate'] as num).toDouble() : null,
    );
  }
}