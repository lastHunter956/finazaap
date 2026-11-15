import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:finazaap/Screens/main_container.dart';
import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/services/onboarding_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

/// Flujo guiado de primera apertura (5 pasos) y reapertura desde Ajustes.
class OnboardingScreen extends StatefulWidget {
  final int initialStep;
  final bool isReopened;
  final VoidCallback? onFinished;

  const OnboardingScreen({
    super.key,
    this.initialStep = 0,
    this.isReopened = false,
    this.onFinished,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const List<String> _suggestedExpenses = [
    'Alimentación',
    'Transporte',
    'Vivienda',
    'Servicios',
    'Salud',
    'Entretenimiento',
    'Educación',
    'Compras',
  ];

  static const List<String> _suggestedIncomes = [
    'Salario',
    'Freelance',
    'Ventas',
    'Inversiones',
    'Reembolsos',
    'Otros ingresos',
  ];

  static const List<String> _accountTypes = [
    'Efectivo',
    'Cuenta bancaria',
    'Billetera digital',
    'Tarjeta de crédito',
  ];

  late final PageController _pageController;
  late int _currentStep;
  bool _isBusy = false;

  // Paso 2: Categorías seleccionadas/creadas
  int _categoryTabIndex = 0; // 0 = Egresos, 1 = Ingresos
  final Set<String> _selectedExpenses = {};
  final Set<String> _selectedIncomes = {};
  final List<String> _customExpenses = [];
  final List<String> _customIncomes = [];
  List<String> _existingExpenses = [];
  List<String> _existingIncomes = [];

  // Paso 3: Primera cuenta
  String _selectedAccountType = 'Efectivo';
  final TextEditingController _accountNameCtrl = TextEditingController();
  final TextEditingController _accountBalanceCtrl = TextEditingController(
    text: '0',
  );
  String? _accountNameError;
  String? _accountBalanceError;

  // Paso 4: Primer movimiento real opcional
  int _txTypeIndex = 0; // 0 = Expenses, 1 = Income
  final TextEditingController _txAmountCtrl = TextEditingController();
  final TextEditingController _txDetailCtrl = TextEditingController();
  DateTime _txDate = DateTime.now();
  String? _txAccount;
  String? _txCategory;
  String? _txAmountError;
  List<Map<String, dynamic>> _activeAccounts = [];
  String? _recordedFirstTxSummary;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep.clamp(0, OnboardingService.totalSteps - 1);
    _pageController = PageController(initialPage: _currentStep);
    _loadExistingState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _accountNameCtrl.dispose();
    _accountBalanceCtrl.dispose();
    _txAmountCtrl.dispose();
    _txDetailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingState() async {
    final existingExp = await CategoryService.getCategories('Expenses');
    final existingInc = await CategoryService.getCategories('Income');
    final accounts = await AccountService.getActiveAccounts();
    if (!mounted) return;
    setState(() {
      _existingExpenses = existingExp;
      _existingIncomes = existingInc;
      _activeAccounts = accounts;
      _syncStep4Defaults();
    });
  }

  void _syncStep4Defaults() {
    if (_activeAccounts.isNotEmpty) {
      final titles = _activeAccounts
          .map((a) => (a['title'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .toList();
      if (_txAccount == null || !titles.contains(_txAccount)) {
        _txAccount = titles.isNotEmpty ? titles.first : null;
      }
    } else {
      _txAccount = null;
    }

    final categories = _txTypeIndex == 0 ? _existingExpenses : _existingIncomes;
    if (categories.isNotEmpty) {
      if (_txCategory == null || !categories.contains(_txCategory)) {
        _txCategory = categories.first;
      }
    } else {
      _txCategory = null;
    }
  }

  Future<void> _goToStep(int step, {bool persistStep = true}) async {
    final target = step.clamp(0, OnboardingService.totalSteps - 1);
    if (persistStep && !widget.isReopened) {
      await OnboardingService.advanceStep(target);
    }
    if (!mounted) return;
    setState(() {
      _currentStep = target;
    });
    await _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _confirmSkip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.appTheme.cardBackground,
        title: Text(
          '¿Omitir guía inicial?',
          style: TextStyle(color: context.appTheme.textPrimary),
        ),
        content: Text(
          'Podrás volver a abrirla cuando quieras desde Ajustes.',
          style: TextStyle(color: context.appTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: const Text('Seguir aquí'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: context.appTheme.buttonBackground,
              foregroundColor: context.appTheme.buttonForeground,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Omitir'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    if (!widget.isReopened) {
      await OnboardingService.skipOnboarding();
    }
    if (!mounted) return;
    _exitOnboarding();
  }

  void _exitOnboarding() {
    if (widget.onFinished != null) {
      widget.onFinished!();
      return;
    }
    if (widget.isReopened) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainContainer()),
      );
    }
  }

  Future<void> _handleBackPressed() async {
    if (_currentStep > 0) {
      await _goToStep(_currentStep - 1, persistStep: false);
      return;
    }
    if (widget.isReopened) {
      Navigator.of(context).pop();
      return;
    }
    await _confirmSkip();
  }

  Future<void> _saveCategoriesAndAdvance() async {
    setState(() => _isBusy = true);
    try {
      await OnboardingService.saveSelectedCategories(
        expenseCategories: _selectedExpenses.toList(),
        incomeCategories: _selectedIncomes.toList(),
      );
      await _loadExistingState();
      await _goToStep(2);
    } catch (_) {
      if (mounted) {
        AlertHelper.error(
          context,
          'No se pudo guardar en el dispositivo. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _showCreateCategoryDialog() async {
    final nameCtrl = TextEditingController();
    int dialogType = _categoryTabIndex;
    String? errorMsg;

    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: context.appTheme.cardBackground,
          title: Text(
            'Nueva categoría',
            style: TextStyle(color: context.appTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MoneoSegmentedControl<int>(
                options: const [
                  MoneoSegmentOption(value: 0, label: 'Egreso'),
                  MoneoSegmentOption(value: 1, label: 'Ingreso'),
                ],
                selectedValue: dialogType,
                onChanged: (idx) => setDialogState(() => dialogType = idx),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre de la categoría',
                  errorText: errorMsg,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  setDialogState(
                    () => errorMsg = 'Por favor ingresa un nombre',
                  );
                  return;
                }
                final pool = dialogType == 0
                    ? {..._existingExpenses, ..._suggestedExpenses, ..._customExpenses}
                    : {..._existingIncomes, ..._suggestedIncomes, ..._customIncomes};
                if (pool.any((e) => e.toLowerCase() == name.toLowerCase())) {
                  setDialogState(
                    () => errorMsg = 'Ya existe una categoría con ese nombre',
                  );
                  return;
                }
                Navigator.of(ctx).pop({'name': name, 'type': dialogType});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: context.appTheme.buttonBackground,
                foregroundColor: context.appTheme.buttonForeground,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );

    nameCtrl.dispose();
    if (created == null || !mounted) return;
    final name = created['name'] as String;
    final type = created['type'] as int;
    setState(() {
      if (type == 0) {
        _customExpenses.add(name);
        _selectedExpenses.add(name);
        _categoryTabIndex = 0;
      } else {
        _customIncomes.add(name);
        _selectedIncomes.add(name);
        _categoryTabIndex = 1;
      }
    });
  }

  Future<void> _saveAccountAndAdvance() async {
    final name = _accountNameCtrl.text.trim();
    final rawBal = CurrencyHelper.cleanAmountString(_accountBalanceCtrl.text);
    final bal = rawBal.isEmpty ? 0.0 : double.tryParse(rawBal);

    setState(() {
      _accountNameError = name.isEmpty
          ? 'Por favor ingresa un nombre para la cuenta'
          : name.contains(' > ')
              ? 'El nombre no puede contener " > "'
              : null;
      _accountBalanceError = bal == null
          ? 'El monto debe ser un número válido'
          : bal < 0
              ? 'El saldo inicial no puede ser negativo'
              : null;
    });

    if (_accountNameError != null || _accountBalanceError != null) return;

    setState(() => _isBusy = true);
    try {
      final err = await OnboardingService.saveFirstAccount(
        title: name,
        accountType: _selectedAccountType,
        initialBalance: bal!,
      );
      if (!mounted) return;
      if (err != null) {
        setState(() => _accountNameError = err);
        return;
      }
      await _loadExistingState();
      await _goToStep(3);
    } catch (_) {
      if (mounted) {
        AlertHelper.error(
          context,
          'No se pudo guardar en el dispositivo. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _saveFirstTransactionAndAdvance() async {
    final cleanAmount = CurrencyHelper.cleanAmountString(_txAmountCtrl.text);
    final parsed = double.tryParse(cleanAmount);

    setState(() {
      _txAmountError = cleanAmount.isEmpty
          ? 'Por favor ingresa un monto'
          : (parsed == null)
              ? 'El monto debe ser un número válido'
              : (parsed <= 0)
                  ? 'El monto debe ser mayor a 0'
                  : null;
    });

    if (_txAmountError != null) return;
    if (_txAccount == null || _txCategory == null) {
      AlertHelper.warning(context, 'Por favor selecciona cuenta y categoría');
      return;
    }

    setState(() => _isBusy = true);
    try {
      final txType = _txTypeIndex == 0 ? 'Expenses' : 'Income';
      final err = await OnboardingService.recordFirstTransaction(
        type: txType,
        amount: parsed!,
        accountTitle: _txAccount!,
        category: _txCategory!,
        date: _txDate,
        detail: _txDetailCtrl.text,
      );
      if (!mounted) return;
      if (err != null) {
        AlertHelper.error(context, err);
        return;
      }
      setState(() {
        final sign = _txTypeIndex == 0 ? '-' : '+';
        _recordedFirstTxSummary =
            '$sign${CurrencyHelper.format(parsed)} (${_txCategory!})';
      });
      await _loadExistingState();
      await _goToStep(4);
    } catch (_) {
      if (mounted) {
        AlertHelper.error(
          context,
          'No se pudo guardar en el dispositivo. Intenta de nuevo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _finishOnboarding() async {
    if (!widget.isReopened) {
      await OnboardingService.completeOnboarding();
    }
    if (!mounted) return;
    _exitOnboarding();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleBackPressed();
        }
      },
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(theme),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _wrapPage(0, _buildStep1Welcome(theme)),
                    _wrapPage(1, _buildStep2Categories(theme)),
                    _wrapPage(2, _buildStep3Account(theme)),
                    _wrapPage(3, _buildStep4FirstTransaction(theme)),
                    _wrapPage(4, _buildStep5Summary(theme)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _wrapPage(int stepIndex, Widget child) {
    final isActive = _currentStep == stepIndex;
    return ExcludeSemantics(
      excluding: !isActive,
      child: FocusTraversalGroup(
        child: child,
      ),
    );
  }

  Widget _buildTopBar(AppTheme theme) {
    final stepLabel = 'Paso ${_currentStep + 1} de ${OnboardingService.totalSteps}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Semantics(
                  label: stepLabel,
                  child: Text(
                    stepLabel,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (_currentStep < 4)
                Semantics(
                  button: true,
                  label: 'Omitir guía inicial',
                  child: TextButton(
                    onPressed: _isBusy ? null : _confirmSkip,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    child: Text(
                      'Omitir',
                      style: TextStyle(
                        color: theme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 48),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / OnboardingService.totalSteps,
              minHeight: 6,
              backgroundColor: theme.cardBackground,
              valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1Welcome(AppTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 56, color: theme.accent),
          const SizedBox(height: 16),
          Text(
            'Bienvenido a Moneo',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tus datos se guardan en tu dispositivo. Moneo no requiere una cuenta en la nube para usar sus funciones principales.',
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _infoCard(
            theme,
            Icons.category_outlined,
            'Organiza tus cuentas y categorías',
            'Elige o crea solo las categorías y cuentas que realmente usas.',
          ),
          const SizedBox(height: 12),
          _infoCard(
            theme,
            Icons.add_circle_outline,
            'Registra en segundos',
            'Anota ingresos, gastos o transferencias desde el botón +.',
          ),
          const SizedBox(height: 12),
          _infoCard(
            theme,
            Icons.smartphone_outlined,
            'Almacenamiento en tu dispositivo',
            'Tus movimientos y saldos se almacenan localmente en tu teléfono.',
          ),
          const SizedBox(height: 24),
          _primaryButton(
            theme: theme,
            label: 'Comenzar',
            onPressed: _isBusy ? null : () => _goToStep(1),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2Categories(AppTheme theme) {
    final isExpenses = _categoryTabIndex == 0;
    final options = isExpenses
        ? {..._existingExpenses, ..._suggestedExpenses, ..._customExpenses}.toList()
        : {..._existingIncomes, ..._suggestedIncomes, ..._customIncomes}.toList();
    final selectedSet = isExpenses ? _selectedExpenses : _selectedIncomes;
    final existingSet = isExpenses ? _existingExpenses : _existingIncomes;
    final totalSelected = _selectedExpenses.length + _selectedIncomes.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Elige tus primeras categorías',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selecciona las que uses o crea las tuyas. No agregamos categorías sin tu permiso.',
            style: TextStyle(color: theme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 14),
          MoneoSegmentedControl<int>(
            options: const [
              MoneoSegmentOption(value: 0, label: 'Egresos'),
              MoneoSegmentOption(value: 1, label: 'Ingresos'),
            ],
            selectedValue: _categoryTabIndex,
            onChanged: (idx) => setState(() => _categoryTabIndex = idx),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((cat) {
              final alreadySaved = existingSet.any(
                (e) => e.toLowerCase() == cat.toLowerCase(),
              );
              final isSelected = alreadySaved || selectedSet.contains(cat);
              final typeLabel = isExpenses ? 'egreso' : 'ingreso';
              return Semantics(
                button: true,
                selected: isSelected,
                label: '$cat, categoría de $typeLabel',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: FilterChip(
                    label: Text(alreadySaved ? '$cat (ya creada)' : cat),
                    selected: isSelected,
                    onSelected: alreadySaved
                        ? null
                        : (val) {
                            setState(() {
                              if (val) {
                                selectedSet.add(cat);
                              } else {
                                selectedSet.remove(cat);
                              }
                            });
                          },
                    selectedColor: theme.accent.withValues(alpha: 0.2),
                    checkmarkColor: theme.accent,
                    labelStyle: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Semantics(
            button: true,
            label: 'Crear categoría propia',
            child: OutlinedButton.icon(
              onPressed: _isBusy ? null : _showCreateCategoryDialog,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Crear categoría propia'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: theme.accent,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_selectedExpenses.length} de egresos · ${_selectedIncomes.length} de ingresos seleccionadas',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  theme: theme,
                  label: 'Atrás',
                  onPressed: _isBusy ? null : () => _goToStep(0, persistStep: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _primaryButton(
                  theme: theme,
                  label: totalSelected > 0
                      ? 'Guardar y continuar'
                      : 'Continuar sin categorías',
                  onPressed: _isBusy ? null : _saveCategoriesAndAdvance,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Account(AppTheme theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crea tu primera cuenta',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Puede ser efectivo, cuenta bancaria, billetera digital o tarjeta de crédito.',
            style: TextStyle(color: theme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _accountTypes.map((type) {
              final isSelected = _selectedAccountType == type;
              return Semantics(
                button: true,
                selected: isSelected,
                label: 'Tipo de cuenta $type',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _selectedAccountType = type);
                    },
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accountNameCtrl,
            decoration: InputDecoration(
              labelText: 'Nombre de la cuenta',
              hintText: 'Ej. Efectivo principal',
              errorText: _accountNameError,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountBalanceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Saldo inicial',
              errorText: _accountBalanceError,
            ),
          ),
          const SizedBox(height: 20),
          _primaryButton(
            theme: theme,
            label: 'Crear cuenta y continuar',
            onPressed: _isBusy ? null : _saveAccountAndAdvance,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  theme: theme,
                  label: 'Atrás',
                  onPressed: _isBusy ? null : () => _goToStep(1, persistStep: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _secondaryButton(
                  theme: theme,
                  label: 'Omitir y crear después',
                  onPressed: _isBusy ? null : () => _goToStep(3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4FirstTransaction(AppTheme theme) {
    final accountTitles = _activeAccounts
        .map((a) => (a['title'] ?? '').toString())
        .where((t) => t.isNotEmpty)
        .toList();
    final categories = _txTypeIndex == 0 ? _existingExpenses : _existingIncomes;
    final canRecord = accountTitles.isNotEmpty && categories.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Registra tu primer movimiento (opcional)',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Registra tu primer ingreso o gasto real para verlo en tu balance, o continúa directo al resumen.',
            style: TextStyle(color: theme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          MoneoSegmentedControl<int>(
            options: const [
              MoneoSegmentOption(value: 0, label: 'Egreso'),
              MoneoSegmentOption(value: 1, label: 'Ingreso'),
            ],
            selectedValue: _txTypeIndex,
            onChanged: (idx) {
              setState(() {
                _txTypeIndex = idx;
                _syncStep4Defaults();
              });
            },
          ),
          const SizedBox(height: 16),
          if (!canRecord) ...[
            _infoCard(
              theme,
              Icons.info_outline,
              'Falta cuenta o categoría',
              'Para registrar un movimiento primero necesitas al menos 1 cuenta y 1 categoría.',
            ),
            const SizedBox(height: 16),
          ] else ...[
            TextField(
              controller: _txAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Monto',
                errorText: _txAmountError,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: accountTitles.contains(_txAccount) ? _txAccount : null,
              decoration: const InputDecoration(labelText: 'Cuenta'),
              items: accountTitles
                  .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) => setState(() => _txAccount = val),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: categories.contains(_txCategory) ? _txCategory : null,
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (val) => setState(() => _txCategory = val),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Fecha: ${DateFormat('dd/MM/yyyy').format(_txDate)}',
                style: TextStyle(color: theme.textPrimary),
              ),
              trailing: Icon(Icons.calendar_today_outlined, color: theme.accent),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _txDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null && mounted) {
                  setState(() => _txDate = picked);
                }
              },
            ),
            TextField(
              controller: _txDetailCtrl,
              decoration: const InputDecoration(
                labelText: 'Detalle (opcional)',
              ),
            ),
            const SizedBox(height: 20),
            _primaryButton(
              theme: theme,
              label: 'Guardar movimiento',
              onPressed: _isBusy ? null : _saveFirstTransactionAndAdvance,
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _secondaryButton(
                  theme: theme,
                  label: 'Atrás',
                  onPressed: _isBusy ? null : () => _goToStep(2, persistStep: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _secondaryButton(
                  theme: theme,
                  label: 'Omitir este paso',
                  onPressed: _isBusy ? null : () => _goToStep(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep5Summary(AppTheme theme) {
    final catSummary = (_existingIncomes.isEmpty && _existingExpenses.isEmpty)
        ? 'Ninguna aún — puedes crearlas en Categorías'
        : '${_existingIncomes.length} ingresos · ${_existingExpenses.length} egresos';
    final accSummary = _activeAccounts.isEmpty
        ? 'Ninguna aún — puedes crearlas en Cuentas'
        : _activeAccounts
            .map((a) => '${a['title']} (${CurrencyHelper.format(double.tryParse((a['balance'] ?? '0').toString()) ?? 0)})')
            .join(', ');
    final txSummary = _recordedFirstTxSummary ?? 'Sin movimientos iniciales';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.check_circle_outline_rounded, size: 56, color: theme.accent),
          const SizedBox(height: 12),
          Text(
            '¡Todo listo!',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Así quedó tu punto de partida en Moneo.',
            style: TextStyle(color: theme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 18),
          _infoCard(theme, Icons.category_outlined, 'Categorías configuradas', catSummary),
          const SizedBox(height: 10),
          _infoCard(theme, Icons.account_balance_outlined, 'Cuentas activas', accSummary),
          const SizedBox(height: 10),
          _infoCard(theme, Icons.receipt_long_outlined, 'Primer movimiento', txSummary),
          const SizedBox(height: 14),
          Text(
            'Usa el botón + en Inicio para registrar movimientos cuando quieras.',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 22),
          _primaryButton(
            theme: theme,
            label: widget.isReopened ? 'Volver a Ajustes' : 'Ir a Inicio',
            onPressed: _isBusy ? null : _finishOnboarding,
          ),
        ],
      ),
    );
  }

  Widget _infoCard(
    AppTheme theme,
    IconData icon,
    String title,
    String body,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.accent, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required AppTheme theme,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.buttonBackground,
          foregroundColor: theme.buttonForeground,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _secondaryButton({
    required AppTheme theme,
    required String label,
    required VoidCallback? onPressed,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.textPrimary,
          side: BorderSide(color: theme.borderVisible),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
