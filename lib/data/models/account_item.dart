import 'package:flutter/material.dart';

class AccountItem {
  String id; // Nuevo campo para identificar de manera única
  IconData icon;
  String title;
  String subtitle;
  String balance;
  Color iconColor;
  bool includeInTotal;

  AccountItem({
    String? id, // Opcional en el constructor
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.balance,
    required this.iconColor,
    this.includeInTotal = true,
  }) : this.id = id ?? DateTime.now().millisecondsSinceEpoch.toString();

  Map<String, dynamic> toJson() => {
        'id': id,
        'icon': icon.codePoint,
        'title': title,
        'subtitle': subtitle,
        'balance': balance,
        'iconColor': iconColor.value,
        'includeInTotal': includeInTotal,
      };

  factory AccountItem.fromJson(Map<String, dynamic> json) => AccountItem(
        id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        title: json['title'],
        subtitle: json['subtitle'],
        balance: json['balance'],
        iconColor: Color(json['iconColor']),
        includeInTotal: json['includeInTotal'] ?? true,
      );
}