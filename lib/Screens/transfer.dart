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
  return Scaffold(
    backgroundColor: const Color(0xFF1F2639),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Center(
          child: Container(
            width: 340,
            margin: const EdgeInsets.only(top: 50, bottom: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A3A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildForm(),
          ),
        ),
      ),
    ),
  );
}

Widget _buildForm() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      // Título centrado con tamaño consistente
      Center(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Text(
            'Transferencia',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),

      // Monto - sin etiqueta de texto
      _buildListRow(
        icon: Icons.attach_money,
        trailing: TextField(
          controller: _amountCtrl,
          decoration: const InputDecoration(
            hintText: 'Monto',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 15),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
          ],
        ),
      ),

      // Cuenta origen - sin etiqueta de texto
      _buildListRow(
        icon: Icons.account_balance_wallet,
        trailing: _buildAccountsDropdown(
          hintText: 'Cuenta de origen',
          selectedAccount: _selectedSourceAccount,
          onChanged: (value) {
            setState(() {
              _selectedSourceAccount = value;
            });
          },
        ),
      ),

      // Saldo disponible con alineación y estilo consistente
      if (_selectedSourceAccount != null)
        Padding(
          padding: const EdgeInsets.only(left: 34, top: 4, bottom: 8),
          child: Text(
            'Saldo: ${currencyFormat.format(_selectedSourceAccount!.balance)} \$',
            style: TextStyle(
              color: Colors.blueAccent.withOpacity(0.7), 
              fontSize: 13,
            ),
          ),
        ),

      // Cuenta destino - sin etiqueta de texto
      _buildListRow(
        icon: Icons.arrow_forward,
        trailing: _buildAccountsDropdown(
          hintText: 'Cuenta de destino',
          selectedAccount: _selectedDestinationAccount,
          onChanged: (value) {
            setState(() {
              _selectedDestinationAccount = value;
            });
          },
        ),
      ),

      // Detalle - sin etiqueta de texto
      _buildListRow(
        icon: Icons.note_alt,
        trailing: TextField(
          controller: _detailCtrl,
          decoration: const InputDecoration(
            hintText: 'Detalle (opcional)',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),

      // Fecha - sin etiqueta de texto
      _buildListRow(
        icon: Icons.calendar_today,
        trailing: InkWell(
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
                      primary: Colors.blueAccent,
                      onPrimary: Colors.white,
                      surface: const Color(0xFF2A2A3A),
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
          child: Text(
            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            style: const TextStyle(color: Colors.white, fontSize: 15),
          ),
        ),
      ),

      // Espaciado adicional consistente
      const SizedBox(height: 32),

      // Botones de acción con alineación y estilo coherentes
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Contenedor para botones de la izquierda (Cancelar y Eliminar)
          Row(
            children: [
              // Botón Cancelar
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.grey),
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
          
          // Botón Transferir (a la derecha)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigoAccent,
            ),
            onPressed: _isProcessing ? null : _saveTransfer,
            child: _isProcessing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : Text(widget.isEditing ? 'Actualizar' : 'Transferir'),
          ),
        ],
      ),
    ],
  );
}

Widget _buildListRow({
  required IconData icon,
  required Widget trailing,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    margin: const EdgeInsets.only(bottom: 4),
    decoration: const BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.grey, width: 0.2),
      ),
    ),
    child: Row(
      children: [
        // Icono siempre azul
        Icon(icon, color: Colors.blueAccent, size: 20),
        const SizedBox(width: 14),
        // Cambio de alineación a izquierda
        Expanded(child: trailing),
      ],
    ),
  );
}

// Dropdown rediseñado para mantener el icono original de la cuenta cuando se selecciona
Widget _buildAccountsDropdown({
  required String hintText,
  required AccountItem? selectedAccount,
  required ValueChanged<AccountItem?> onChanged,
}) {
  return DropdownButton<AccountItem>(
    value: selectedAccount,
    hint: Text(hintText, style: TextStyle(color: Colors.grey, fontSize: 15)),
    dropdownColor: const Color(0xFF2A2A3A),
    iconEnabledColor: Colors.blueAccent,
    underline: Container(),
    style: const TextStyle(color: Colors.white, fontSize: 15),
    onChanged: onChanged,
    icon: Icon(Icons.keyboard_arrow_down, color: Colors.blueAccent, size: 20),
    items: _accountItems.map((account) {
      return DropdownMenuItem<AccountItem>(
        value: account,
        // Eliminar icono, solo mostrar el nombre de la cuenta
        child: Text(account.title, style: TextStyle(fontSize: 15)),
      );
    }).toList(),
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