import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import 'package:finazaap/data/account_utils.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'dart:collection';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/account_service.dart';

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
  final dynamic transactionKey; // Agregar esta propiedad
  final VoidCallback? onTransactionUpdated;

  const Add_Screen({
    Key? key,
    this.isEditing = false,
    this.transaction,
    this.transactionKey, // Agregar a constructor
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

  // (hacer lo mismo en add_expense.dart y transfer.dart)

  Future<void> _loadAccountsFromPrefs() async {
    try {
      // Obtener solo cuentas activas
      final activeAccountsData = await AccountService.getActiveAccounts();
      final deletedAccountNames = await AccountService.getDeletedAccountNames();

      setState(() {
        _accountItems = activeAccountsData
            .map((jsonData) => AccountItem.fromJson(jsonData))
            .toList();
      });

      // Caso especial para edición con cuenta eliminada
      if (widget.isEditing && widget.transaction != null) {
        final transactionAccountName = widget.transaction!.name;

        // Si la cuenta existe, seleccionarla
        try {
          AccountItem? accountToSelect = _accountItems.firstWhere(
            (account) => account.title.trim() == transactionAccountName.trim(),
          );

          setState(() {
            _selectedAccount = accountToSelect;
          });
        } catch (_) {
          // Si no existe, es porque fue eliminada
          debugPrint('⚠️ Cuenta eliminada detectada: $transactionAccountName');
          // Será manejado por el diálogo de advertencia en home.dart
        }
      }
    } catch (e) {
      debugPrint('❌ Error al cargar cuentas: $e');
    }
  }

// (hacer lo mismo en add_expense.dart cambiando 'Income' por 'Expenses')

  Future<void> _loadCategoriesFromPrefs() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    // Obtener categorías activas y eliminadas
    final String type = 'Income'; // Usar 'Expenses' en add_expense.dart
    List<String> activeCategories = await CategoryService.getCategories(type);
    List<String> deletedCategories = await CategoryService.getDeletedCategories(type);

    debugPrint('📊 Categorías activas: ${activeCategories.length}, eliminadas: ${deletedCategories.length}');

    // Ordenar alfabéticamente
    activeCategories.sort((a, b) => a.compareTo(b));
    
    // CORRECCIÓN: Usar el resultado filtrado, no la lista original
    List<String> categoriasFiltradas = activeCategories
        .where((categoria) => !deletedCategories.contains(categoria))
        .toList();
    
    setState(() {
      // Usar la lista FILTRADA
      _categories = categoriasFiltradas;
      
      // Si estamos editando, verificar si la categoría seleccionada existe
      if (widget.isEditing && widget.transaction != null) {
        final transactionCategory = widget.transaction!.explain;
        
        // NUEVO: Si la categoría fue eliminada, deseleccionarla
        if (deletedCategories.contains(transactionCategory)) {
          _selectedCategory = null; // Forzar al usuario a seleccionar otra
        } else if (categoriasFiltradas.contains(transactionCategory)) {
          _selectedCategory = transactionCategory;
        } else {
          _selectedCategory = null;
        }
      }
    });

    _debugCategories();
  } catch (e) {
    debugPrint('❌ Error al cargar categorías: $e');
  }
}

  // Método para depuración
  void _debugCategories() {
    debugPrint("\n=== DEBUGGING CATEGORIES ===");
    for (var cat in _categories) {
      debugPrint("Categoría cargada: $cat");
    }
    debugPrint("===========================\n");
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
      if (widget.isEditing &&
          widget.transaction != null &&
          widget.transactionKey != null) {
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
          oldTransaction: transaction);
    } catch (e) {
      print('Error al revertir transacción previa: $e');
      throw e;
    }
  }

