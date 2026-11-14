import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/widgets/show_responsibility_options.dart';
import 'package:finazaap/widgets/add_responsibility_dialog.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

class AnnualProjectionScreen extends StatefulWidget {
  const AnnualProjectionScreen({Key? key}) : super(key: key);

  @override
  State<AnnualProjectionScreen> createState() => _AnnualProjectionScreenState();
}

class _AnnualProjectionScreenState extends State<AnnualProjectionScreen> {
  final int _currentMonth = DateTime.now().month;
  final int _currentYear = DateTime.now().year;

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase().trim()) {
      case 'servicio':
        return const Color(0xFF3B82F6); // Blue
      case 'membresía':
      case 'membresia':
        return const Color(0xFF8B5CF6); // Purple
      case 'tarjeta':
        return const Color(0xFFEF4444); // Red
      case 'préstamo':
      case 'prestamo':
        return const Color(0xFFF59E0B); // Orange
      case 'vivienda':
        return const Color(0xFF10B981); // Green
      case 'seguros':
        return const Color(0xFFEC4899); // Pink
      case 'educación':
      case 'educacion':
        return const Color(0xFF06B6D4); // Cyan
      case 'transporte':
        return const Color(0xFF6B7280); // Grey
      default:
        return Colors.blueGrey;
    }
  }

  void _showAddResponsibilityDialog({Responsibility? responsibility}) {
    showDialog(
      context: context,
      builder: (context) => AddResponsibilityDialog(responsibility: responsibility),
    ).then((_) => setState(() {}));
  }

  void _confirmDeleteResponsibility(Responsibility responsibility) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.cardBackground,
        title: const Text('Eliminar Obligación', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que deseas eliminar "${responsibility.safeName}"?', style: TextStyle(color: context.appTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ResponsibilityService.deleteResponsibility(responsibility.safeId);
              setState(() {});
              AlertHelper.success(context, '"${responsibility.safeName}" eliminada');
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _handleResponsibilityTap(Responsibility responsibility) {
    showResponsibilityOptions(
      context: context,
      responsibility: responsibility,
      selectedMonth: _currentMonth,
      selectedYear: _currentYear,
      onEdit: (r) => _showAddResponsibilityDialog(responsibility: r),
      onDelete: _confirmDeleteResponsibility,
      onPay: _showUnifiedPaymentDialog,
    );
  }

  void _showUnifiedPaymentDialog(Responsibility responsibility) async {
    final double expected = responsibility.getAmountForDate(_currentMonth, _currentYear);
    final double paid = responsibility.getPaidAmountInCycle(_currentMonth, _currentYear);
    final double suggestedAmount = (expected - paid).clamp(0.0, double.infinity);
    
    double initialValue = suggestedAmount > 0 
        ? suggestedAmount 
        : (responsibility.safeCategory == 'tarjeta' 
            ? (responsibility.cardBalance ?? expected) 
            : expected);

    final TextEditingController amountController = TextEditingController(text: CurrencyHelper.format(initialValue, showSymbol: false));
    final bool isCardResponsibility = responsibility.safeCategory == 'tarjeta';
    final List<Map<String, dynamic>> rawAccounts = await AccountService.getActiveAccounts();
    final List<Map<String, dynamic>> accounts = isCardResponsibility
        ? rawAccounts
            .where((a) => (a['title'] ?? '').toString().trim() != responsibility.safeName.trim())
            .toList()
        : rawAccounts;
    String? selectedAccountName;
    if (accounts.isNotEmpty) {
      selectedAccountName = accounts.first['title'];
    }

    DateTime selectedDate = DateTime.now();
    bool isMinimumPayment = true;
    bool markAsPaidComplete = true;

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Pagar Obligación",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: context.appTheme.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.getIcon(responsibility.safeIconCode), color: Colors.blueAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pagar ${responsibility.safeName}',
                        style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: StatefulBuilder(
                    builder: (context, setStateSB) {
                      Future<void> _pickPaymentDate() async {
                        final newDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.blueAccent,
                                  onPrimary: Colors.white,
                                  surface: context.appTheme.cardBackground,
                                  onSurface: context.appTheme.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (newDate != null) {
                          setStateSB(() {
                            selectedDate = newDate;
                          });
                        }
                      }

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pendiente para este mes',
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyHelper.format(suggestedAmount),
                                    style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(
                                      'Sugerido',
                                      style: TextStyle(
                                        color: isMinimumPayment ? context.appTheme.primaryBackground : context.appTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: isMinimumPayment,
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: context.appTheme.borderSubtle,
                                    onSelected: (val) {
                                      setStateSB(() {
                                        isMinimumPayment = true;
                                        amountController.text = CurrencyHelper.format(initialValue, showSymbol: false);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(
                                      'Personalizado',
                                      style: TextStyle(
                                        color: !isMinimumPayment ? context.appTheme.primaryBackground : context.appTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: !isMinimumPayment,
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: context.appTheme.borderSubtle,
                                    onSelected: (val) {
                                      setStateSB(() {
                                        isMinimumPayment = false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Monto a pagar',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              enabled: !isMinimumPayment,
                              style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.attach_money, color: context.appTheme.textSecondary),
                                filled: true,
                                fillColor: isMinimumPayment ? Colors.white.withOpacity(0.02) : Colors.black12,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cuenta de Pago',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.appTheme.borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedAccountName,
                                  dropdownColor: context.appTheme.cardBackground,
                                  isExpanded: true,
                                  hint: Text('Seleccionar cuenta', style: TextStyle(color: context.appTheme.textHint, fontSize: 14)),
                                  icon: Icon(Icons.keyboard_arrow_down, color: context.appTheme.textSecondary),
                                  items: accounts.map<DropdownMenuItem<String>>((account) {
                                    return DropdownMenuItem<String>(
                                      value: account['title'],
                                      child: Row(
                                        children: [
                                          Icon(
                                            AppIcons.getIcon(account['icon']),
                                            size: 16,
                                            color: Color(account['iconColor'] ?? 0xFFFFFFFF),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(account['title'], style: TextStyle(color: context.appTheme.textPrimary, fontSize: 14)),
                                          const Spacer(),
                                          Text(
                                            CurrencyHelper.formatCompact(double.tryParse(account['balance'].toString()) ?? 0),
                                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setStateSB(() {
                                      selectedAccountName = newValue;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Fecha del Pago',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickPaymentDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.appTheme.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(selectedDate),
                                      style: TextStyle(color: context.appTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.edit_calendar_rounded, color: context.appTheme.textSecondary, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: Text(
                                'Marcar obligación completa',
                                style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              value: markAsPaidComplete,
                              activeColor: Colors.blueAccent,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setStateSB(() {
                                  markAsPaidComplete = val;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancelar', style: TextStyle(color: context.appTheme.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      if (amountController.text.isEmpty || selectedAccountName == null) return;
                      final payAmount = double.tryParse(CurrencyHelper.cleanAmountString(amountController.text)) ?? 0.0;
                      if (payAmount <= 0) return;

                      Navigator.pop(dialogContext);

                      try {
                        final box = Hive.isBoxOpen('data')
                            ? Hive.box<Add_data>('data')
                            : await Hive.openBox<Add_data>('data');

                        if (isCardResponsibility) {
                          final success = await TransactionService.processTransaction(
                            type: 'Transfer',
                            amount: payAmount,
                            accountName: selectedAccountName!,
                            destinationAccount: responsibility.safeName,
                            isNewTransaction: true,
                            targetMonth: selectedDate.month,
                            targetYear: selectedDate.year,
                          );

                          if (success) {
                            final transaction = Add_data(
                              'Transfer',
                              payAmount.toString(),
                              selectedDate,
                              'Pago tarjeta: ${responsibility.safeName}',
                              '${selectedAccountName!} > ${responsibility.safeName}',
                              '',
                              Icons.sync_alt.codePoint,
                              '1',
                              true,
                            );
                            await box.add(transaction);
                            if (mounted) {
                              setState(() {});
                              AlertHelper.success(context, 'Pago registrado correctamente');
                            }
                          } else if (mounted) {
                            AlertHelper.error(context, 'Error al procesar la transacción');
                          }
                        } else {
                          final success = await TransactionService.processTransaction(
                            type: 'Expenses',
                            amount: payAmount,
                            accountName: selectedAccountName!,
                            isNewTransaction: true,
                          );

                          if (success) {
                            final matchedCat = await CategoryService.findMatchingCategoryForObligation(responsibility.safeCategory);
                            final String categoryName = matchedCat != null ? (matchedCat['text'] as String) : responsibility.safeCategory;
                            final int iconCode = matchedCat != null ? (matchedCat['icon'] as int) : responsibility.safeIconCode;

                            final transaction = Add_data(
                              'Expenses',
                              payAmount.toString(),
                              selectedDate,
                              'Pago obligación: ${responsibility.safeName}',
                              categoryName,
                              selectedAccountName!,
                              iconCode,
                              '1',
                              true,
                              responsibility.safeId,
                              true,
                            );
                            await box.add(transaction);

                            await ResponsibilityService.registerPayment(
                              responsibility.safeId,
                              payAmount,
                              selectedDate,
                              markAsPaidComplete,
                            );

                            if (mounted) {
                              setState(() {});
                              AlertHelper.success(context, 'Pago registrado correctamente');
                            }
                          } else if (mounted) {
                            AlertHelper.error(context, 'Error al procesar la transacción');
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          AlertHelper.error(context, 'Ocurrió un error: $e');
                        }
                      }
                    },
                    child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      appBar: MoneoHeaderBar.subScreen(
        title: 'Proyección Anual',
      ).asPreferredSize(context),
      body: ValueListenableBuilder(
        valueListenable: ResponsibilityService.getBox().listenable(),
        builder: (context, Box<Responsibility> box, _) {
          final list = box.values.where((r) => r.safeCategory != 'tarjeta').toList();

          double totalAnnual = 0.0;
          final Map<String, double> categorySums = {};
          for (var r in list) {
            final annualAmount = r.getAnnualAmount();
            totalAnnual += annualAmount;
            final cat = r.safeCategory;
            categorySums[cat] = (categorySums[cat] ?? 0.0) + annualAmount;
          }
          double monthlyAverage = totalAnnual / 12;

          final sortedCategories = categorySums.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          final sortedResponsibilities = List<Responsibility>.from(list)
            ..sort((a, b) => b.getAnnualAmount().compareTo(a.getAnnualAmount()));

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF8B5CF6).withOpacity(0.15),
                        const Color(0xFF3B82F6).withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 15,
                        spreadRadius: -2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PROYECCIÓN ANUAL TOTAL',
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyHelper.format(totalAnnual),
                                style: TextStyle(
                                  color: context.appTheme.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: context.appTheme.secondaryCardBackground,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: context.appTheme.borderVisible, width: 1.5),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Promedio Mensual',
                                  style: TextStyle(
                                    color: context.appTheme.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyHelper.format(monthlyAverage),
                                  style: TextStyle(
                                    color: context.appTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (sortedCategories.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Divider(color: context.appTheme.borderSubtle, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'Distribución por Categorías',
                          style: TextStyle(
                            color: context.appTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...sortedCategories.take(4).map((entry) {
                          final cat = entry.key;
                          final amt = entry.value;
                          final percentage = totalAnnual > 0 ? (amt / totalAnnual) : 0.0;
                          final color = _getCategoryColor(cat);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          cat.toUpperCase(),
                                          style: TextStyle(
                                            color: context.appTheme.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${CurrencyHelper.format(amt)} (${(percentage * 100).toStringAsFixed(0)}%)',
                                      style: TextStyle(
                                        color: context.appTheme.textPrimary,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: percentage,
                                    backgroundColor: context.appTheme.borderSubtle,
                                    valueColor: AlwaysStoppedAnimation<Color>(color),
                                    minHeight: 5,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Obligaciones Anuales',
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sortedResponsibilities.length} total',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (sortedResponsibilities.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 60, color: context.appTheme.borderSubtle),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes obligaciones registradas',
                          style: TextStyle(color: context.appTheme.textHint),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final r = sortedResponsibilities[index];
                        final annualCost = r.getAnnualAmount();
                        final catColor = _getCategoryColor(r.safeCategory);
                        final icon = AppIcons.getIcon(r.safeIconCode);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: context.appTheme.cardBackground,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: catColor.withOpacity(0.45),
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () => _handleResponsibilityTap(r),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            catColor.withOpacity(0.22),
                                            catColor.withOpacity(0.13),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: catColor.withOpacity(0.35),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(icon, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.safeName,
                                            style: TextStyle(
                                              color: context.appTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${CurrencyHelper.format(r.safeAmount, showSymbol: true)} / ${r.safeFrequency}',
                                            style: TextStyle(
                                              color: context.appTheme.textSecondary,
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          CurrencyHelper.format(annualCost),
                                          style: TextStyle(
                                            color: context.appTheme.accent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: catColor.withOpacity(0.15),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: catColor.withOpacity(0.25)),
                                          ),
                                          child: Text(
                                            r.safeFrequency.toUpperCase(),
                                            style: TextStyle(
                                              color: catColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: sortedResponsibilities.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "annual_projection_fab",
        onPressed: () => _showAddResponsibilityDialog(),
        backgroundColor: context.appTheme.accent,
        child: Icon(Icons.add_rounded, size: 32, color: context.appTheme.primaryBackground),
      ),
    );
  }
}
