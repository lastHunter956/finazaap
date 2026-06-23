import 'package:flutter/material.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/utlity.dart';
import 'dart:convert';
import 'package:finazaap/data/account_utils.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:flutter/services.dart'; // Para FilteringTextInputFormatter
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/utils/currency_helper.dart';

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
        iconData = AppIcons.getIcon(json['icon']);
      } else if (json['icon'] is String) {
        // En caso que el icono venga como string (código en hexadecimal)
        iconData = AppIcons.getIcon(
            int.tryParse(json['icon']) ??
                Icons.account_balance_wallet.codePoint);
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
  final TextEditingController _installmentsCtrl = TextEditingController(); // Cuotas
  bool _isInterestFree = false; // Sin intereses

  // ========= LISTAS DE DATOS =========
  List<AccountItem> _accountItems = []; // Para “Cuenta”
  // Change to store full category objects
  List<Map<String, dynamic>> _categories = []; 

  // ========= SELECCIONES DEL USUARIO =========
  AccountItem? _selectedAccount;
  String? _selectedCategory; // Still store the name of the selected category
  DateTime _selectedDate = DateTime.now();

  // (Opcional) Para “Ingreso” / “Egreso”
  // Si solo usarás “Egreso” en esta vista, puedes dejarlo fijo.
  bool _isIncome = false; // true => Ingreso, false => Egreso

  // ========= OBLIGACIONES / RESPONSABILIDADES =========
  bool _isObligationPayment = false;
  Responsibility? _selectedResponsibility;
  bool _isMinimumPayment = true; // True: Pago Sugerido, False: Pago Personalizado
  bool _markAsPaidComplete = true; // Switch para marcar la obligación como totalmente pagada
  List<Responsibility> _responsibilities = [];

  @override
  void initState() {
    super.initState();
    _loadAccountsFromPrefs();
    _loadCategoriesFromPrefs();
    _loadResponsibilities();
    
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
  try {
    // Obtener solo cuentas activas
    final activeAccountsData = await AccountService.getActiveAccounts();
    final deletedAccountNames = await AccountService.getDeletedAccountNames();
    
      if (mounted) {
        setState(() {
          _accountItems = activeAccountsData.map((jsonData) => 
            AccountItem.fromJson(jsonData)
          ).toList();
          
          if (!widget.isEditing) {
             // ... (Logic for default account selection)
             if (_accountItems.isNotEmpty) {
               _selectedAccount = _accountItems.first;
             }
          } else {
             // ... (existing editing logic will handle selection in _loadTransactionData or here if needed)
          }
        });
      }
      
      // Handle loaded selection logic if strictly needed here or keep existing structure
      // For brevity in this replacement, relying on existing logic flow or _loadTransactionData
  } catch (e) {
    debugPrint('❌ Error al cargar cuentas: $e');
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

  Future<void> _loadCategoriesFromPrefs() async {
    try {
      // Usar getCategoriesWithMetadata para obtener iconos y colores
      final String type = 'Expenses'; 
      List<Map<String, dynamic>> activeCategories = await CategoryService.getCategoriesWithMetadata(type);
      List<String> deletedCategories = await CategoryService.getDeletedCategories(type);
      
      // Filtrar categorías eliminadas
      List<Map<String, dynamic>> filteredCategories = activeCategories.where((cat) {
        return !deletedCategories.contains(cat['text']);
      }).toList();

      // Ordenar alfabéticamente
      filteredCategories.sort((a, b) => (a['text'] as String).compareTo(b['text'] as String));

      if (mounted) {
        setState(() {
          _categories = filteredCategories;

          // Validar categoría seleccionada en modo edición
          if (widget.isEditing && widget.transaction != null) {
            final transactionCategory = widget.transaction!.explain;
            // Verificar si existe en la lista cargada
            bool exists = _categories.any((cat) => cat['text'] == transactionCategory);
            
            if (exists) {
              _selectedCategory = transactionCategory;
            } else {
               _selectedCategory = null; 
            }
          }

          // Auto-seleccionar si ya está activo el pago de obligación
          if (_isObligationPayment) {
            _autoSelectCategoryForObligation();
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Error al cargar categorías: $e');
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
      _loadResponsibilities(); // Recargar responsabilidades para el mes seleccionado
    }
  }

  Future<void> _loadResponsibilities() async {
    try {
      await ResponsibilityService.init();
      final all = ResponsibilityService.getAllResponsibilities();
      
      final currentMonth = _selectedDate.month;
      final currentYear = _selectedDate.year;
      
      setState(() {
        _responsibilities = all.where((r) {
          if (widget.isEditing && widget.transaction != null && widget.transaction!.responsibilityId == r.safeId) {
            return true;
          }
          return !r.isPaidInMonth(currentMonth, currentYear);
        }).toList();
        
        // Si estamos en modo edición y tiene una obligación vinculada, pre-seleccionarla
        if (widget.isEditing && widget.transaction != null && widget.transaction!.isObligationPayment == true) {
          _isObligationPayment = true;
          final String? respId = widget.transaction!.responsibilityId;
          if (respId != null) {
            final matches = _responsibilities.where((r) => r.safeId == respId);
            if (matches.isNotEmpty) {
              _selectedResponsibility = matches.first;
            }
          }
          _isMinimumPayment = false;
          _markAsPaidComplete = false;
          _autoSelectCategoryForObligation();
        }
      });
    } catch (e) {
      debugPrint('Error cargando responsabilidades: $e');
    }
  }

  String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  void _autoSelectCategoryForObligation() {
    debugPrint('*** [_autoSelectCategoryForObligation] Iniciando auto-selección');
    if (_selectedResponsibility != null) {
      final responsibilityCategory = _selectedResponsibility!.safeCategory;
      debugPrint('Obligación seleccionada: ${_selectedResponsibility!.safeName}');
      debugPrint('Categoría de la obligación: $responsibilityCategory');
      debugPrint('Categorías de egresos disponibles en dropdown: ${_categories.map((c) => c['text']).toList()}');
      
      bool found = false;
      
      // 1. Intento de coincidencia exacta directa
      for (var cat in _categories) {
        if (cat['text'] == responsibilityCategory) {
          _selectedCategory = cat['text'] as String;
          found = true;
          debugPrint('Coincidencia exacta encontrada: $_selectedCategory');
          break;
        }
      }
      
      // 2. Fallback a coincidencia normalizada/parcial
      if (!found) {
        final matchedCategory = _findMatchingCategory(responsibilityCategory);
        if (matchedCategory != null) {
          _selectedCategory = matchedCategory;
          debugPrint('Coincidencia por sinónimos/normalizada encontrada: $_selectedCategory');
        } else {
          _selectedCategory = null;
          debugPrint('No se encontró ninguna coincidencia para la categoría "$responsibilityCategory"');
        }
      }
    } else {
      _selectedCategory = null;
      debugPrint('No hay obligación seleccionada');
    }
  }

  String? _findMatchingCategory(String responsibilityCategory) {
    const Map<String, List<String>> obligationCategoryMapping = {
      'servicio': ['servicios', 'servicio', 'servicios publicos', 'luz', 'agua', 'gas', 'internet'],
      'membresía': ['suscripciones', 'membresias', 'membresia', 'suscripcion', 'netflix', 'spotify'],
      'membresia': ['suscripciones', 'membresias', 'membresia', 'suscripcion', 'netflix', 'spotify'],
      'tarjeta': ['tarjetas', 'tarjeta', 'tarjetas de credito', 'tarjeta de credito', 'banco'],
      'préstamo': ['prestamos', 'prestamo', 'credito', 'deudas', 'deuda'],
      'prestamo': ['prestamos', 'prestamo', 'credito', 'deudas', 'deuda'],
      'vivienda': ['vivienda', 'hogar', 'alquiler', 'arriendo', 'arriendos'],
      'seguros': ['seguros', 'seguro'],
      'educación': ['educacion', 'colegio', 'universidad', 'estudio', 'estudios'],
      'educacion': ['educacion', 'colegio', 'universidad', 'estudio', 'estudios'],
      'transporte': ['transporte', 'gasolina', 'carro', 'moto', 'viajes', 'viaje'],
      'ahorro': ['ahorros', 'ahorro', 'inversion', 'inversiones'],
      'legal': ['legal', 'otros', 'impuestos', 'tasas'],
      'salud': ['salud', 'medicina', 'farmacia', 'doctor', 'clinica'],
      'impuestos': ['impuestos', 'impuesto', 'tasas', 'legal', 'otros'],
      'mascotas': ['mascotas', 'mascota', 'perro', 'gato', 'veterinaria'],
      'otros': ['otros', 'general'],
    };

    final cleanKey = responsibilityCategory.toLowerCase().trim();
    
    // Bidirectional/Synonym Group Expansion
    List<String> possibleMatches = [cleanKey];
    if (obligationCategoryMapping.containsKey(cleanKey)) {
      possibleMatches.addAll(obligationCategoryMapping[cleanKey]!);
    }
    
    obligationCategoryMapping.forEach((key, synonyms) {
      final normalizedSynonyms = synonyms.map((s) => s.toLowerCase().trim()).toList();
      if (normalizedSynonyms.contains(cleanKey) || key == cleanKey) {
        possibleMatches.add(key);
        possibleMatches.addAll(synonyms);
      }
    });
    
    possibleMatches = possibleMatches.toSet().toList();
    debugPrint('posibles sinónimos expandidos para "$cleanKey": $possibleMatches');
    
    // 1. Coincidencia exacta en orden de preferencia de sinónimos
    for (final possibleMatch in possibleMatches) {
      final target = _normalizeString(possibleMatch);
      for (var cat in _categories) {
        final catText = _normalizeString(cat['text'] as String);
        if (catText == target) {
          debugPrint('Match exacto de sinónimo: "$possibleMatch" con categoría: "${cat['text']}"');
          return cat['text'] as String;
        }
      }
    }
    
    // 2. Coincidencia parcial en orden de preferencia de sinónimos
    for (final possibleMatch in possibleMatches) {
      final target = _normalizeString(possibleMatch);
      for (var cat in _categories) {
        final catText = _normalizeString(cat['text'] as String);
        if (catText.contains(target) || target.contains(catText)) {
          debugPrint('Match parcial de sinónimo: "$possibleMatch" con categoría: "${cat['text']}"');
          return cat['text'] as String;
        }
      }
    }
    
    // 3. Fallback: coincidencia general sobre el string original normalizado
    final target = _normalizeString(responsibilityCategory);
    if (target.isNotEmpty) {
      for (var cat in _categories) {
        final catText = _normalizeString(cat['text'] as String);
        if (catText == target || catText.contains(target) || target.contains(catText)) {
          debugPrint('Match fallback general: "$responsibilityCategory" con categoría: "${cat['text']}"');
          return cat['text'] as String;
        }
      }
    }
    
    return null;
  }

  Widget _buildObligationSection(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isObligationPayment 
              ? primaryColor.withOpacity(0.4) 
              : Colors.white.withOpacity(0.05),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    color: _isObligationPayment ? primaryColor : Colors.white54,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    '¿Vincular a una obligación?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _isObligationPayment,
                activeColor: primaryColor,
                activeTrackColor: primaryColor.withOpacity(0.3),
                inactiveThumbColor: Colors.grey,
                inactiveTrackColor: Colors.white.withOpacity(0.05),
                onChanged: (val) {
                  setState(() {
                    _isObligationPayment = val;
                    if (val) {
                      if (_responsibilities.isNotEmpty) {
                        _selectedResponsibility = _responsibilities.first;
                        _updateAmountFromResponsibility();
                        _autoSelectCategoryForObligation();
                        _detailCtrl.text = 'Pago obligación: ${_selectedResponsibility!.safeName}';
                      }
                    } else {
                      if (_detailCtrl.text.startsWith('Pago obligación:')) {
                        _detailCtrl.clear();
                      }
                      _selectedResponsibility = null;
                      _autoSelectCategoryForObligation(); // Clears and unlocks category
                    }
                  });
                },
              ),
            ],
          ),
          
          if (_isObligationPayment) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white10, height: 1),
            const SizedBox(height: 16),
            Text(
              'Seleccionar Obligación Pendiente',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF131722),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Responsibility>(
                  value: _selectedResponsibility,
                  dropdownColor: const Color(0xFF1A1F2B),
                  isExpanded: true,
                  hint: const Text('Seleccionar obligación', style: TextStyle(color: Colors.white54, fontSize: 14)),
                  icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                  items: _responsibilities.map((r) {
                    final expected = r.getAmountForDate(_selectedDate.month, _selectedDate.year);
                    final paid = r.getPaidAmountInCycle(_selectedDate.month, _selectedDate.year);
                    final remaining = (expected - paid).clamp(0.0, double.infinity);
                    return DropdownMenuItem<Responsibility>(
                      value: r,
                      child: Row(
                        children: [
                          Icon(AppIcons.getIcon(r.safeIconCode), size: 16, color: primaryColor),
                          const SizedBox(width: 8),
                          Text(r.safeName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                          const Spacer(),
                          Text(
                            'Falta: ${CurrencyHelper.formatCompact(remaining)}',
                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (r) {
                    setState(() {
                      _selectedResponsibility = r;
                      _updateAmountFromResponsibility();
                      _autoSelectCategoryForObligation();
                      if (r != null) {
                        _detailCtrl.text = 'Pago obligación: ${r.safeName}';
                      }
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            if (_selectedResponsibility != null) ...[
              Text(
                'Modalidad de Pago',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: Container(
                        alignment: Alignment.center,
                        child: Text(
                          'Sugerido (${CurrencyHelper.formatCompact(_getSuggestedPaymentAmount())})',
                          style: TextStyle(
                            color: _isMinimumPayment ? Colors.white : Colors.white54,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      selected: _isMinimumPayment,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.white.withOpacity(0.03),
                      onSelected: (val) {
                        setState(() {
                          _isMinimumPayment = true;
                          _updateAmountFromResponsibility();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: Container(
                        alignment: Alignment.center,
                        child: const Text(
                          'Personalizado',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      selected: !_isMinimumPayment,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.white.withOpacity(0.03),
                      onSelected: (val) {
                        setState(() {
                          _isMinimumPayment = false;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              CheckboxListTile(
                title: const Text(
                  'Marcar obligación como pagada completa',
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                value: _markAsPaidComplete,
                activeColor: primaryColor,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (val) {
                  setState(() {
                    _markAsPaidComplete = val ?? true;
                  });
                },
              ),
            ],
          ],
        ],
      ),
    );
  }

  double _getSuggestedPaymentAmount() {
    if (_selectedResponsibility == null) return 0.0;
    final double remainingQuota = _selectedResponsibility!.getRemainingQuota(_selectedDate.month, _selectedDate.year);
    return remainingQuota > 0 
        ? remainingQuota 
        : _selectedResponsibility!.getAmountForDate(_selectedDate.month, _selectedDate.year);
  }

  void _updateAmountFromResponsibility() {
    if (_selectedResponsibility != null && _isMinimumPayment) {
      final double amt = _getSuggestedPaymentAmount();
      _amountCtrl.text = CurrencyHelper.format(amt, showSymbol: false);
    }
  }

  // Reemplazar el método _saveTransaction con esta versión mejorada

  Future<void> _saveTransaction() async {
    // Validaciones básicas
    final String? categoryToSave = _isObligationPayment 
        ? _getObligationCategoryDetails()['text'] 
        : _selectedCategory;

    if (_isObligationPayment && _selectedResponsibility == null) {
      AlertHelper.warning(context, 'Por favor selecciona una obligación');
      return;
    }

    final cleanAmountText = CurrencyHelper.cleanAmountString(_amountCtrl.text);
    if (cleanAmountText.isEmpty ||
        _selectedAccount == null ||
        categoryToSave == null) {
      AlertHelper.warning(context, 'Por favor completa todos los campos');
      return;
    }

    try {
      final amount = double.parse(cleanAmountText);

      // Obtener el código del icono para esta categoría específica
      final int categoryIconCode = _isObligationPayment
          ? _getObligationCategoryDetails()['icon'] as int
          : _getCategoryIconCode(categoryToSave);

      // Crear objeto de transacción con el iconCode y datos de tarjeta de crédito
      final Add_data transaction = Add_data(
        'Expenses',
        cleanAmountText,
        _selectedDate,
        _detailCtrl.text,
        categoryToSave,
        _selectedAccount!.title,
        categoryIconCode,
        _installmentsCtrl.text.isEmpty ? '1' : _installmentsCtrl.text,
        _isInterestFree,
        _isObligationPayment ? _selectedResponsibility?.safeId : null,
        _isObligationPayment,
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
          installments: int.tryParse(_installmentsCtrl.text) ?? 1, // Pasamos las cuotas al editar también
          isInterestFree: _isInterestFree, // Pasamos preferencia de interés
        );

        if (success) {
          // Actualizar en Hive solo si la actualización de saldo tuvo éxito
          box.put(widget.transactionKey, transaction);
          print('Categoría guardada con iconCode: $categoryIconCode');

          // REGISTRAR PAGO DE OBLIGACIÓN (tras haber sido revertido por processTransaction)
          if (_isObligationPayment && _selectedResponsibility != null) {
            await ResponsibilityService.registerPayment(
              _selectedResponsibility!.safeId,
              amount,
              _selectedDate,
              _markAsPaidComplete,
            );
          }
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
          installments: int.tryParse(_installmentsCtrl.text) ?? 1, // Pasamos las cuotas al crear
          isInterestFree: _isInterestFree, // Pasamos preferencia de interés
        );

        if (success) {
          // Guardar en Hive solo si la actualización de saldo tuvo éxito
          box.add(transaction);
          print('Nueva categoría guardada con iconCode: $categoryIconCode');

          // REGISTRAR PAGO DE OBLIGACIÓN
          if (_isObligationPayment && _selectedResponsibility != null) {
            await ResponsibilityService.registerPayment(
              _selectedResponsibility!.safeId,
              amount,
              _selectedDate,
              _markAsPaidComplete,
            );
          }
        } else {
          throw Exception('Error al actualizar el saldo de la cuenta');
        }
      }

      // Notificar a ResponsibilityService si es una compra con tarjeta (SOLO PARA MODO CREACIÓN O EDICIÓN QUE AFECTE)
      // La lógica interna de processDebtIncrease se encarga de verificar si es tarjeta
      if (_selectedAccount != null) {
         await ResponsibilityService.processDebtIncrease(
            _selectedAccount!.title,
            amount,
            int.tryParse(_installmentsCtrl.text) ?? 1,
            _isInterestFree,
            _selectedDate
         );
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
      AlertHelper.error(context, 'Error: $e');
    }
  }

// Reemplazar la llamada a updateAccountBalanceOnTransaction por la API correcta
  Future<void> _revertPreviousTransaction(Add_data transaction) async {
    try {
      final amount = double.parse(transaction.safeAmount);

      // Usar el método existente en TransactionService en lugar del que falta
      await TransactionService.processTransaction(
          type: transaction.safeType,
          amount: amount,
          accountName: transaction.safeAccount,
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
    _amountCtrl.text = CurrencyHelper.formatString(transaction.safeAmount, showSymbol: false);
    _detailCtrl.text = transaction.safeDetail;
    _selectedDate = transaction.safeDate;
    _selectedCategory = transaction.safeCategory; // Categoría
    
    // Cargar datos de tarjeta de crédito si existen
    if (transaction.installments != null) {
      _installmentsCtrl.text = transaction.installments!;
    }
    if (transaction.isInterestFree != null) {
      _isInterestFree = transaction.isInterestFree!;
    }
    if (transaction.isObligationPayment == true) {
      _isObligationPayment = true;
    }

    // Cargar las cuentas primero y luego buscar la correcta
    _loadAccountsFromPrefs().then((_) {
      // Buscar la cuenta por nombre exacto
      try {
        final accountToSelect = _accountItems.firstWhere(
          (account) => account.title.trim() == transaction.safeAccount.trim(),
        );
        setState(() {
          _selectedAccount = accountToSelect;
        });
      } catch (e) {
        // Si no encuentra la cuenta exacta, mostrar un mensaje de error
        print('Error: No se encontró la cuenta ${transaction.safeAccount}: $e');
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
    // Buscar la categoría en la lista _categories
    try {
      final categoryMap = _categories.firstWhere(
        (cat) => cat['text'] == categoryName,
        orElse: () => {'icon': Icons.category.codePoint}, 
      );
      return categoryMap['icon'] as int;
    } catch (_) {
      return Icons.category.codePoint;
    }
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
          title: const Text('Confirmar eliminación',
              style: TextStyle(color: Colors.white)),
          content: const Text(
              '¿Estás seguro que deseas eliminar esta transacción?',
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
                  AlertHelper.error(context, 'Error al eliminar: ${e.toString()}');
                }
              },
              child: const Text('Eliminar',
                  style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Colores y constantes de diseño
    const Color primaryColor = Colors.redAccent; // Rojo para gastos
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
                          Opacity(
                            opacity: (_isObligationPayment && _isMinimumPayment) ? 0.6 : 1.0,
                            child: _buildInputField(
                              child: TextField(
                                controller: _amountCtrl,
                                enabled: !(_isObligationPayment && _isMinimumPayment),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                 inputFormatters: [
                                   ThousandsSeparatorInputFormatter(),
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
                                            // Extraer ícono y color
                                            final IconData iconData = account
                                                    .icon ??
                                                Icons.account_balance_wallet;
                                            final Color iconColor =
                                                account.iconColor ??
                                                    Colors.blue;

                                            return DropdownMenuItem<
                                                AccountItem>(
                                              value: account,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: iconColor
                                                          .withOpacity(0.2),
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
                                    _isObligationPayment
                                        ? _buildReadOnlyCategoryWidget()
                                        : _buildCategoryDropdown(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          _buildObligationSection(primaryColor),
                          const SizedBox(height: 14),

                          // Lógica para tarjetas de crédito
                          if (_selectedAccount != null && _selectedAccount!.subtitle == 'Tarjeta de Crédito' && !_isObligationPayment) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Número de cuotas
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('Cuotas'),
                                      _buildInputField(
                                        child: TextField(
                                          controller: _installmentsCtrl,
                                          keyboardType: TextInputType.number,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          inputFormatters: [
                                            FilteringTextInputFormatter.digitsOnly,
                                          ],
                                          decoration: InputDecoration(
                                            hintText: '1',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withOpacity(0.3),
                                            ),
                                            border: InputBorder.none,
                                            prefixIcon: const Icon(
                                              Icons.layers_rounded,
                                              color: primaryColor,
                                              size: 18,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(vertical: 14),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 12),

                                // Sin intereses (Toggle)
                                Expanded(
                                  flex: 1,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('¿Sin intereses?'),
                                      Container(
                                        height: 50, // Altura similar al input
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1F2B),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: _isInterestFree
                                                ? Colors.greenAccent.withOpacity(0.5)
                                                : Colors.white.withOpacity(0.08),
                                            width: 1,
                                          ),
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                _isInterestFree = !_isInterestFree;
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 12),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    _isInterestFree
                                                        ? Icons.check_circle_rounded
                                                        : Icons.circle_outlined,
                                                    color: _isInterestFree
                                                        ? Colors.greenAccent
                                                        : Colors.grey,
                                                    size: 20,
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Text(
                                                    _isInterestFree ? 'Sí' : 'No',
                                                    style: TextStyle(
                                                      color: _isInterestFree
                                                          ? Colors.greenAccent
                                                          : Colors.white70,
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                          ],

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
                                  onPressed: () async {
                                    try {
                                      // Mostrar indicador de carga
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return const Center(
                                              child:
                                                  CircularProgressIndicator());
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
                                        Navigator.of(context)
                                            .popUntil((route) => route.isFirst);
                                      }
                                    } catch (e) {
                                      // Cerrar el indicador de carga en caso de error
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }

                                      // Mostrar mensaje de error
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Error: ${e.toString()}'),
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

  Map<String, dynamic> _getObligationCategoryDetails() {
    if (_selectedResponsibility == null) {
      return {
        'text': 'Sin categoría',
        'icon': Icons.category.codePoint,
        'color': Colors.grey.value,
      };
    }

    final responsibilityCategory = _selectedResponsibility!.safeCategory;
    
    // Intento de encontrar la categoría seleccionada (que fue mapeada en _autoSelectCategoryForObligation)
    if (_selectedCategory != null) {
      for (var cat in _categories) {
        if (cat['text'] == _selectedCategory) {
          return cat;
        }
      }
    }

    // Si no hay _selectedCategory, intentar buscar de nuevo usando _findMatchingCategory
    final matchedName = _findMatchingCategory(responsibilityCategory);
    if (matchedName != null) {
      for (var cat in _categories) {
        if (cat['text'] == matchedName) {
          return cat;
        }
      }
    }

    // Fallback si no hay ninguna coincidencia en _categories: usar los datos de la propia obligación o mapeos estáticos
    int iconCode = _selectedResponsibility!.safeIconCode;
    if (iconCode == 0xe3a6 || iconCode == 0) {
      iconCode = _getFallbackIconForCategory(responsibilityCategory);
    }
    
    return {
      'text': _capitalize(responsibilityCategory),
      'icon': iconCode,
      'color': _getFallbackColorForCategory(responsibilityCategory).value,
    };
  }

  String _capitalize(String text) {
    if (text.isEmpty) return '';
    return text[0].toUpperCase() + text.substring(1);
  }

  int _getFallbackIconForCategory(String category) {
    final clean = category.toLowerCase().trim();
    switch (clean) {
      case 'servicio':
      case 'servicios':
        return Icons.build_rounded.codePoint;
      case 'membresía':
      case 'membresia':
        return Icons.card_membership_rounded.codePoint;
      case 'tarjeta':
        return Icons.credit_card_rounded.codePoint;
      case 'préstamo':
      case 'prestamo':
        return Icons.monetization_on_rounded.codePoint;
      case 'vivienda':
        return Icons.home_rounded.codePoint;
      case 'seguros':
        return Icons.security_rounded.codePoint;
      case 'educación':
      case 'educacion':
        return Icons.school_rounded.codePoint;
      case 'transporte':
        return Icons.directions_car_rounded.codePoint;
      case 'ahorro':
        return Icons.savings_rounded.codePoint;
      case 'salud':
        return Icons.medical_services_rounded.codePoint;
      case 'impuestos':
        return Icons.description_rounded.codePoint;
      case 'mascotas':
        return Icons.pets_rounded.codePoint;
      default:
        return Icons.category_rounded.codePoint;
    }
  }

  Color _getFallbackColorForCategory(String category) {
    final clean = category.toLowerCase().trim();
    switch (clean) {
      case 'servicio':
      case 'servicios':
        return Colors.orange;
      case 'membresía':
      case 'membresia':
        return Colors.purple;
      case 'tarjeta':
        return Colors.blue;
      case 'préstamo':
      case 'prestamo':
        return Colors.green;
      case 'vivienda':
        return Colors.brown;
      case 'seguros':
        return Colors.teal;
      case 'educación':
      case 'educacion':
        return Colors.indigo;
      case 'transporte':
        return Colors.amber;
      case 'ahorro':
        return Colors.pink;
      case 'salud':
        return Colors.red;
      case 'impuestos':
        return Colors.blueGrey;
      case 'mascotas':
        return Colors.lightGreen;
      default:
        return Colors.grey;
    }
  }

  Widget _buildReadOnlyCategoryWidget() {
    final catDetails = _getObligationCategoryDetails();
    final String catText = catDetails['text'] as String;
    final IconData catIcon = AppIcons.getIcon(catDetails['icon'] as int);
    final Color catColor = Color(catDetails['color'] as int);

    return _buildInputField(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: catColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                catIcon,
                color: catColor,
                size: 14,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                catText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(
              Icons.lock_rounded,
              color: Colors.white30,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    const Color cardColor = Color(0xFF1A1F2B);
    return _buildInputField(
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
            final catText = category['text'] as String;
            final catIcon = AppIcons.getIcon(category['icon']);
            final catColor = Color(category['color']);

            return DropdownMenuItem<String>(
              value: catText,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: catColor.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      catIcon,
                      color: catColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      catText,
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
}
