import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

// Modelo de cuenta adaptado para recibir datos desde selecctaccount.dart
class AccountItem {
  String title;
  double balance;
  IconData? icon; // Opcional
  String? subtitle; // Opcional
  Color? iconColor; // Opcional

  AccountItem({
    required this.title,
    required this.balance,
    this.icon,
    this.subtitle,
    this.iconColor,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'balance': balance is String ? balance : balance.toString(),
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
      // Agregar campos opcionales si están presentes
      icon: json['icon'] != null
          ? IconData(json['icon'], fontFamily: 'MaterialIcons')
          : null,
      subtitle: json['subtitle'],
      iconColor: json['iconColor'] != null ? Color(json['iconColor']) : null,
    );
  }
}

class Add_Screen extends StatefulWidget {
  const Add_Screen({Key? key}) : super(key: key);

  @override
  State<Add_Screen> createState() => _Add_ScreenState();
}

class _Add_ScreenState extends State<Add_Screen> {
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
  // Si solo usarás “Ingreso” en esta vista, puedes dejarlo fijo.
  bool _isIncome = true; // true => Ingreso, false => Egreso

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
        _accountItems = accountsData.map((item) {
          final Map<String, dynamic> jsonData = json.decode(item);
          return AccountItem.fromJson(jsonData);
        }).toList();
      });
    }
  }

  // Carga la lista de categorías guardadas en “ingresos” (ajusta la clave si usas otra)
  Future<void> _loadCategoriesFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? categoriesData = prefs.getStringList('ingresos');
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
  // Guardar la transacción en Hive y actualizar el saldo disponible global
  Future<void> _saveTransaction() async {
    // Validar que se han completado los campos obligatorios
    if (_amountCtrl.text.isEmpty ||
        _selectedAccount == null ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    // Define "Income" o "Expenses"
    final type = _isIncome ? 'Income' : 'Expenses';

    // Creamos la instancia Add_data
    final newAdd = Add_data(
      type, // 'Income' o 'Expenses'
      _amountCtrl.text,
      _selectedDate,
      _detailCtrl.text,
      _selectedCategory ?? 'Sin categoría',
      _selectedAccount?.title ?? 'Sin cuenta',
      0, // iconCode, puedes ajustar esto según sea necesario
    );

    // Guardamos en Hive
    box.add(newAdd);

    // Actualizar el saldo de la cuenta seleccionada
    await _updateAccountBalance(_selectedAccount?.title ?? '',
        double.parse(_amountCtrl.text), _isIncome);

    // Después de actualizar el saldo de la cuenta, actualizamos el saldo disponible global
    await _updateGlobalAvailableBalance();

    // Cerrar esta pantalla
    Navigator.of(context).pop();
  }

// Método auxiliar para actualizar el saldo disponible global
  Future<void> _updateGlobalAvailableBalance() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');

    if (accountsData != null) {
      double totalBalance = 0.0;
      for (var accountJson in accountsData) {
        final Map<String, dynamic> data = json.decode(accountJson);
        // Convertir el balance a double (puede estar como String)
        final balance = data['balance'] is String
            ? double.tryParse(data['balance']) ?? 0.0
            : (data['balance'] is double ? data['balance'] : 0.0);
        totalBalance += balance;
      }

      // Guardar el valor total calculado en SharedPreferences para que
      // total_balance_widget pueda recuperarlo
      await prefs.setDouble('available_balance', totalBalance);

      // Si estamos usando Provider o algún sistema de estado global,
      // podríamos actualizar directamente el notificador aquí:
      // Provider.of<BalanceModel>(context, listen: false).updateBalance(totalBalance);

      // Si tenemos acceso al notificador global:
      // availableBalanceNotifier.value = totalBalance;
    }
  }

  Future<void> _updateAccountBalance(
      String accountTitle, double amount, bool isIncome) async {
    if (accountTitle.isEmpty) return;
    final accountIndex =
        _accountItems.indexWhere((a) => a.title == accountTitle);
    if (accountIndex == -1) return;

    setState(() {
      if (isIncome) {
        _accountItems[accountIndex].balance += amount;
      } else {
        _accountItems[accountIndex].balance -= amount;
      }
    });

    final prefs = await SharedPreferences.getInstance();
    // Convierte solo los campos necesarios para preservar compatibilidad
    final accountsData = _accountItems
        .map((item) => json.encode({
              'title': item.title,
              'subtitle': item.subtitle ?? '',
              'balance': item.balance.toString(),
              'icon': item.icon?.codePoint ?? Icons.account_balance.codePoint,
              'iconColor': item.iconColor?.value ?? Colors.blue.value,
            }))
        .toList();

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
        // Título “Ingreso”
        Text(
          _isIncome ? 'Ingreso' : 'Egreso',
          style: const TextStyle(
            color: Color(0xFF368983), // Verde
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),

        // Fila Monto
        _buildListRow(
          icon: _isIncome ? Icons.arrow_upward : Icons.arrow_downward,
          iconColor: const Color(0xFF368983),
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
          iconColor: const Color(0xFF368983),
          trailing: Expanded(child: _buildAccountsDropdown()),
        ),
        const SizedBox(height: 10),

        // Fila Categoría (dropdown)
        _buildListRow(
          icon: Icons.list_alt,
          iconColor: const Color(0xFF368983),
          trailing: Expanded(child: _buildCategoriesDropdown()),
        ),
        const SizedBox(height: 10),

        // Fila Descripción
        _buildListRow(
          icon: Icons.subject,
          iconColor: const Color(0xFF368983),
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
          iconColor: const Color(0xFF368983),
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
                style: TextStyle(color: Color(0xFF368983)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF368983),
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
          child: Text(account.title),
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
