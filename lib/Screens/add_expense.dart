import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/utlity.dart';
import 'dart:convert';

// Modelo de cuenta adaptado para recibir datos desde selecctaccount.dart
class AccountItem {
  String title;
  double balance;
  IconData? icon;
  String? subtitle;
  Color? iconColor;

  AccountItem({
    required this.title,
    required this.balance,
    this.icon,
    this.subtitle,
    this.iconColor,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'subtitle': subtitle ?? '',
        'balance': balance.toString(), // Convertir a String para compatibilidad
        'icon': icon?.codePoint ?? Icons.account_balance_wallet.codePoint,
        'iconColor': iconColor?.value ?? Colors.blue.value,
      };

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    // Manejar el caso donde balance puede ser String o double
    double balanceValue;
    if (json['balance'] is String) {
      balanceValue = double.tryParse(json['balance']) ?? 0.0;
    } else {
      balanceValue = (json['balance'] is double) ? json['balance'] : 0.0;
    }

    return AccountItem(
      title: json['title'],
      balance: balanceValue,
      icon: json['icon'] != null
          ? IconData(json['icon'], fontFamily: 'MaterialIcons')
          : null,
      subtitle: json['subtitle'],
      iconColor: json['iconColor'] != null ? Color(json['iconColor']) : null,
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({Key? key}) : super(key: key);

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final box = Hive.box<Add_data>('data');

  // ========= CONTROLADORES DE TEXTO =========
  final TextEditingController _amountCtrl = TextEditingController(); // Monto
  final TextEditingController _detailCtrl =
      TextEditingController(); // Descripción

  // ========= LISTAS DE DATOS =========
  List<AccountItem> _accountItems = []; // Para “Cuenta”
  List<String> _categories = []; // Para “Categoría”

  // ========= SELECCIONES DEL USUARIO =========
  AccountItem? _selectedAccount;
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  // (Opcional) Para “Ingreso” / “Egreso”
  // Si solo usarás “Egreso” en esta vista, puedes dejarlo fijo.
  bool _isIncome = false; // true => Ingreso, false => Egreso

  @override
  void initState() {
    super.initState();
    _loadAccountsFromPrefs();
    _loadCategoriesFromPrefs();
  }

  // Carga la lista de cuentas guardadas en “accounts”
  Future<void> _loadAccountsFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');
    if (accountsData != null) {
      setState(() {
        _accountItems = accountsData
            .map((item) => AccountItem.fromJson(json.decode(item)))
            .toList();
      });
    }
  }

  // Carga la lista de categorías guardadas en “gastos” (ajusta la clave si usas otra)
  Future<void> _loadCategoriesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? categoriesData = prefs.getStringList('gastos');
    if (categoriesData != null) {
      setState(() {
        _categories = categoriesData
            .map((item) => json.decode(item)['text'] as String)
            .toList();
      });
    }
  }

