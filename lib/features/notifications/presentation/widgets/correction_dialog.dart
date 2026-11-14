import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/themes/app_theme_data.dart';

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
    final theme = Theme.of(context).extension<AppTheme>() ??
        AppTheme.forMode(ThemeNotifier.activeMode);
    final merchantTitle = widget.item.comercio ??
        (widget.item.merchantKey ?? 'Transacción sin comercio');
    final headerColor = _classification == 'ingreso'
        ? theme.income
        : _classification == 'transferencia-propia'
            ? theme.accent
            : theme.expense;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: SingleChildScrollView(
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: theme.secondaryCardBackground,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
              border: Border.all(
                color: theme.borderSubtle,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabecera estilizada estilo Moneo
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            headerColor.withValues(alpha: 0.22),
                            headerColor.withValues(alpha: 0.04),
                          ],
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: theme.borderSubtle,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: headerColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: headerColor.withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              _classification == 'ingreso'
                                  ? Icons.arrow_downward_rounded
                                  : _classification == 'transferencia-propia'
                                      ? Icons.swap_horiz_rounded
                                      : Icons.edit_note_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Corregir Transacción',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  merchantTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.accent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tipo de movimiento',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildTypeChip(
                                theme,
                                'gasto',
                                'Gasto',
                                Icons.arrow_upward_rounded,
                              ),
                              _buildTypeChip(
                                theme,
                                'ingreso',
                                'Ingreso',
                                Icons.arrow_downward_rounded,
                              ),
                              _buildTypeChip(
                                theme,
                                'transferencia-propia',
                                'Transferencia',
                                Icons.swap_horiz_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _inputDecoration(
                                theme, 'Monto (${widget.item.moneda})'),
                            validator: (val) {
                              final n = double.tryParse(val?.trim() ?? '');
                              if (n == null || n <= 0) {
                                return 'Ingresa un monto válido mayor a 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _categoryController,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _inputDecoration(theme, 'Categoría'),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'La categoría no puede estar vacía';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          _buildCategoryShortcuts(theme),
                          const SizedBox(height: 12),

                          TextFormField(
                            controller: _accountController,
                            style: TextStyle(color: theme.textPrimary),
                            decoration:
                                _inputDecoration(theme, 'Cuenta origen'),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Ingresa la cuenta de origen';
                              }
                              return null;
                            },
                          ),

                          if (_classification == 'transferencia-propia') ...[
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _destinationAccountController,
                              style: TextStyle(color: theme.textPrimary),
                              decoration:
                                  _inputDecoration(theme, 'Cuenta destino'),
                              validator: (val) {
                                if (_classification == 'transferencia-propia' &&
                                    (val == null || val.trim().isEmpty)) {
                                  return 'Ingresa la cuenta de destino para la transferencia';
                                }
                                return null;
                              },
                            ),
                          ],

                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(null),
                                  child: Text(
                                    'Cancelar',
                                    style:
                                        TextStyle(color: theme.textSecondary),
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: theme.buttonShadow,
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _submit,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.buttonBackground,
                                      foregroundColor: theme.buttonForeground,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Guardar corrección',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
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
          ),
        ),
      ),
    );
  }

  Widget _buildTypeChip(
    AppTheme theme,
    String value,
    String label,
    IconData icon,
  ) {
    final isSelected = _classification == value;

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 14,
        color: isSelected ? theme.buttonForeground : theme.textSecondary,
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
      selectedColor: theme.buttonBackground,
      backgroundColor: theme.darkBackground,
      labelStyle: TextStyle(
        color: isSelected ? theme.buttonForeground : theme.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      side: BorderSide(
        color: isSelected ? theme.buttonBackground : theme.borderSubtle,
      ),
    );
  }

  Widget _buildCategoryShortcuts(AppTheme theme) {
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
                fontSize: 11,
                color: theme.textSecondary,
              ),
              backgroundColor: theme.darkBackground,
              side: BorderSide(color: theme.borderSubtle),
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

  InputDecoration _inputDecoration(AppTheme theme, String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: theme.textSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: theme.darkBackground,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.borderSubtle),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.accent, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.error, width: 1.5),
      ),
    );
  }
}
