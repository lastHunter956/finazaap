import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/utlity.dart';
import 'dart:convert';
import 'package:finazaap/data/account_utils.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter

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

    // Manejo mejorado para el icono
    IconData? iconData;
    if (json['icon'] != null) {
      if (json['icon'] is int) {
        iconData = IconData(json['icon'], fontFamily: 'MaterialIcons');
      } else if (json['icon'] is String) {
        // En caso que el icono venga como string (código en hexadecimal)
        iconData = IconData(
            int.tryParse(json['icon']) ??
                Icons.account_balance_wallet.codePoint,
            fontFamily: 'MaterialIcons');
      }
    }

    // Manejo mejorado para el color del icono
    Color? iconColor;
    if (json['iconColor'] != null) {
      if (json['iconColor'] is int) {
        iconColor = Color(json['iconColor']);
      } else if (json['iconColor'] is String) {
        // En caso que el color venga como string (código en hexadecimal)
        iconColor = Color(
            int.tryParse(json['iconColor'] ?? '0xFF4C8BF5') ?? 0xFF4C8BF5);
      }
    }

    return AccountItem(
      title: json['title'] ?? '',
      balance: balanceValue,
      icon: iconData,
      subtitle: json['subtitle'],
      iconColor: iconColor,
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  final bool isEditing;
  final Add_data? transaction;
  final dynamic transactionKey; // Añadir este campo
  final VoidCallback? onTransactionUpdated;

  const AddExpenseScreen({
    Key? key,
    this.isEditing = false,
    this.transaction,
    this.transactionKey, // Añadir al constructor
    this.onTransactionUpdated,
  }) : super(key: key);

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
    _debugPrintAllIconCodes(); // Añadir esta línea

    // Cargar datos si estamos en modo edición
    if (widget.isEditing && widget.transaction != null) {
      _loadTransactionData();
    }
  }
 
  void _debugPrintAllIconCodes() {
  print("\n=== DEBUGGING ICON CODES ===");
  for (var item in box.values.toList()) {
    print("Transacción: ${item.explain} - iconCode: ${item.iconCode}");
  }
  print("===========================\n");
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

  // Reemplazar el método _saveTransaction con esta versión mejorada

  Future<void> _saveTransaction() async {
    // Validaciones básicas
    if (_amountCtrl.text.isEmpty ||
        _selectedAccount == null ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos')),
      );
      return;
    }

    try {
      final amount = double.parse(_amountCtrl.text);

      // Obtener el código del icono para esta categoría específica
      final int categoryIconCode = _getCategoryIconCode(_selectedCategory!);

      // Crear objeto de transacción con el iconCode
      final Add_data transaction = Add_data(
        'Expenses',
        _amountCtrl.text,
        _selectedDate,
        _detailCtrl.text,
        _selectedCategory!,
        _selectedAccount!.title,
        categoryIconCode, // Asegurar que este parámetro se está pasando correctamente
      );

      // Guardar transacción en Hive y actualizar saldos
      if (widget.isEditing &&
          widget.transaction != null &&
          widget.transactionKey != null) {
        // Modo edición - procesar cambios de manera atómica
        bool success = await TransactionService.processTransaction(
          type: 'Expenses',
          amount: amount,
          accountName: _selectedAccount!.title,
          isNewTransaction: false,
          oldTransaction: widget.transaction,
        );

        if (success) {
          // Actualizar en Hive solo si la actualización de saldo tuvo éxito
          box.put(widget.transactionKey, transaction);
          print('Categoría guardada con iconCode: $categoryIconCode');
        } else {
          throw Exception('Error al actualizar el saldo de la cuenta');
        }
      } else {
        // Modo creación - procesar cambios de manera atómica
        bool success = await TransactionService.processTransaction(
          type: 'Expenses',
          amount: amount,
          accountName: _selectedAccount!.title,
          isNewTransaction: true,
        );

        if (success) {
          // Guardar en Hive solo si la actualización de saldo tuvo éxito
          box.add(transaction);
          print('Nueva categoría guardada con iconCode: $categoryIconCode');
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

// Reemplazar la llamada a updateAccountBalanceOnTransaction por la API correcta
  Future<void> _revertPreviousTransaction(Add_data transaction) async {
    try {
      final amount = double.parse(transaction.amount);

      // Usar el método existente en TransactionService en lugar del que falta
      await TransactionService.processTransaction(
          type: transaction.IN,
          amount: amount,
          accountName: transaction.name,
          isNewTransaction: false,
          oldTransaction: transaction);
    } catch (e) {
      print('Error al revertir transacción previa: $e');
      throw e;
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

      // Guardar el valor total calculado en SharedPreferences
      await prefs.setDouble('available_balance', totalBalance);
    }
  }

  // Guarda la lista de cuentas en SharedPreferences
  Future<void> _saveAccountsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accountsData =
        _accountItems.map((item) => json.encode(item.toJson())).toList();
    prefs.setStringList('accounts', accountsData);
  }

  // Método para cargar los datos del gasto
  void _loadTransactionData() {
    final transaction = widget.transaction!;

    // Cargar los valores en los controladores y estado
    _amountCtrl.text = transaction.amount;
    _detailCtrl.text = transaction.detail;
    _selectedDate = transaction.datetime;
    _selectedCategory = transaction.explain; // Categoría

    // Cargar las cuentas primero y luego buscar la correcta
    _loadAccountsFromPrefs().then((_) {
      // Buscar la cuenta por nombre exacto
      try {
        final accountToSelect = _accountItems.firstWhere(
          (account) => account.title.trim() == transaction.name.trim(),
        );
        setState(() {
          _selectedAccount = accountToSelect;
        });
      } catch (e) {
        // Si no encuentra la cuenta exacta, mostrar un mensaje de error
        print('Error: No se encontró la cuenta ${transaction.name}: $e');
        // Usar la primera cuenta como fallback si hay cuentas disponibles
        if (_accountItems.isNotEmpty) {
          setState(() {
            _selectedAccount = _accountItems.first;
          });
        }
      }
    });
  }

  // 1. Agregar el método _getCategoryIconCode
  int _getCategoryIconCode(String categoryName) {
    // Mapa de categorías de gastos a iconos
    final Map<String, int> categoryIcons = {
      'alimentación': Icons.restaurant.codePoint,
      'transporte': Icons.directions_car.codePoint,
      'entretenimiento': Icons.movie.codePoint,
      'servicios': Icons.build.codePoint,
      'salud': Icons.medical_services.codePoint,
      'educación': Icons.school.codePoint,
      'ropa': Icons.shopping_bag.codePoint,
      'hogar': Icons.home.codePoint,
      'viajes': Icons.flight.codePoint,
      'tecnología': Icons.computer.codePoint,
    };

    // Convertir a minúsculas para evitar problemas de coincidencia
    final normalizedCategory = categoryName.toLowerCase();

    // Devolver el icono correspondiente o un icono predeterminado
    return categoryIcons[normalizedCategory] ?? Icons.category.codePoint;
  }

  // 2. Agregar el método _updateAccountBalance
  Future<void> _updateAccountBalance(
      String accountName, double amount, bool add) async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');

    if (accountsData != null) {
      List<AccountItem> accounts = [];
      bool updated = false;

      for (var accountJson in accountsData) {
        final Map<String, dynamic> data = json.decode(accountJson);
        final account = AccountItem.fromJson(data);

        if (account.title == accountName) {
          if (add) {
            account.balance += amount;
          } else {
            account.balance -= amount;
          }
          updated = true;
        }

        accounts.add(account);
      }

      if (updated) {
        List<String> updatedAccountsData =
            accounts.map((item) => json.encode(item.toJson())).toList();
        await prefs.setStringList('accounts', updatedAccountsData);
      }
    }
  }

  // Método para mostrar el diálogo de confirmación de eliminación
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3A),
          title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
          content: const Text('¿Estás seguro que deseas eliminar esta transacción?', style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Cerrar el diálogo
                
                try {
                  // Mostrar indicador de carga
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(child: CircularProgressIndicator());
                    },
                  );
                  
                  // Revertir el efecto de la transacción en el saldo de la cuenta
                  if (widget.transaction != null) {
                    await _revertPreviousTransaction(widget.transaction!);
                  }
                  
                  // Eliminar la transacción del box de Hive
                  if (widget.transactionKey != null) {
                    box.delete(widget.transactionKey);
                  }
                  
                  // Actualizar el saldo global disponible
                  await _updateGlobalAvailableBalance();
                  
                  // Notificar a la pantalla principal
                  if (widget.onTransactionUpdated != null) {
                    widget.onTransactionUpdated!();
                  }
                  
                  // Cerrar el indicador de carga
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  
                  // Volver a la pantalla anterior
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  // Cerrar el indicador de carga
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  
                  // Mostrar error
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error al eliminar: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
            // Contenedor para botones de la izquierda (Cancelar y Eliminar)
            Row(
              children: [
                // Botón Cancelar
                TextButton(
                  onPressed: () {
                    // Navegar directamente a la pantalla de inicio
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: Color(0xFFFF6F61)),
                  ),
                ),
                
                // Botón Eliminar (solo en modo edición)
                if (widget.isEditing && widget.transaction != null)
                  TextButton.icon(
                    onPressed: () => _showDeleteConfirmation(),
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
            
            // Botón Guardar (a la derecha)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6F61), // Rojo pálido
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                // Código existente para guardar
                try {
                  // Mostrar indicador de carga
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  );

                  // Guardar la transacción
                  await _saveTransaction();

                  // Cerrar el indicador de carga
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // Volver a la pantalla anterior con un pequeño retraso
                  await Future.delayed(const Duration(milliseconds: 200));
                  if (mounted && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                } catch (e) {
                  // Cerrar el indicador de carga
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }

                  // Mostrar error
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
        // Mejora de la conversión de iconos
        IconData getIconFromAccount(AccountItem account) {
          // Si ya tenemos un IconData, usarlo directamente
          if (account.icon != null) {
            return account.icon!;
          }

          // Si no, intentar extraerlo del json
          final accountJson = account.toJson();
          if (accountJson.containsKey('icon')) {
            final iconCode = accountJson['icon'];
            if (iconCode is int) {
              return IconData(iconCode, fontFamily: 'MaterialIcons');
            }
          }

          // Valor predeterminado si todo falla
          return Icons.account_balance_wallet;
        }

        // Mejora para recuperar el color del icono
        Color getIconColor(AccountItem account) {
          if (account.iconColor != null) {
            return account.iconColor!;
          }

          final accountJson = account.toJson();
          if (accountJson.containsKey('iconColor')) {
            final colorValue = accountJson['iconColor'];
            if (colorValue is int) {
              return Color(colorValue);
            }
          }

          return Colors.blue; // Color predeterminado
        }

        // Obtener el icono y color usando las funciones mejoradas
        final iconData = getIconFromAccount(account);
        final iconColor = getIconColor(account);

        return DropdownMenuItem<AccountItem>(
          value: account,
          child: Row(
            children: [
              // Siempre mostrar un icono
              Icon(iconData, color: iconColor, size: 18),
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
