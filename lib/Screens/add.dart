import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:finazaap/data/account_utils.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter

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
  final bool isEditing;
  final Add_data? transaction;
  final dynamic transactionKey;  // Agregar esta propiedad
  final VoidCallback? onTransactionUpdated;

  const Add_Screen({
    Key? key, 
    this.isEditing = false, 
    this.transaction,
    this.transactionKey,  // Agregar a constructor
    this.onTransactionUpdated,
  }) : super(key: key);

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
    
    // Cargar datos si estamos en modo edición
    if (widget.isEditing && widget.transaction != null) {
      _loadTransactionData();
    }
  }

  // Método para cargar los datos de la transacción
  void _loadTransactionData() {
    final transaction = widget.transaction!;
    
    // Cargar valores en controladores
    _amountCtrl.text = transaction.amount;
    _detailCtrl.text = transaction.detail;
    _selectedDate = transaction.datetime;
    _selectedCategory = transaction.explain; 
    
    // Para asegurarse que la cuenta se cargue correctamente
    _loadAccountsFromPrefs().then((_) {
      // Buscar la cuenta por nombre exacto después de que las cuentas estén cargadas
      AccountItem? accountToSelect;
      
      try {
        accountToSelect = _accountItems.firstWhere(
          (account) => account.title.trim() == transaction.name.trim(),
        );
      } catch (_) {
        // Si no encuentra la cuenta, usar la primera si existe
        if (_accountItems.isNotEmpty) {
          accountToSelect = _accountItems.first;
        }
      }
      
      if (accountToSelect != null) {
        setState(() {
          _selectedAccount = accountToSelect;
        });
      }
    });
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

  // Reemplazar el método _saveTransaction con esta versión mejorada

Future<void> _saveTransaction() async {
  // Validaciones básicas
  if (_amountCtrl.text.isEmpty || _selectedAccount == null || _selectedCategory == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor completa todos los campos')),
    );
    return;
  }

  try {
    final amount = double.parse(_amountCtrl.text);
    final int categoryIconCode = _getCategoryIconCode(_selectedCategory!);
    
    // Crear objeto de transacción
    final Add_data transaction = Add_data(
      'Income',
      _amountCtrl.text,
      _selectedDate,
      _detailCtrl.text,
      _selectedCategory!,
      _selectedAccount!.title,
      categoryIconCode,
    );
    
    // Guardar transacción en Hive y actualizar saldos
    if (widget.isEditing && widget.transaction != null && widget.transactionKey != null) {
      // Modo edición - procesar cambios de manera atómica
      bool success = await TransactionService.processTransaction(
        type: 'Income',
        amount: amount,
        accountName: _selectedAccount!.title,
        isNewTransaction: false,
        oldTransaction: widget.transaction,
      );
      
      if (success) {
        // Actualizar en Hive solo si la actualización de saldo tuvo éxito
        box.put(widget.transactionKey, transaction);
      } else {
        throw Exception('Error al actualizar el saldo de la cuenta');
      }
    } else {
      // Modo creación - procesar cambios de manera atómica
      bool success = await TransactionService.processTransaction(
        type: 'Income',
        amount: amount,
        accountName: _selectedAccount!.title,
        isNewTransaction: true,
      );
      
      if (success) {
        // Guardar en Hive solo si la actualización de saldo tuvo éxito
        box.add(transaction);
      } else {
        throw Exception('Error al actualizar el saldo de la cuenta');
      }
    }

    // Notificar a la pantalla principal
    if (widget.onTransactionUpdated != null) {
      widget.onTransactionUpdated!();
    }

    // Pequeño retraso para asegurar que los datos se han guardado
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Navegar de vuelta
    if (mounted) {
      Navigator.pop(context);
    }
  } catch (e) {
    print('Error al guardar: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
    );
  }
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

  // Método para revertir el efecto de la transacción anterior
  Future<void> _revertPreviousTransaction(Add_data transaction) async {
  try {
    final amount = double.parse(transaction.amount);
    
    // Usar el método existente en TransactionService en lugar del que falta
    await TransactionService.processTransaction(
      type: transaction.IN,
      amount: amount,
      accountName: transaction.name,
      isNewTransaction: false,
      oldTransaction: transaction
    );
  } catch (e) {
    print('Error al revertir transacción previa: $e');
    throw e;
  }
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              // Añadir filtro para permitir solo números y punto decimal
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
              ],
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
              onPressed: () {
                // Navegar directamente a la pantalla de inicio
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF368983),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                try {
                  await _saveTransaction();
                  
                  // Notificar actualización primero
                  if (widget.onTransactionUpdated != null) {
                    widget.onTransactionUpdated!();
                  }
                  
                  // Navegar hacia atrás de manera segura
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
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

  // Método auxiliar para obtener el código de icono
  int _getCategoryIconCode(String categoryName) {
    // Mapa de categorías de ingresos a iconos
    final Map<String, int> categoryIcons = {
      'salario': Icons.work.codePoint,
      'inversiones': Icons.trending_up.codePoint,
      'devoluciones': Icons.replay.codePoint,
      'regalos': Icons.card_giftcard.codePoint,
      'premios': Icons.emoji_events.codePoint,
      'ventas': Icons.monetization_on.codePoint,
      'intereses': Icons.account_balance.codePoint,
      'otros': Icons.add_box.codePoint,
      // Agregar también las categorías de gastos para tener todo en un solo lugar
      'comida': Icons.restaurant.codePoint,
      'transporte': Icons.directions_car.codePoint,
      'entretenimiento': Icons.movie.codePoint,
      'servicios': Icons.build.codePoint,
    };
    
    // Convertir a minúsculas para evitar problemas de coincidencia
    final normalizedCategory = categoryName.toLowerCase();
    
    // Devolver el icono correspondiente o un icono predeterminado
    return categoryIcons[normalizedCategory] ?? Icons.attach_money.codePoint;
  }
}

// filepath: d:\programacion 5.0\finazaap\lib\data\account_utils.dart
class AccountUtils {
  static Future<void> updateAccountBalance(String accountName, double amount, bool add) async {
    // Código común para actualizar saldos
  }
  
  static Future<void> revertTransaction(Add_data transaction) async {
    // Código común para revertir transacciones
  }
}
