import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'dart:convert';
import 'package:hive/hive.dart'; // Importar Hive
import 'package:finazaap/data/model/add_date.dart'; // Importar modelo Add_data
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/core/utils/app_logger.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

import 'package:finazaap/data/models/account_item.dart';
export 'package:finazaap/data/models/account_item.dart';

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
    this.initialAmount,
    this.initialDestinationAccount,
    this.initialDescription,
  }) : super(key: key);

  final double? initialAmount;
  final String? initialDestinationAccount;
  final String? initialDescription;
  
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
  @override
  void initState() {
    super.initState();
    _loadAccountsFromPrefs();
    
    // Cargar datos si estamos en modo edición
    if (widget.isEditing && widget.transaction != null) {
      _loadTransactionData();
    } else {
      // Si no es edición, verificar si hay datos iniciales
      if (widget.initialAmount != null) {
        _amountCtrl.text = CurrencyHelper.format(widget.initialAmount!, showSymbol: false);
      }
      if (widget.initialDescription != null) {
        _detailCtrl.text = widget.initialDescription!;
      }
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _detailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');
    if (accountsData != null) {
      setState(() {
        _accountItems = accountsData
            .map((item) => AccountItem.fromJson(json.decode(item)))
            .toList();
            
        // Pre-seleccionar cuenta destino si se provee
        if (!widget.isEditing && widget.initialDestinationAccount != null) {
           try {
             _selectedDestinationAccount = _accountItems.firstWhere(
               (a) => a.title.trim() == widget.initialDestinationAccount!.trim()
             );
           } catch (e) {
           } catch (e) {
             AppLogger.warning('No se encontró la cuenta destino inicial: ${widget.initialDestinationAccount}', error: e);
           }
        }
      });
    }
  }

  // Reemplazar el método _saveTransfer con esta versión mejorada

Future<bool> _saveTransfer() async {
  final cleanAmountText = CurrencyHelper.cleanAmountString(_amountCtrl.text);
  if (cleanAmountText.isEmpty) {
    AlertHelper.warning(context, 'Por favor ingresa un monto');
    return false;
  }

  final amountParsed = double.tryParse(cleanAmountText);
  if (amountParsed == null || amountParsed <= 0) {
    AlertHelper.warning(context, 'El monto debe ser mayor a 0');
    return false;
  }

  if (_selectedSourceAccount == null || _selectedDestinationAccount == null) {
    AlertHelper.warning(context, 'Por favor selecciona cuentas');
    return false;
  }

  // Verificar que no sean la misma cuenta
  if (_selectedSourceAccount!.title == _selectedDestinationAccount!.title) {
    AlertHelper.warning(context, 'No puedes transferir a la misma cuenta');
    return false;
  }

  try {
    setState(() {
      _isProcessing = true;
    });

    final amount = amountParsed;
    
    // Crear objeto de transferencia
    final Add_data transferTransaction = Add_data(
      'Transfer',
      cleanAmountText,
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
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
    }

    return true;
  } catch (e) {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      AlertHelper.error(context, 'Error: ${e.toString()}');
    }
    
    AppLogger.error('Error al guardar la transferencia', error: e);
    return false;
  }
}

  // Reemplazar el código con error (alrededor de la línea 286)
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
    
    // Manejo especial para edición de transacciones con cuentas eliminadas
    if (widget.isEditing && widget.transaction != null) {
      // Para transferencias, el formato de explain es "Cuenta origen > Cuenta destino"
      final parts = (widget.transaction!.explain ?? '').split(' > ');
      if (parts.length == 2) {
        final sourceAccountName = parts[0].trim();
        final destAccountName = parts[1].trim();
        
        try {
          // Intentar encontrar la cuenta de origen
          AccountItem? sourceAccount = _accountItems.firstWhere(
            (account) => account.title.trim() == sourceAccountName,
          );
          
          // Intentar encontrar la cuenta de destino
          AccountItem? destAccount = _accountItems.firstWhere(
            (account) => account.title.trim() == destAccountName,
          );
          
          setState(() {
            _selectedSourceAccount = sourceAccount;
            _selectedDestinationAccount = destAccount;
          });
        } catch (e) {
          // Si no se encuentra alguna cuenta, fue eliminada
          AppLogger.warning('Cuenta eliminada detectada en transferencia', error: e);
          
          // Será manejado por el diálogo de advertencia en Home
        }
      }
    }
  }
}

  @override
