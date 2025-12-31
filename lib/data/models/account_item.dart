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

  factory AccountItem.fromJson(Map<String, dynamic> json) => AccountItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        icon: AppIcons.getIcon(json['icon']),
        title: json['title'],
        subtitle: json['subtitle'],
        balance: json['balance'],
        iconColor: Color(json['iconColor']),
        includeInTotal: json['includeInTotal'] ?? true,
        creditLimit: json['creditLimit'],
        cutoffDay: json['cutoffDay'],
        paymentDay: json['paymentDay'],
        interestRate: json['interestRate'] != null ? (json['interestRate'] as num).toDouble() : null,
      );
}