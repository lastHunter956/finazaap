import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/currency_helper.dart';

/// Datos estructurados capturados tras la corrección manual del usuario.
class CorrectionData {
  final String classification;
  final String category;
  final String accountName;
  final String? destinationAccount;
  final double amount;
  final String description;
  final DateTime date;

  CorrectionData({
    required this.classification,
    required this.category,
    required this.accountName,
    this.destinationAccount,
    required this.amount,
    this.description = '',
    DateTime? date,
  }) : date = date ?? DateTime.now();
}

/// Diálogo modal estilizado al estilo Moneo para corregir tipo, monto, cuentas,
/// categoría, descripción y fecha de una transacción pendiente.
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
  late String _selectedCategory;
  late String _selectedAccount;
  String? _selectedDestinationAccount;
  late DateTime _selectedDate;

  late TextEditingController _amountController;
  late TextEditingController _descriptionController;

  List<String> _accounts = [];
  List<String> _expenseCategories = [];
  List<String> _incomeCategories = [];

  static const _defaultExpenseCategories = [
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

  static const _defaultIncomeCategories = [
    'Salario',
    'Freelance',
    'Inversiones',
    'Bonificación',
    'Reembolso',
    'Otros',
  ];

  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = false;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    _classification = widget.item.classification == 'sospechosa'
        ? 'gasto'
        : widget.item.classification;

    _selectedDate = widget.item.fecha;

    final initialAmount = widget.item.monto;
    _amountController = TextEditingController(
      text: (initialAmount != null && initialAmount > 0)
          ? CurrencyHelper.format(initialAmount, showSymbol: false)
          : '',
    );

    _descriptionController = TextEditingController(
      text: widget.item.comercio ?? '',
    );

    _initLists();
    _scrollController.addListener(_checkScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
  }

  void _checkScroll() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    final show = maxScroll > 4 && currentScroll < maxScroll - 20;
    if (show != _showScrollIndicator) {
      setState(() {
        _showScrollIndicator = show;
      });
    }
  }

  void _initLists() {
    final providedAccounts = widget.availableAccounts;
    if (providedAccounts != null && providedAccounts.isNotEmpty) {
      _accounts = List<String>.from(providedAccounts);
    } else if (widget.item.accountName != null &&
        widget.item.accountName!.trim().isNotEmpty) {
      _accounts = [widget.item.accountName!.trim()];
    } else {
      _accounts = ['Cuenta Principal'];
    }

    if (widget.item.accountName != null &&
        widget.item.accountName!.trim().isNotEmpty &&
        !_accounts.contains(widget.item.accountName!.trim())) {
      _accounts.insert(0, widget.item.accountName!.trim());
    }
    _selectedAccount =
        (widget.item.accountName != null &&
                _accounts.contains(widget.item.accountName!.trim()))
            ? widget.item.accountName!.trim()
            : _accounts.first;

    final dest = widget.item.destinationAccount?.trim();
    if (dest != null && dest.isNotEmpty && _accounts.contains(dest)) {
      _selectedDestinationAccount = dest;
    } else {
      final other = _accounts.where((a) => a != _selectedAccount).toList();
      _selectedDestinationAccount = other.isNotEmpty ? other.first : null;
    }

    _expenseCategories = List<String>.from(
      widget.availableCategories ?? _defaultExpenseCategories,
    );
    _incomeCategories = List<String>.from(
      widget.availableCategories ?? _defaultIncomeCategories,
    );

    _syncSelectedCategory();

    // Cargar cuentas y categorías reales del usuario solo si no se inyectaron explícitamente
    if (widget.availableAccounts == null) {
      _loadUserAccounts();
    }
    if (widget.availableCategories == null) {
      _loadUserCategories();
    }
  }

  Future<void> _loadUserAccounts() async {
    try {
      final active = await AccountService.getActiveAccounts();
      if (!mounted || active.isEmpty) return;

      final titles = active
          .map((e) => (e['title'] ?? '').toString().trim())
          .where((t) => t.isNotEmpty)
          .toList();
      if (titles.isEmpty) return;

      setState(() {
        _accounts = titles;
        if (!_accounts.contains(_selectedAccount)) {
          _selectedAccount = _accounts.first;
        }
        if (_selectedDestinationAccount == null ||
            !_accounts.contains(_selectedDestinationAccount) ||
            _selectedDestinationAccount == _selectedAccount) {
          final others =
              _accounts.where((a) => a != _selectedAccount).toList();
          _selectedDestinationAccount =
              others.isNotEmpty ? others.first : null;
        }
      });
    } catch (_) {
      // Mantiene fallback seguro en entornos sin SharedPreferences inicializado
    }
  }

  Future<void> _loadUserCategories() async {
    try {
      final expenses = await CategoryService.getCategories('Expenses');
      final incomes = await CategoryService.getCategories('Income');
      if (!mounted) return;

      setState(() {
        if (expenses.isNotEmpty) _expenseCategories = expenses;
        if (incomes.isNotEmpty) _incomeCategories = incomes;
        _syncSelectedCategory();
      });
    } catch (_) {
      // Mantiene categorías por defecto
    }
  }

  List<String> get _currentCategories =>
      _classification == 'ingreso' ? _incomeCategories : _expenseCategories;

  void _syncSelectedCategory() {
    final list = _currentCategories;
    final itemCat = widget.item.category?.trim();
    if (itemCat != null && itemCat.isNotEmpty && list.contains(itemCat)) {
      _selectedCategory = itemCat;
    } else if (list.contains('Otros')) {
      _selectedCategory = 'Otros';
    } else {
      _selectedCategory = list.first;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final cleanedAmount =
        CurrencyHelper.cleanAmountString(_amountController.text.trim());
    final parsedAmount = double.tryParse(cleanedAmount) ?? 0.0;
    final dest = _classification == 'transferencia-propia'
        ? _selectedDestinationAccount
        : null;
    if (_classification == 'transferencia-propia' &&
        (dest == null || dest.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la cuenta de destino')),
      );
      return;
    }

    final result = CorrectionData(
      classification: _classification,
      category: _classification == 'transferencia-propia'
          ? 'Transferencia'
          : _selectedCategory,
      accountName: _selectedAccount,
      destinationAccount: dest,
      amount: parsedAmount,
      description: _descriptionController.text.trim(),
      date: _selectedDate,
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

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    if ((bottomInset - _lastBottomInset).abs() > 1) {
      _lastBottomInset = bottomInset;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
    }

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
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
                  // Cabecera fija estilo Moneo
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
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
                          width: 44,
                          height: 44,
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
                                ? Icons.arrow_upward_rounded
                                : _classification == 'transferencia-propia'
                                    ? Icons.swap_horiz_rounded
                                    : Icons.arrow_downward_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
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
                                  color: headerColor,
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

                  // Cuerpo scrolleable con indicador "Desliza para ver más"
                  Flexible(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildLabel(theme, 'Tipo de movimiento'),
                              const SizedBox(height: 6),
                              _buildTypeSelector(theme),
                              const SizedBox(height: 14),

                              _buildLabel(
                                  theme, 'Monto (${widget.item.moneda})'),
                              const SizedBox(height: 6),
                              _buildMoneoField(
                                theme,
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    ThousandsSeparatorInputFormatter(),
                                  ],
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(
                                        color: theme.textHint, fontSize: 14),
                                    border: InputBorder.none,
                                    prefixIcon: Icon(
                                      Icons.attach_money_rounded,
                                      color: headerColor,
                                      size: 20,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                  ),
                                  validator: (val) {
                                    final cleaned =
                                        CurrencyHelper.cleanAmountString(
                                            val?.trim() ?? '');
                                    final n = double.tryParse(cleaned);
                                    if (n == null || n <= 0) {
                                      return 'Ingresa un monto válido mayor a 0';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Transferencia: Cuenta origen arriba -> ícono conector -> Cuenta destino abajo
                              // Gasto / Ingreso: Cuenta al lado de Categoría (como Editar Ingreso)
                              if (_classification == 'transferencia-propia') ...[
                                _buildLabel(theme, 'Cuenta origen'),
                                const SizedBox(height: 6),
                                _buildAccountDropdown(theme),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: theme.borderSubtle,
                                          height: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: InkWell(
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          onTap: (_selectedDestinationAccount !=
                                                      null &&
                                                  _selectedDestinationAccount!
                                                      .isNotEmpty)
                                              ? () {
                                                  setState(() {
                                                    final prevOrigin =
                                                        _selectedAccount;
                                                    _selectedAccount =
                                                        _selectedDestinationAccount!;
                                                    _selectedDestinationAccount =
                                                        prevOrigin;
                                                  });
                                                }
                                              : null,
                                          child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: theme.accent
                                                  .withValues(alpha: 0.16),
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: theme.accent
                                                    .withValues(alpha: 0.4),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.arrow_downward_rounded,
                                              size: 16,
                                              color: theme.accent,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: theme.borderSubtle,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                _buildLabel(theme, 'Cuenta destino'),
                                const SizedBox(height: 6),
                                _buildDestinationDropdown(theme),
                              ] else
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel(theme, 'Cuenta'),
                                          const SizedBox(height: 6),
                                          _buildAccountDropdown(theme),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          _buildLabel(theme, 'Categoría'),
                                          const SizedBox(height: 6),
                                          _buildCategoryDropdown(
                                              theme, headerColor),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 14),

                              // Fila 2: Descripción al lado de Fecha (igual que Editar Ingreso)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(theme, 'Descripción'),
                                        const SizedBox(height: 6),
                                        _buildMoneoField(
                                          theme,
                                          child: TextFormField(
                                            controller: _descriptionController,
                                            style: TextStyle(
                                              color: theme.textPrimary,
                                              fontSize: 14,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Detalles...',
                                              hintStyle: TextStyle(
                                                color: theme.textHint,
                                                fontSize: 14,
                                              ),
                                              border: InputBorder.none,
                                              prefixIcon: Icon(
                                                Icons.description_outlined,
                                                color: headerColor,
                                                size: 18,
                                              ),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildLabel(theme, 'Fecha'),
                                        const SizedBox(height: 6),
                                        InkWell(
                                          onTap: _pickDate,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: _buildMoneoField(
                                            theme,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .calendar_today_rounded,
                                                    color: headerColor,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      _formatDate(
                                                          _selectedDate),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color:
                                                            theme.textPrimary,
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
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
                            ],
                          ),
                        ),

                        // Indicador de desplazamiento igual que EditAccountDialog
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedOpacity(
                            opacity: _showScrollIndicator ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            child: IgnorePointer(
                              ignoring: !_showScrollIndicator,
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      theme.secondaryCardBackground
                                          .withValues(alpha: 0.95),
                                    ],
                                  ),
                                ),
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Desliza para ver más',
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                    Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: theme.textSecondary,
                                      size: 20,
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

                  // Barra de botones fija abajo
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: theme.borderSubtle, width: 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: TextButton(
                            onPressed: () => Navigator.of(context).pop(null),
                            child: Text(
                              'Cancelar',
                              style: TextStyle(color: theme.textSecondary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: Container(
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Guardar corrección',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
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
    );
  }

  Widget _buildAccountDropdown(AppTheme theme) {
    return _buildMoneoField(
      theme,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedAccount,
          dropdownColor: theme.secondaryCardBackground,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: theme.textSecondary,
          ),
          isExpanded: true,
          style: TextStyle(color: theme.textPrimary),
          onChanged: (val) {
            if (val == null) return;
            setState(() {
              _selectedAccount = val;
              if (_selectedDestinationAccount == val) {
                final others = _accounts.where((a) => a != val).toList();
                _selectedDestinationAccount =
                    others.isNotEmpty ? others.first : null;
              }
            });
          },
          items: _accounts.map((acc) {
            return DropdownMenuItem<String>(
              value: acc,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_rounded,
                      color: theme.accent,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      acc,
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

  Widget _buildDestinationDropdown(AppTheme theme) {
    final availableDest =
        _accounts.where((acc) => acc != _selectedAccount).toList();
    final currentDest = availableDest.contains(_selectedDestinationAccount)
        ? _selectedDestinationAccount
        : null;

    return _buildMoneoField(
      theme,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentDest,
          hint: Text(
            'Destino',
            style: TextStyle(color: theme.textHint, fontSize: 14),
          ),
          dropdownColor: theme.secondaryCardBackground,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: theme.textSecondary,
          ),
          isExpanded: true,
          style: TextStyle(color: theme.textPrimary),
          onChanged: (val) {
            setState(() {
              _selectedDestinationAccount = val;
            });
          },
          items: availableDest.map((acc) {
            return DropdownMenuItem<String>(
              value: acc,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.income.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.account_balance_rounded,
                      color: theme.income,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      acc,
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

  Widget _buildCategoryDropdown(AppTheme theme, Color headerColor) {
    final currentCat = _currentCategories.contains(_selectedCategory)
        ? _selectedCategory
        : _currentCategories.first;

    return _buildMoneoField(
      theme,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentCat,
          dropdownColor: theme.secondaryCardBackground,
          icon: Icon(
            Icons.arrow_drop_down_rounded,
            color: theme.textSecondary,
          ),
          isExpanded: true,
          style: TextStyle(color: theme.textPrimary),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedCategory = val;
              });
            }
          },
          items: _currentCategories.map((cat) {
            return DropdownMenuItem<String>(
              value: cat,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _resolveCategoryIcon(cat),
                      color: headerColor,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      cat,
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

  Widget _buildMoneoField(AppTheme theme, {required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.borderSubtle,
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

  Widget _buildLabel(AppTheme theme, String text) {
    return Text(
      text,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildTypeSelector(AppTheme theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.darkBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        children: [
          _buildTypeSegment(
            theme,
            value: 'gasto',
            label: 'Gasto',
            icon: Icons.arrow_downward_rounded,
            activeColor: theme.expense,
          ),
          _buildTypeSegment(
            theme,
            value: 'ingreso',
            label: 'Ingreso',
            icon: Icons.arrow_upward_rounded,
            activeColor: theme.income,
          ),
          _buildTypeSegment(
            theme,
            value: 'transferencia-propia',
            label: 'Transferir',
            icon: Icons.swap_horiz_rounded,
            activeColor: theme.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildTypeSegment(
    AppTheme theme, {
    required String value,
    required String label,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _classification == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_classification == value) return;
          setState(() {
            _classification = value;
            _syncSelectedCategory();
          });
          WidgetsBinding.instance.addPostFrameCallback((_) => _checkScroll());
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.18)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(color: activeColor.withValues(alpha: 0.6))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeColor : theme.textSecondary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? activeColor : theme.textSecondary,
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _resolveCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('aliment') || lower.contains('comida')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('transport')) return Icons.directions_car_rounded;
    if (lower.contains('servic')) return Icons.receipt_long_rounded;
    if (lower.contains('salud')) return Icons.local_hospital_rounded;
    if (lower.contains('educa')) return Icons.school_rounded;
    if (lower.contains('entreten')) return Icons.movie_rounded;
    if (lower.contains('compra')) return Icons.shopping_bag_rounded;
    if (lower.contains('suscrip')) return Icons.subscriptions_rounded;
    if (lower.contains('hogar')) return Icons.home_rounded;
    if (lower.contains('salar') || lower.contains('nómina')) {
      return Icons.payments_rounded;
    }
    if (lower.contains('invers')) return Icons.trending_up_rounded;
    if (lower.contains('freelance')) return Icons.work_outline_rounded;
    return Icons.category_rounded;
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }
}
