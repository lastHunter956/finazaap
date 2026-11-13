import 'package:flutter/material.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/themes/app_colors.dart';

/// Datos estructurados capturados tras la corrección manual del usuario.
class CorrectionData {
  final String classification;
  final String category;
  final String accountName;
  final String? destinationAccount;
  final double amount;

  const CorrectionData({
    required this.classification,
    required this.category,
    required this.accountName,
    this.destinationAccount,
    required this.amount,
  });
}

/// Diálogo modal accesible para corregir tipo, categoría, cuenta y monto
/// de una transacción pendiente.
class CorrectionDialog extends StatefulWidget {
  final PendingTransactionItem item;
  final List<String>? availableAccounts;
  final List<String>? availableCategories;

  const CorrectionDialog({
    super.key,
    required this.item,
    this.availableAccounts,
    this.availableCategories,
  });

  /// Muestra el diálogo modal y retorna los [CorrectionData] seleccionados o null.
  static Future<CorrectionData?> show(
    BuildContext context, {
    required PendingTransactionItem item,
    List<String>? availableAccounts,
    List<String>? availableCategories,
  }) {
    return showDialog<CorrectionData>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CorrectionDialog(
        item: item,
        availableAccounts: availableAccounts,
        availableCategories: availableCategories,
      ),
    );
  }

  @override
  State<CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends State<CorrectionDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _classification;
  late TextEditingController _categoryController;
  late TextEditingController _accountController;
  late TextEditingController _destinationAccountController;
  late TextEditingController _amountController;

  static const _defaultCategories = [
    'Alimentación',
    'Transporte',
    'Servicios',
    'Salud',
    'Educación',
    'Entretenimiento',
    'Compras',
    'Suscripciones',
    'Hogar',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _classification = widget.item.classification == 'sospechosa'
        ? 'gasto'
        : widget.item.classification;

    _categoryController = TextEditingController(
      text: widget.item.category ?? 'Otros',
    );
    _accountController = TextEditingController(
      text: widget.item.accountName ?? '',
    );
    _destinationAccountController = TextEditingController(
      text: widget.item.destinationAccount ?? '',
    );
    _amountController = TextEditingController(
      text: widget.item.monto != null
          ? widget.item.monto!.toStringAsFixed(0)
          : '',
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _accountController.dispose();
    _destinationAccountController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final parsedAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final dest = _classification == 'transferencia-propia'
        ? _destinationAccountController.text.trim()
        : null;

    final result = CorrectionData(
      classification: _classification,
      category: _categoryController.text.trim().isEmpty
          ? 'Otros'
          : _categoryController.text.trim(),
      accountName: _accountController.text.trim(),
      destinationAccount: dest,
      amount: parsedAmount,
    );

    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final merchantTitle = widget.item.comercio ??
        (widget.item.merchantKey ?? 'Transacción sin comercio');

    return AlertDialog(
      backgroundColor: AppColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      title: Text(
        'Corregir Transacción',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                merchantTitle,
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),

              // Selector de tipo (Gasto / Ingreso / Transferencia)
              Text(
                'Tipo de movimiento',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  _buildTypeChip('gasto', 'Gasto', Icons.arrow_upward_rounded),
                  _buildTypeChip('ingreso', 'Ingreso', Icons.arrow_downward_rounded),
                  _buildTypeChip(
                    'transferencia-propia',
                    'Transferencia',
                    Icons.swap_horiz_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Campo de Monto
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Monto (${widget.item.moneda})'),
                validator: (val) {
                  final n = double.tryParse(val?.trim() ?? '');
                  if (n == null || n <= 0) {
                    return 'Ingresa un monto válido mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Campo de Categoría
              TextFormField(
                controller: _categoryController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Categoría'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'La categoría no puede estar vacía';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 6),
              _buildCategoryShortcuts(),
              const SizedBox(height: 12),

              // Campo de Cuenta Origen
              TextFormField(
                controller: _accountController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: _inputDecoration('Cuenta origen'),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Ingresa la cuenta de origen';
                  }
                  return null;
                },
              ),

              // Campo de Cuenta Destino (Solo si es transferencia)
              if (_classification == 'transferencia-propia') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _destinationAccountController,
                  style: TextStyle(color: AppColors.textPrimary),
                  decoration: _inputDecoration('Cuenta destino'),
                  validator: (val) {
                    if (_classification == 'transferencia-propia' &&
                        (val == null || val.trim().isEmpty)) {
                      return 'Ingresa la cuenta de destino para la transferencia';
                    }
                    return null;
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancelar',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.primaryBackground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Guardar corrección',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(String value, String label, IconData icon) {
    final isSelected = _classification == value;
    final color = isSelected ? AppColors.accent : AppColors.textSecondary;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? AppColors.primaryBackground : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _classification = value;
          });
        }
      },
      selectedColor: AppColors.accent,
      backgroundColor: AppColors.darkBackground,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primaryBackground : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? AppColors.accent : AppColors.borderSubtle,
      ),
    );
  }

  Widget _buildCategoryShortcuts() {
    final list = widget.availableCategories ?? _defaultCategories;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.take(6).map((cat) {
          return Padding(
            padding: const EdgeInsets.only(right: 6.0),
            child: ActionChip(
              label: Text(cat),
              labelStyle: TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
              backgroundColor: AppColors.darkBackground,
              side: BorderSide(color: AppColors.borderSubtle),
              onPressed: () {
                setState(() {
                  _categoryController.text = cat;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: AppColors.darkBackground,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