Widget build(BuildContext context) {
  // Colores y constantes de diseño
  const Color primaryColor = Color(0xFF3D7AF0); // Azul para transferencias
  final Color surfaceColor = context.appTheme.secondaryCardBackground;
  final Color cardColor = context.appTheme.darkBackground;
  const double cornerRadius = 20.0;
  
  return Scaffold(
    backgroundColor: context.appTheme.primaryBackground,
    appBar: MoneoHeaderBar.form(
      title: widget.isEditing ? 'Editar Transferencia' : 'Nueva Transferencia',
    ).asPreferredSize(context),
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
                  color: context.appTheme.borderSubtle,
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
                                  color: context.appTheme.textSecondary,
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
                          context: context,
                          child: TextField(
                            controller: _amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(
                              color: context.appTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            inputFormatters: [
                              ThousandsSeparatorInputFormatter(),
                            ],
                            decoration: InputDecoration(
                              hintText: '0.00',
                              hintStyle: TextStyle(
                                color: context.appTheme.textHint,
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
                          context: context,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AccountItem>(
                              value: _selectedSourceAccount,
                              hint: Text(
                                'Seleccionar origen',
                                style: TextStyle(
                                  color: context.appTheme.textHint,
                                  fontSize: 14,
                                ),
                              ),
                              dropdownColor: context.appTheme.cardBackground,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: context.appTheme.textSecondary,
                              ),
                              isExpanded: true,
                              style: TextStyle(color: context.appTheme.textPrimary),
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
                                  'Saldo disponible: ${CurrencyHelper.format(_selectedSourceAccount!.balanceAsDouble)}',
                                  style: TextStyle(
                                    color: context.appTheme.textSecondary,
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
                          context: context,
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<AccountItem>(
                              value: _selectedDestinationAccount,
                              hint: Text(
                                'Seleccionar destino',
                                style: TextStyle(
                                  color: context.appTheme.textHint,
                                  fontSize: 14,
                                ),
                              ),
                              dropdownColor: context.appTheme.cardBackground,
                              icon: Icon(
                                Icons.arrow_drop_down_rounded,
                                color: context.appTheme.textSecondary,
                              ),
                              isExpanded: true,
                              style: TextStyle(color: context.appTheme.textPrimary),
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
                                    context: context,
                                    child: TextField(
                                      controller: _detailCtrl,
                                      style: TextStyle(
                                        color: context.appTheme.textPrimary,
                                        fontSize: 14,
                                      ),
                                      decoration: InputDecoration(
                                        hintText: 'Detalle (opcional)',
                                        hintStyle: TextStyle(
                                          color: context.appTheme.textHint,
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
                                      context: context,
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
                                              child: FittedBox(
                                                fit: BoxFit.scaleDown,
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  _formatDate(_selectedDate),
                                                  maxLines: 1,
                                                  style: TextStyle(
                                                    color: context.appTheme.textPrimary,
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
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
                                color: context.appTheme.textSecondary,
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
                                    // Guardar la transferencia
                                    final bool saved = await _saveTransfer();
                                    
                                    // Volver a la pantalla principal solo si se guardó
                                    if (saved && mounted) {
                                      Navigator.of(context).popUntil((route) => route.isFirst);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() {
                                        _isProcessing = false;
                                      });
                                    }
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
Widget _buildInputLabel(String label, [BuildContext? context]) {
  return Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 6),
    child: Text(
      label,
      style: TextStyle(
        color: context?.appTheme.textSecondary ?? const Color(0xFF94A3B8),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

// Método helper para campos de entrada más compactos
Widget _buildInputField({required Widget child, required BuildContext context}) {
  return Container(
    decoration: BoxDecoration(
      color: context.appTheme.darkBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: context.appTheme.borderSubtle,
        width: 1,
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    child: Theme(
      data: Theme.of(context).copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
        ),
      ),
      child: child,
    ),
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
              ? Border.all(color: color.withOpacity(0.5), width: 1)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
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
    ),
  );
}

// Método para cargar los datos de la transferencia
void _loadTransactionData() {
  final transaction = widget.transaction!;
  
  // Cargar valores básicos
  _amountCtrl.text = CurrencyHelper.formatString(transaction.safeAmount, showSymbol: false);
  _detailCtrl.text = transaction.safeDetail;
  _selectedDate = transaction.safeDate;
  
  // Para transferencias, la categoría contiene "Cuenta origen > Cuenta destino"
  final accountsParts = transaction.safeCategory.split(' > ');
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
          AppLogger.error('Error al cargar cuentas', error: e);
        }
      }
    });
  }
}
}