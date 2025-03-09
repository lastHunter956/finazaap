import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Para formatear números
import 'package:hive/hive.dart'; // Importar Hive
import 'package:finazaap/data/model/add_date.dart'; // Importar modelo Add_data
import 'package:finazaap/data/account_utils.dart';
import 'package:finazaap/data/transaction_service.dart';
// Añadir en la parte superior del archivo
import 'package:finazaap/widgets/bottomnavigationbar.dart';

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

class TransferScreen extends StatefulWidget {
  final bool isEditing;
  final Add_data? transaction;
  final dynamic transactionKey;  // Añadir este campo
  final VoidCallback? onTransactionUpdated;

  const TransferScreen({
    Key? key, 
    this.isEditing = false, 
    this.transaction,
    this.transactionKey,  // Añadir al constructor
    this.onTransactionUpdated,
  }) : super(key: key);
  
  @override
  _TransferScreenState createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  // Añadir esta línea para definir la variable box
  final box = Hive.box<Add_data>('data');
  
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _detailCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  AccountItem? _selectedSourceAccount;
  AccountItem? _selectedDestinationAccount;
  List<AccountItem> _accountItems = [];
  bool _isProcessing =
      false; // Para prevenir múltiples transferencias simultáneas

  // Formateador para los números
  final currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadAccountsFromPrefs();
    
