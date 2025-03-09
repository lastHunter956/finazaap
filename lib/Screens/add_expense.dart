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
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
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
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colores y constantes de diseño
    const Color primaryColor = Colors.redAccent;  // Rojo para gastos
    const Color surfaceColor = Color(0xFF222939);
    const Color cardColor = Color(0xFF1A1F2B);
    const double cornerRadius = 20.0;
    
    return Scaffold(
      backgroundColor: const Color(0xFF1F2639),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Editar Egreso' : 'Nuevo Egreso',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Contenedor principal más compacto
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(cornerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                      spreadRadius: -5,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado más compacto con flexbox para el título
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            primaryColor.withOpacity(0.15),
                            primaryColor.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(cornerRadius),
                          topRight: Radius.circular(cornerRadius),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Icono más pequeño
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: primaryColor,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Texto más compacto
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Egreso',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Registra un nuevo egreso',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Formulario más compacto
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Campo de monto
                          _buildInputLabel('Monto'),
                          _buildInputField(
                            child: TextField(
                              controller: _amountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                              ],
                              decoration: InputDecoration(
                                hintText: '0.00',
                                hintStyle: TextStyle(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                                border: InputBorder.none,
                                prefixIcon: const Icon(
                                  Icons.attach_money_rounded,
                                  color: primaryColor,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Fila para cuenta y categoría (dos columnas)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cuenta (izquierda)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Cuenta'),
                                    _buildInputField(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<AccountItem>(
                                          value: _selectedAccount,
                                          hint: Text(
                                            'Cuenta',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 14,
                                            ),
                                          ),
                                          dropdownColor: cardColor,
                                          icon: const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Colors.white54,
                                          ),
                                          isExpanded: true,
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedAccount = value;
                                            });
                                          },
                                          items: _accountItems.map((account) {
                                            // Extraer ícono y color
                                            final IconData iconData = account.icon ?? Icons.account_balance_wallet;
                                            final Color iconColor = account.iconColor ?? Colors.blue;
                                            
                                            return DropdownMenuItem<AccountItem>(
                                              value: account,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: iconColor.withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      iconData,
                                                      color: iconColor,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      account.title,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Categoría (derecha)
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Categoría'),
                                    _buildInputField(
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _selectedCategory,
                                          hint: Text(
                                            'Categoría',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
                                              fontSize: 14,
                                            ),
                                          ),
                                          dropdownColor: cardColor,
                                          icon: const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Colors.white54,
                                          ),
                                          isExpanded: true,
                                          style: const TextStyle(color: Colors.white),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedCategory = value;
                                            });
                                          },
                                          items: _categories.map((category) {
                                            final IconData categoryIcon = IconData(
                                              _getCategoryIconCode(category),
                                              fontFamily: 'MaterialIcons'
                                            );
                                            
                                            return DropdownMenuItem<String>(
                                              value: category,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor.withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      categoryIcon,
                                                      color: primaryColor,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      category,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Fila para descripción y fecha
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Descripción (izquierda)
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Descripción'),
                                    _buildInputField(
                                      child: TextField(
                                        controller: _detailCtrl,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                        decoration: InputDecoration(
                                          hintText: 'Detalles...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withOpacity(0.3),
                                          ),
                                          border: InputBorder.none,
                                          prefixIcon: const Icon(
                                            Icons.description_outlined,
                                            color: primaryColor,
                                            size: 18,
                                          ),
                                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Fecha (derecha, más pequeña)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildInputLabel('Fecha'),
                                    InkWell(
                                      onTap: _pickDate,
                                      borderRadius: BorderRadius.circular(12),
                                      child: _buildInputField(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 11),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.calendar_today_rounded,
                                                color: primaryColor,
                                                size: 18,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _formatDate(_selectedDate),
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 20),
                          
                          // Botones de acción más compactos
                          Row(
                            children: [
                              // Botón cancelar
                              Expanded(
                                flex: 1,
                                child: _buildActionButton(
                                  label: 'Cancelar',
                                  icon: Icons.close_rounded,
                                  color: Colors.white54,
                                  isOutlined: true,
                                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                                ),
                              ),
                              
                              const SizedBox(width: 12),
                              
                              // Botón guardar
                              Expanded(
                                flex: 2,
                                child: _buildActionButton(
                                  label: 'Guardar',
                                  icon: Icons.check_rounded,
                                  color: primaryColor,
                                  onPressed: () async {
                                    try {
                                      // Mostrar indicador de carga
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return const Center(child: CircularProgressIndicator());
                                        },
                                      );
                                      
                                      // Guardar la transacción
                                      await _saveTransaction();
                                      
                                      // Cerrar el indicador de carga y regresar a la página principal
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      
                                      // Ir a la pantalla principal
                                      if (mounted) {
                                        Navigator.of(context).popUntil((route) => route.isFirst);
                                      }
                                    } catch (e) {
                                      // Cerrar el indicador de carga en caso de error
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                      
                                      // Mostrar mensaje de error
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Error: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Método helper para etiquetas de campos más compactas
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Método helper para campos de entrada más compactos
  Widget _buildInputField({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: child,
    );
  }

  // Método para formatear la fecha de manera legible
  String _formatDate(DateTime date) {
    // Formato: dd/MM/yyyy
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  // Método helper para botones de acción más compactos
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool isOutlined = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(12),
            border: isOutlined
                ? Border.all(color: Colors.white24, width: 1)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: isOutlined ? color : Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: isOutlined ? color : Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