// Método para mostrar el diálogo de confirmación de eliminación
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2A2A3A),
          title: const Text('Confirmar eliminación',
              style: TextStyle(color: Colors.white)),
          content: const Text('¿Estás seguro que deseas eliminar este ingreso?',
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Cancelar', style: TextStyle(color: Colors.grey)),
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
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colores y constantes de diseño
    const Color primaryColor = Color(0xFF368983);
    const Color surfaceColor = Color(0xFF222939);
    const Color cardColor = Color(0xFF1A1F2B);
    const double cornerRadius = 20.0;

    // Asegurarse de que _selectedCategory exista en _categories
    if (_selectedCategory != null && !_categories.contains(_selectedCategory)) {
      debugPrint('⚠️ Categoría seleccionada no encontrada: $_selectedCategory');
      debugPrint('⚠️ Añadiendo temporalmente a la lista para evitar error');

      // Añadir la categoría temporalmente a la lista
      setState(() {
        _categories.add(_selectedCategory!);
      });

      // NO guardar permanentemente si es una categoría eliminada
      // Solo la añadimos temporalmente para esta edición
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1F2639),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.isEditing ? 'Editar Ingreso' : 'Nuevo Ingreso',
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
                              Icons.arrow_upward_rounded,
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
                                  'Ingreso',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Registra un nuevo ingreso',
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d*$')),
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
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 14),
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
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                              fontSize: 14,
                                            ),
                                          ),
                                          dropdownColor: cardColor,
                                          icon: const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Colors.white54,
                                          ),
                                          isExpanded: true,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedAccount = value;
                                            });
                                          },
                                          items: _accountItems.map((account) {
                                            return DropdownMenuItem<
                                                AccountItem>(
                                              value: account,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          (account.iconColor ??
                                                                  Colors.blue)
                                                              .withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      account.icon ??
                                                          Icons
                                                              .account_balance_wallet,
                                                      color:
                                                          account.iconColor ??
                                                              Colors.blue,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      account.title,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                              color:
                                                  Colors.white.withOpacity(0.5),
                                              fontSize: 14,
                                            ),
                                          ),
                                          dropdownColor: cardColor,
                                          icon: const Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: Colors.white54,
                                          ),
                                          isExpanded: true,
                                          style: const TextStyle(
                                              color: Colors.white),
                                          onChanged: (value) {
                                            setState(() {
                                              _selectedCategory = value;
                                            });
                                          },
                                          items: _categories.map((category) {
                                            return DropdownMenuItem<String>(
                                              value: category,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor
                                                          .withOpacity(0.2),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      _getCategoryIcon(
                                                          category),
                                                      color: primaryColor,
                                                      size: 14,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Flexible(
                                                    child: Text(
                                                      category,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w500,
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
                                            color:
                                                Colors.white.withOpacity(0.3),
                                          ),
                                          border: InputBorder.none,
                                          prefixIcon: const Icon(
                                            Icons.description_outlined,
                                            color: primaryColor,
                                            size: 18,
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  vertical: 14),
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
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 11),
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
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                  onPressed: () => Navigator.of(context)
                                      .popUntil((route) => route.isFirst),
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
                                  onPressed: _saveTransaction,
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
            border:
                isOutlined ? Border.all(color: Colors.white24, width: 1) : null,
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

  // Método para obtener iconos por categoría
  IconData _getCategoryIcon(String category) {
    final Map<String, IconData> categoryIcons = {
      'salario': Icons.work_rounded,
      'inversiones': Icons.trending_up_rounded,
      'devoluciones': Icons.replay_rounded,
      'regalos': Icons.card_giftcard_rounded,
      'premios': Icons.emoji_events_rounded,
      'ventas': Icons.store_rounded,
      'intereses': Icons.account_balance_rounded,
      'otros': Icons.attach_money_rounded,
    };

    final String normalizedCategory = category.toLowerCase();
    return categoryIcons[normalizedCategory] ?? Icons.attach_money_rounded;
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
  static Future<void> updateAccountBalance(
      String accountName, double amount, bool add) async {
    // Código común para actualizar saldos
  }

  static Future<void> revertTransaction(Add_data transaction) async {
    // Código común para revertir transacciones
  }
}
