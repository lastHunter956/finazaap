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
        backgroundColor: const Color(0xFF222939),
        title: const Text('Eliminar Obligación', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que deseas eliminar "${responsibility.safeName}"?', style: const TextStyle(color: Colors.white70)),
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
    final List<Map<String, dynamic>> accounts = await AccountService.getActiveAccounts();
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
                backgroundColor: const Color(0xFF222939),
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
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.blueAccent,
                                  onPrimary: Colors.white,
                                  surface: Color(0xFF222939),
                                  onSurface: Colors.white,
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
                                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                                        color: isMinimumPayment ? const Color(0xFF1F2639) : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: isMinimumPayment,
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: Colors.white.withOpacity(0.05),
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
                                        color: !isMinimumPayment ? const Color(0xFF1F2639) : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: !isMinimumPayment,
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: Colors.white.withOpacity(0.05),
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
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              enabled: !isMinimumPayment,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.attach_money, color: Colors.white70),
                                filled: true,
                                fillColor: isMinimumPayment ? Colors.white.withOpacity(0.02) : Colors.black12,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Cuenta de Pago',
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.black12,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withOpacity(0.05)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedAccountName,
                                  dropdownColor: const Color(0xFF222939),
                                  isExpanded: true,
                                  hint: const Text('Seleccionar cuenta', style: TextStyle(color: Colors.white54, fontSize: 14)),
                                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
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
                                          Text(account['title'], style: const TextStyle(color: Colors.white, fontSize: 14)),
                                          const Spacer(),
                                          Text(
                                            CurrencyHelper.formatCompact(double.tryParse(account['balance'].toString()) ?? 0),
                                            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
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
                              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, fontWeight: FontWeight.w500),
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
                                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(selectedDate),
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.edit_calendar_rounded, color: Colors.white54, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SwitchListTile(
                              title: const Text(
                                'Marcar obligación completa',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
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
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
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
                        final success = await TransactionService.processTransaction(
                          type: 'Expenses',
                          amount: payAmount,
                          accountName: selectedAccountName!,
                          isNewTransaction: true,
                        );

                        if (success) {
                          final box = Hive.isBoxOpen('data')
                              ? Hive.box<Add_data>('data')
                              : await Hive.openBox<Add_data>('data');
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

                          setState(() {});
                          AlertHelper.success(context, 'Pago registrado correctamente');
                        } else {
                          AlertHelper.error(context, 'Error al procesar la transacción');
                        }
                      } catch (e) {
                        AlertHelper.error(context, 'Ocurrió un error: $e');
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
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Proyección Anual',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                CurrencyHelper.format(totalAnnual),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Promedio Mensual',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyHelper.format(monthlyAverage),
                                  style: const TextStyle(
                                    color: Colors.white,
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
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 16),
                        Text(
                          'Distribución por Categorías',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
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
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      '${CurrencyHelper.format(amt)} (${(percentage * 100).toStringAsFixed(0)}%)',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
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
                                    backgroundColor: Colors.white.withOpacity(0.05),
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
                      const Text(
                        'Obligaciones Anuales',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sortedResponsibilities.length} total',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
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
                        Icon(Icons.calendar_today_outlined, size: 60, color: Colors.white.withOpacity(0.1)),
                        const SizedBox(height: 12),
                        Text(
                          'No tienes obligaciones registradas',
                          style: TextStyle(color: Colors.white.withOpacity(0.4)),
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
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(const Color(0xFF222939), catColor, 0.12)!,
                                const Color(0xFF222939),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            border: Border.all(
                              color: catColor.withOpacity(0.15),
                              width: 1,
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
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${CurrencyHelper.format(r.safeAmount, showSymbol: true)} / ${r.safeFrequency}',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(0.5),
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
                                          style: const TextStyle(
                                            color: Color(0xFF52E2FF),
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
        backgroundColor: const Color(0xFF52E2FF),
        child: const Icon(Icons.add_rounded, size: 32, color: Color(0xFF1F2639)),
      ),
    );
  }
}