    // Cargar datos si estamos en modo edición
    if (widget.isEditing && widget.transaction != null) {
      _loadTransactionData();
    }
  }

  Future<void> _loadAccounts() async {
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

  // Reemplazar el método _saveTransfer con esta versión mejorada

Future<void> _saveTransfer() async {
  if (_amountCtrl.text.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor ingresa un monto')),
    );
    return;
  }

  if (_selectedSourceAccount == null || _selectedDestinationAccount == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Por favor selecciona cuentas')),
    );
    return;
  }

  // Verificar que no sean la misma cuenta
  if (_selectedSourceAccount!.title == _selectedDestinationAccount!.title) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No puedes transferir a la misma cuenta')),
    );
    return;
  }

  try {
    setState(() {
      _isProcessing = true;
    });

    final amount = double.parse(_amountCtrl.text);
    
    // Crear objeto de transferencia
    final Add_data transferTransaction = Add_data(
      'Transfer',
      _amountCtrl.text,
      _selectedDate,
      _detailCtrl.text,
      '${_selectedSourceAccount!.title} > ${_selectedDestinationAccount!.title}',
      '',
      Icons.sync_alt.codePoint,
    );

    // Procesar la transferencia de manera atómica
    if (widget.isEditing && widget.transaction != null && widget.transactionKey != null) {
      // Modo edición
      bool success = await TransactionService.processTransaction(
        type: 'Transfer',
        amount: amount,
        accountName: _selectedSourceAccount!.title,
        destinationAccount: _selectedDestinationAccount!.title,
        isNewTransaction: false,
        oldTransaction: widget.transaction,
      );
      
      if (success) {
        box.put(widget.transactionKey, transferTransaction);
      } else {
        throw Exception('Error al actualizar los saldos de las cuentas');
      }
    } else {
      // Modo creación
      bool success = await TransactionService.processTransaction(
        type: 'Transfer',
        amount: amount,
        accountName: _selectedSourceAccount!.title,
        destinationAccount: _selectedDestinationAccount!.title,
        isNewTransaction: true,
      );
      
      if (success) {
        box.add(transferTransaction);
      } else {
        throw Exception('Error al actualizar los saldos de las cuentas');
      }
    }

    // Notificar a la pantalla principal
    if (widget.onTransactionUpdated != null) {
      widget.onTransactionUpdated!();
    }

    // Finalizar
    setState(() {
      _isProcessing = false;
    });

    // Pequeña espera para asegurar que todo se ha guardado
    await Future.delayed(const Duration(milliseconds: 100));
    
    // Volver a la pantalla anterior
    if (mounted) {
      Navigator.of(context).pop();
    }
  } catch (e) {
    setState(() {
      _isProcessing = false;
    });
    
    print('Error al guardar la transferencia: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // Método para guardar las cuentas actualizadas
  Future<void> _saveAccountsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Serializar los objetos AccountItem a JSON
    List<String> accountsData = _accountItems.map((item) {
      // Crear mapa con todos los datos necesarios de la cuenta
      final Map<String, dynamic> itemMap = {
        'title': item.title,
        'balance': item.balance.toString(), // Guardar como String para evitar problemas de precisión
        'icon': item.icon?.codePoint ?? Icons.account_balance_wallet.codePoint,
        'iconColor': item.iconColor?.value ?? Colors.blue.value,
        'subtitle': item.subtitle ?? '',
        'includeInTotal': true // Por defecto incluir en total
      };
      
      return json.encode(itemMap);
    }).toList();
    
    // Guardar en SharedPreferences
    await prefs.setStringList('accounts', accountsData);
    
    // Imprimir para debug
    print('Cuentas actualizadas exitosamente. Nuevos saldos: ' +
        _accountItems.map((a) => "${a.title}: ${a.balance}").join(', '));
  }

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

  Future<void> _updateAccountBalance(String accountName, double amount, bool add) async {
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

  @override
Widget build(BuildContext context) {
  // Colores y constantes de diseño
  const Color primaryColor = Color(0xFF3D7AF0); // Azul para transferencias
  const Color surfaceColor = Color(0xFF222939);
  const Color cardColor = Color(0xFF1A1F2B);
  const double cornerRadius = 20.0;
  
  return Scaffold(
    backgroundColor: const Color(0xFF1F2639),
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        widget.isEditing ? 'Editar Transferencia' : 'Nueva Transferencia',
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
                            Icons.swap_horiz_rounded,
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
                                'Transferencia',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Movimiento entre cuentas',
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

                        // Cuenta de origen
                        _buildInputLabel('Cuenta de origen'),
                        _buildInputField(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AccountItem>(
                              value: _selectedSourceAccount,
                              hint: Text(
                                'Seleccionar origen',
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
                                  _selectedSourceAccount = value;
                                });
                              },
                              items: _accountItems.map((account) {
                                return DropdownMenuItem<AccountItem>(
                                  value: account,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: (account.iconColor ?? Colors.blue).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          account.icon ?? Icons.account_balance_wallet,
                                          color: account.iconColor ?? Colors.blue,
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
                        
                        // Mostrar saldo disponible si hay cuenta seleccionada
                        if (_selectedSourceAccount != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 10, left: 12),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.account_balance_wallet_outlined,
                                  size: 14,
                                  color: primaryColor.withOpacity(0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Saldo disponible: ${currencyFormat.format(_selectedSourceAccount!.balance)} \$',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        
                        const SizedBox(height: 14),

                        // Cuenta de destino
                        _buildInputLabel('Cuenta de destino'),
                        _buildInputField(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AccountItem>(
                              value: _selectedDestinationAccount,
                              hint: Text(
                                'Seleccionar destino',
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
                                  _selectedDestinationAccount = value;
                                });
                              },
                              items: _accountItems.map((account) {
                                return DropdownMenuItem<AccountItem>(
                                  value: account,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: (account.iconColor ?? Colors.blue).withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          account.icon ?? Icons.account_balance_wallet,
                                          color: account.iconColor ?? Colors.blue,
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
                                        hintText: 'Detalle (opcional)',
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
                                    onTap: () async {
                                      final newDate = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime(2100),
                                        builder: (context, child) {
                                          return Theme(
                                            data: ThemeData.dark().copyWith(
                                              colorScheme: ColorScheme.dark(
                                                primary: primaryColor,
                                                onPrimary: Colors.white,
                                                surface: cardColor,
                                                onSurface: Colors.white,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (newDate != null) {
                                        setState(() {
                                          _selectedDate = newDate;
                                        });
                                      }
                                    },
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
                            
                            // Botón transferir/actualizar
                            Expanded(
                              flex: 2,
                              child: _buildActionButton(
                                label: widget.isEditing ? 'Actualizar' : 'Transferir',
                                icon: Icons.swap_horiz_rounded,
                                color: primaryColor,
                                isLoading: _isProcessing,
                                onPressed: _isProcessing ? null : () async {
                                  try {
                                    // Mostrar indicador de carga inline
                                    setState(() {
                                      _isProcessing = true;
                                    });
                                    
                                    // Guardar la transferencia
                                    await _saveTransfer();
                                    
                                    // Volver a la pantalla principal
                                    if (mounted) {
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                    }
                                  } catch (e) {
                                    setState(() {
                                      _isProcessing = false;
                                    });
                                    // Error manejado en _saveTransfer
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

// Para corregir el error de _formatDate, añadir este método
String _formatDate(DateTime date) {
  return '${date.day}/${date.month}/${date.year}';
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
  required VoidCallback? onPressed,
  bool isOutlined = false,
  bool isLoading = false,
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
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isOutlined ? color : Colors.white
                    ),
                  ),
                )
              else
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

// Método para cargar los datos de la transferencia
void _loadTransactionData() {
  final transaction = widget.transaction!;
  
  // Cargar valores básicos
  _amountCtrl.text = transaction.amount;
  _detailCtrl.text = transaction.detail;
  _selectedDate = transaction.datetime;
  
  // Para transferencias, la categoría contiene "Cuenta origen > Cuenta destino"
  final accountsParts = transaction.explain.split(' > ');
  if (accountsParts.length == 2) {
    final sourceAccountName = accountsParts[0].trim();
    final destAccountName = accountsParts[1].trim();
    
    // Cargar las cuentas primero
    _loadAccountsFromPrefs().then((_) {
      if (_accountItems.isNotEmpty) {
        try {
          setState(() {
            _selectedSourceAccount = _accountItems.firstWhere(
              (account) => account.title.trim() == sourceAccountName,
            );
            
            _selectedDestinationAccount = _accountItems.firstWhere(
              (account) => account.title.trim() == destAccountName,
            );
          });
        } catch (e) {
          // Fallback en caso de error
          setState(() {
            _selectedSourceAccount = _accountItems.first;
            _selectedDestinationAccount = _accountItems.length > 1 
                ? _accountItems[1] 
                : _accountItems.first;
          });
          print('Error al cargar cuentas: $e');
        }
      }
    });
  }
}

// Método para revertir el efecto de una transferencia anterior
Future<void> _revertPreviousTransfer(Add_data transaction) async {
  try {
    final amount = double.parse(transaction.amount);
    final accountsParts = transaction.explain.split(' > ');
    
    if (accountsParts.length == 2) {
      final sourceAccountName = accountsParts[0].trim();
      final destAccountName = accountsParts[1].trim();
      
      // Encontrar las cuentas en la lista actual
      AccountItem? sourceAccount;
      AccountItem? destAccount;
      
      for (var account in _accountItems) {
        if (account.title.trim() == sourceAccountName) {
          sourceAccount = account;
        }
        if (account.title.trim() == destAccountName) {
          destAccount = account;
        }
      }
      
      // Revertir la transferencia: añadir al origen, quitar del destino
      if (sourceAccount != null) {
        sourceAccount.balance += amount;
      }
      
      if (destAccount != null) {
        destAccount.balance -= amount;
      }
      
      // No guardar aquí, se guardará después de la nueva transferencia
    }
  } catch (e) {
    print('Error al revertir transferencia: $e');
    throw Exception('No se pudo revertir la transferencia anterior');
  }
}

// Añadir dentro de la clase _TransferScreenState

// Método para mostrar el diálogo de confirmación de eliminación
void _showDeleteConfirmation() {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        backgroundColor: const Color(0xFF2A2A3A),
        title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
        content: const Text('¿Estás seguro que deseas eliminar esta transferencia?', style: TextStyle(color: Colors.white)),
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

// Método para revertir una transferencia previa
Future<void> _revertPreviousTransaction(Add_data transaction) async {
  try {
    final amount = double.parse(transaction.amount);

    // Especial para transferencias: necesitamos revertir tanto origen como destino
    await TransactionService.processTransaction(
      type: 'Transfer',
      amount: amount,
      accountName: transaction.name, // Cuenta origen
      destinationAccount: transaction.detail, // Cuenta destino (en detail)
      isNewTransaction: false,
      oldTransaction: transaction
    );
  } catch (e) {
    print('Error al revertir transferencia previa: $e');
    throw e;
  }
}
}