  // Abre el DatePicker para seleccionar fecha
  Future<void> _pickDate() async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (newDate != null) {
      setState(() {
        _selectedDate = newDate;
      });
    }
  }

  // Guardar la transacción en Hive
  void _saveTransaction() {
    // Define “Income” o “Expenses”
    final type = _isIncome ? 'Income' : 'Expenses';

    // Actualiza el saldo de la cuenta asociada
    if (_selectedAccount != null) {
      double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
      setState(() {
        if (_isIncome) {
          _selectedAccount!.balance += amount;
        } else {
          _selectedAccount!.balance -= amount;
        }
      });

      // Guarda la cuenta actualizada en SharedPreferences
      _saveAccountsToPrefs();
    }

    // Creamos la instancia Add_data
    final newAdd = Add_data(
      type, // 'Income' o 'Expenses'
      _amountCtrl.text,
      _selectedDate,
      _detailCtrl.text,
      _selectedCategory ?? 'Sin categoría',
      _selectedAccount?.title ??
          'Sin cuenta', // Asegúrate de que aquí se espera un String
      0, // iconCode, puedes ajustar esto según sea necesario
    );

    // Guardamos en Hive
    box.add(newAdd);
    Navigator.of(context).pop();
  }

  // Guarda la lista de cuentas en SharedPreferences
  Future<void> _saveAccountsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accountsData =
        _accountItems.map((item) => json.encode(item.toJson())).toList();
    prefs.setStringList('accounts', accountsData);
  }

  @override
  Widget build(BuildContext context) {
    // Fondo oscuro general
    return Scaffold(
      backgroundColor: const Color(0xFF1F2639),
      body: SafeArea(
        child: Center(
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildForm(),
          ),
        ),
      ),
    );
  }

  // Construye el formulario estilo imagen
  Widget _buildForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título “Egreso”
        Text(
          'Egreso',
          style: const TextStyle(
            color: Color(0xFFFF6F61), // Rojo pálido
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // Fila Monto
        _buildListRow(
          icon: Icons.arrow_downward,
          iconColor: const Color(0xFFFF6F61), // Rojo pálido
          trailing: Expanded(
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Monto',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Fila Cuenta (dropdown)
        _buildListRow(
          icon: Icons.account_balance_wallet,
          iconColor: const Color(0xFFFF6F61), // Rojo pálido
          trailing: Expanded(child: _buildAccountsDropdown()),
        ),
        const SizedBox(height: 10),

        // Fila Categoría (dropdown)
        _buildListRow(
          icon: Icons.list_alt,
          iconColor: const Color(0xFFFF6F61), // Rojo pálido
          trailing: Expanded(child: _buildCategoriesDropdown()),
        ),
        const SizedBox(height: 10),

        // Fila Descripción
        _buildListRow(
          icon: Icons.subject,
          iconColor: const Color(0xFFFF6F61), // Rojo pálido
          trailing: Expanded(
            child: TextField(
              controller: _detailCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Detalles',
                hintStyle: TextStyle(color: Colors.grey),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Fila Fecha
        _buildListRow(
          icon: Icons.calendar_month,
          iconColor: const Color(0xFFFF6F61), // Rojo pálido
          trailing: Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(_selectedDate),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: _pickDate,
                icon: const Icon(Icons.edit_calendar, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Botones Cancelar y Guardar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Color(0xFFFF6F61)), // Rojo pálido
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F61), // Rojo pálido
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _saveTransaction,
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Construye una fila con ícono + trailing
  Widget _buildListRow({
    required IconData icon,
    required Color iconColor,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey, width: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: trailing),
        ],
      ),
    );
  }

  // Dropdown de Cuentas
  Widget _buildAccountsDropdown() {
    return DropdownButton<AccountItem>(
      value: _selectedAccount,
      hint: const Text('Cuenta', style: TextStyle(color: Colors.grey)),
      dropdownColor: const Color(0xFF2A2A3A),
      iconEnabledColor: Colors.white,
      underline: Container(),
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        setState(() {
          _selectedAccount = value;
        });
      },
      items: _accountItems.map((account) {
        return DropdownMenuItem<AccountItem>(
          value: account,
          child: Row(
            children: [
              if (account.icon != null)
                Icon(account.icon,
                    color: account.iconColor ?? Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(account.title),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Dropdown de Categorías
  Widget _buildCategoriesDropdown() {
    return DropdownButton<String>(
      value: _selectedCategory,
      hint: const Text('Categoria', style: TextStyle(color: Colors.grey)),
      dropdownColor: const Color(0xFF2A2A3A),
      iconEnabledColor: Colors.white,
      underline: Container(),
      style: const TextStyle(color: Colors.white),
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
      items: _categories.map((cat) {
        return DropdownMenuItem<String>(
          value: cat,
          child: Text(cat),
        );
      }).toList(),
    );
  }

  // Formatea la fecha en dd/mm/yyyy
  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString();
    return '$day/$month/$year';
  }
}
