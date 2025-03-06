import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart'; // Para formatear números
import 'package:hive/hive.dart'; // Importar Hive
import 'package:finazaap/data/model/add_date.dart'; // Importar modelo Add_data

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
  @override
  _TransferScreenState createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _detailCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  AccountItem? _selectedSourceAccount;
  AccountItem? _selectedDestinationAccount;
  List<AccountItem> _accountItems = [];
  bool _isProcessing = false; // Para prevenir múltiples transferencias simultáneas

  // Formateador para los números
  final currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadAccounts();
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

  Future<void> _saveTransfer() async {
    if (_isProcessing) return; // Prevenir múltiples clics
    
    setState(() {
      _isProcessing = true;
    });

    try {
      // Validación de campos vacíos
      if (_amountCtrl.text.isEmpty ||
          _selectedSourceAccount == null ||
          _selectedDestinationAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor completa todos los campos')),
        );
        return;
      }

      // Validar que no se transfiera a la misma cuenta
      if (_selectedSourceAccount!.title == _selectedDestinationAccount!.title) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No puedes transferir a la misma cuenta')),
        );
        return;
      }

      // Convertir y validar el monto
      double amount = double.tryParse(_amountCtrl.text) ?? 0.0;
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El monto debe ser mayor a cero')),
        );
        return;
      }

      // Verificar fondos suficientes
      if (_selectedSourceAccount!.balance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fondos insuficientes en la cuenta origen')),
        );
        return;
      }

      // Buscar las cuentas reales en la lista de cuentas (para actualizar las correctas)
      int sourceIndex = _accountItems.indexWhere((item) => item.title == _selectedSourceAccount!.title);
      int destIndex = _accountItems.indexWhere((item) => item.title == _selectedDestinationAccount!.title);
      
      if (sourceIndex == -1 || destIndex == -1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al identificar las cuentas')),
        );
        return;
      }

      // Realizar la transferencia
      setState(() {
        _accountItems[sourceIndex].balance -= amount;
        _accountItems[destIndex].balance += amount;
      });

      // Guardar las cuentas actualizadas
      await _saveAccountsToPrefs();

      // Obtenemos el detalle para la transacción, usando un texto por defecto si está vacío
      String detail = _detailCtrl.text.isNotEmpty 
          ? _detailCtrl.text 
          : 'Transferencia entre cuentas';

      // Accedemos al box de Hive para guardar en historial
      final box = Hive.box<Add_data>('data');

      // Crear una sola transacción tipo "Transfer"
      final transferTransaction = Add_data(
        'Transfer',  // IMPORTANTE: Debe ser exactamente 'Transfer'
        _amountCtrl.text,
        _selectedDate,
        _detailCtrl.text.isNotEmpty ? _detailCtrl.text : 'Transferencia entre cuentas',
        '${_selectedSourceAccount!.title} > ${_selectedDestinationAccount!.title}',
        '', // Dejamos vacío el campo de cuenta
        Icons.sync_alt.codePoint,
      );

      // Guardar la transacción en Hive
      box.add(transferTransaction);

      // Mostrar mensaje de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transferencia de ${currencyFormat.format(amount)} realizada con éxito'),
          backgroundColor: Colors.green,
        ),
      );

      // Volver a la pantalla anterior después de un breve retraso
      Future.delayed(Duration(seconds: 1), () {
        Navigator.of(context).pop();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _saveAccountsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accountsData = _accountItems
        .map((item) => json.encode(item.toJson()))
        .toList();
    await prefs.setStringList('accounts', accountsData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2639),
      appBar: null,
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

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Título y botón de retroceso
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón para volver
            InkWell(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.arrow_back, color: Colors.blueAccent),
            ),
            // Título centrado
            const Text(
              'Transferencia',
              style: TextStyle(
                color: Colors.blueAccent,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Elemento invisible para equilibrar el layout
            const SizedBox(width: 24),
          ],
        ),
        const SizedBox(height: 20),

        // Cuenta origen
        _buildListRow(
          icon: Icons.account_balance_wallet,
          iconColor: Colors.blueAccent,
          trailing: _buildAccountsDropdown(
            label: 'Cuenta de origen',
            selectedAccount: _selectedSourceAccount,
            onChanged: (value) {
              setState(() {
                _selectedSourceAccount = value;
              });
            },
          ),
        ),
        
        // Saldo disponible de cuenta origen
        if (_selectedSourceAccount != null)
          Padding(
            padding: const EdgeInsets.only(left: 34, bottom: 10),
            child: Text(
              'Saldo disponible: ${currencyFormat.format(_selectedSourceAccount!.balance)} \$',
              style: TextStyle(color: Colors.blueAccent.withOpacity(0.7), fontSize: 12),
            ),
          ),

        // Cuenta destino
        _buildListRow(
          icon: Icons.arrow_forward,
          iconColor: Colors.blueAccent,
          trailing: _buildAccountsDropdown(
            label: 'Cuenta de destino',
            selectedAccount: _selectedDestinationAccount,
            onChanged: (value) {
              setState(() {
                _selectedDestinationAccount = value;
              });
            },
          ),
        ),

        // Monto
        _buildListRow(
          icon: Icons.attach_money,
          iconColor: Colors.blueAccent,
          trailing: TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              hintText: 'Monto',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
          ),
        ),

        // Fecha (similar a add.dart)
        _buildListRow(
          icon: Icons.calendar_today,
          iconColor: Colors.blueAccent,
          trailing: InkWell(
            onTap: () async {
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
            },
            child: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),

        // Detalle
        _buildListRow(
          icon: Icons.note_alt,
          iconColor: Colors.blueAccent,
          trailing: TextField(
            controller: _detailCtrl,
            decoration: const InputDecoration(
              hintText: 'Detalle (opcional)',
              hintStyle: TextStyle(color: Colors.grey),
              border: InputBorder.none,
            ),
            style: const TextStyle(color: Colors.white),
          ),
        ),

        // Espaciado adicional
        const SizedBox(height: 20),

        // Botones de acción como en add.dart
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Botón Cancel/Reset (como en add.dart)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade800,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                _amountCtrl.clear();
                _detailCtrl.clear();
                setState(() {
                  _selectedSourceAccount = null;
                  _selectedDestinationAccount = null;
                });
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
            ),
            
            // Botón Guardar (anteriormente Transferir)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isProcessing ? null : _saveTransfer,
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Guardar',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  // Método para construir filas con icono + contenido (similar a add_expense.dart)
  Widget _buildListRow({
    required IconData icon,
    required Color iconColor,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
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

  // Simplificación del dropdown para que coincida con el estilo de add.dart
  Widget _buildAccountsDropdown({
    required String label,
    required AccountItem? selectedAccount,
    required ValueChanged<AccountItem?> onChanged,
  }) {
    return DropdownButton<AccountItem>(
      value: selectedAccount,
      hint: Text(label, style: TextStyle(color: Colors.grey)),
      dropdownColor: const Color(0xFF2A2A3A),
      iconEnabledColor: Colors.white,
      underline: Container(),
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      items: _accountItems.map((account) {
        return DropdownMenuItem<AccountItem>(
          value: account,
          child: Row(
            children: [
              Icon(account.icon ?? Icons.account_balance, 
                  color: account.iconColor ?? Colors.grey, size: 16),
              const SizedBox(width: 8),
              Text(account.title),
            ],
          ),
        );
      }).toList(),
    );
  }
}