
import 'package:flutter/material.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/widgets/show_transaction_options.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/liquid_glass_surface.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';

class DailyTransactionsScreen extends StatefulWidget {
  final String dateString;
  final List<Add_data> transactions;
  final double dailyIncome;
  final double dailyExpense;

  const DailyTransactionsScreen({
    Key? key,
    required this.dateString,
    required this.transactions,
    required this.dailyIncome,
    required this.dailyExpense,
  }) : super(key: key);

  @override
  State<DailyTransactionsScreen> createState() => _DailyTransactionsScreenState();
}

class _DailyTransactionsScreenState extends State<DailyTransactionsScreen> {
  late List<Add_data> _transactions;
  late double _dailyIncome;
  late double _dailyExpense;
  final box = Hive.box<Add_data>('data');

  @override
  void initState() {
    super.initState();
    _transactions = widget.transactions;
    _dailyIncome = widget.dailyIncome;
    _dailyExpense = widget.dailyExpense;
  }

  void _refreshTransactions() {
    setState(() {
       final parts = widget.dateString.split('/');
       final day = int.parse(parts[0]);
       final month = int.parse(parts[1]);
       final year = int.parse(parts[2]);

       _transactions = box.values.where((t) =>
         t.safeDate.day == day &&
         t.safeDate.month == month &&
         t.safeDate.year == year
       ).toList();

       _transactions.sort((a, b) => b.safeDate.compareTo(a.safeDate));

       _dailyIncome = 0;
       _dailyExpense = 0;

       for (var transaction in _transactions) {
         if (transaction.safeType == 'Income') {
           _dailyIncome += double.parse(transaction.safeAmount);
         } else if (transaction.safeType == 'Expenses') {
           _dailyExpense += double.parse(transaction.safeAmount);
         }
       }
    });
  }

  @override
  Widget build(BuildContext context) {
    final netBalance = _dailyIncome - _dailyExpense;

    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _CollapsibleHeaderDelegate(
                minHeight: 165,
                maxHeight: 325,
                dateString: widget.dateString,
                netBalance: netBalance,
                dailyIncome: _dailyIncome,
                dailyExpense: _dailyExpense,
                onBackPressed: () => Navigator.pop(context),
              ),
            ),

            _transactions.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: context.appTheme.textHint,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay transacciones',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: MoneoLayoutMetrics.scrollBottomPadding(
                      context,
                      hasFab: true,
                      horizontal: 16,
                      top: 10,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final transaction = _transactions[index];
                          return Column(
                            children: [
                              _buildTransactionItem(transaction),
                              const SizedBox(height: 8),
                            ],
                          );
                        },
                        childCount: _transactions.length,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Add_data history) {
    bool isTransfer = history.IN == 'Transfer';
    bool isIncome = history.IN == 'Income';

    String mainTitle;
    if (isTransfer) {
      mainTitle = history.safeDetail.isNotEmpty
          ? "Transferencia - ${history.safeDetail}"
          : "Transferencia";
    } else {
      mainTitle = history.safeDetail.isNotEmpty
          ? "${history.safeCategory} - ${history.safeDetail}"
          : history.safeCategory;
    }

    IconData transactionIcon;
    if (isTransfer) {
      transactionIcon = Icons.sync_alt;
    } else {
      transactionIcon = AppIcons.getIcon(history.safeIconCode);
    }

    final Color typeColor = isTransfer
        ? context.appTheme.secondaryAccent
        : (isIncome ? context.appTheme.income : context.appTheme.expense);
    final Color readableTypeColor = AppColors.getReadableColor(typeColor, context);
    final bool isLight = Theme.of(context).brightness == Brightness.light;

    return Semantics(
      button: true,
      label: '$mainTitle, ${CurrencyHelper.formatString(history.safeAmount)}',
      child: InkWell(
        onTap: () => showTransactionOptions(history, context, _editTransaction, _confirmDeleteTransaction),
        splashColor: context.appTheme.accent.withValues(alpha: 0.1),
        highlightColor: context.appTheme.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        child: Container(
          decoration: BoxDecoration(
            color: context.appTheme.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
            border: Border.all(color: context.appTheme.borderSubtle, width: 1),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.45),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(10),
                child: Icon(
                  transactionIcon,
                  size: 22,
                  color: readableTypeColor,
                ),
              ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainTitle,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.textPrimary,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isTransfer
                        ? (history.explain ?? '')
                        : history.safeAccount,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyHelper.formatString(history.safeAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isTransfer
                          ? context.appTheme.textSecondary
                          : (isIncome
                              ? context.appTheme.income
                              : context.appTheme.expense),
                    ),
                  ),
                  if (history.installments != null && history.installments != '1' && history.installments!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: context.appTheme.accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: context.appTheme.accent.withOpacity(0.4), width: 0.5),
                      ),
                      child: Text(
                        '${history.installments} cuotas',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.appTheme.accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  void _confirmDeleteTransaction(Add_data transaction) {
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          backgroundColor: ctx.appTheme.cardBackground,
          title: Text('Eliminar transacción', style: TextStyle(color: ctx.appTheme.textPrimary)),
          content: Text(
            '¿Estás seguro de que deseas eliminar esta transacción?',
            style: TextStyle(color: ctx.appTheme.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancelar', style: TextStyle(color: ctx.appTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _deleteTransaction(transaction);
              },
              child: Text('Eliminar', style: TextStyle(color: ctx.appTheme.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(Add_data transaction) async {
    if (!transaction.isInBox) return;

    final deleted = await TransactionService.deleteTransaction(transaction);
    if (!mounted) return;

    if (!deleted) {
      AlertHelper.error(context, 'No se pudo eliminar la transacción');
      return;
    }

    _refreshTransactions();
    AlertHelper.success(context, 'Transacción eliminada');
  }

  void _editTransaction(Add_data transaction) async {
    int? key = transaction.key as int?;

    Widget editScreen;
    if (transaction.IN == 'Transfer') {
      editScreen = TransferScreen(
        isEditing: true,
        transaction: transaction,
        transactionKey: key,
        onTransactionUpdated: _refreshTransactions,
      );
    } else if (transaction.IN == 'Income') {
      editScreen = Add_Screen(
        isEditing: true,
        transaction: transaction,
        transactionKey: key,
        onTransactionUpdated: _refreshTransactions,
      );
    } else {
      editScreen = AddExpenseScreen(
        isEditing: true,
        transaction: transaction,
        transactionKey: key,
        onTransactionUpdated: _refreshTransactions,
      );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => editScreen),
    );

    _refreshTransactions();
  }
}

// ================================
// DELEGATE PARA HEADER COLAPSABLE
// ================================

class _CollapsibleHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final String dateString;
  final double netBalance;
  final double dailyIncome;
  final double dailyExpense;
  final VoidCallback onBackPressed;

  _CollapsibleHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.dateString,
    required this.netBalance,
    required this.dailyIncome,
    required this.dailyExpense,
    required this.onBackPressed,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => math.max(maxHeight, minHeight);

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / (maxExtent - minExtent);
    final progressClamped = progress.clamp(0.0, 1.0);
    final bool showCollapsed = progressClamped > 0.2;

    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.secondaryCardBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios_rounded, color: context.appTheme.textPrimary),
                  onPressed: onBackPressed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transacciones del día',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateString,
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: showCollapsed
                  ? _buildCompactSummary(context)
                  : _buildExpandedSummary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSummary(BuildContext context) {
    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: netBalance >= 0
                    ? [Colors.green.withOpacity(0.15), Colors.green.withOpacity(0.05)]
                    : [Colors.redAccent.withOpacity(0.15), Colors.redAccent.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: netBalance >= 0 ? Colors.green.withOpacity(0.3) : Colors.redAccent.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      netBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                      color: netBalance >= 0 ? context.appTheme.income : context.appTheme.expense,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Balance del Día',
                      style: TextStyle(
                        color: context.appTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyHelper.format(netBalance),
                  style: TextStyle(
                    color: netBalance >= 0 ? context.appTheme.income : context.appTheme.expense,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withOpacity(0.2), width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_downward_rounded,
                              color: context.appTheme.income,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Ingresos",
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dailyIncome >= 1000000
                            ? NumberFormat.compact(locale: 'es').format(dailyIncome) + ' ' + CurrencyHelper.currencySymbol
                            : CurrencyHelper.format(dailyIncome),
                        style: TextStyle(
                          color: context.appTheme.income,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_upward_rounded,
                              color: context.appTheme.expense,
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Gastos",
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dailyExpense >= 1000000
                            ? NumberFormat.compact(locale: 'es').format(dailyExpense) + ' ' + CurrencyHelper.currencySymbol
                            : CurrencyHelper.format(dailyExpense),
                        style: TextStyle(
                          color: context.appTheme.expense,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactSummary(BuildContext context) {
    return Padding(
      key: const ValueKey('compact'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: context.appTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: context.appTheme.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        netBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: netBalance >= 0 ? context.appTheme.income : context.appTheme.expense,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Balance',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.compact(locale: 'es').format(netBalance),
                    style: TextStyle(
                      color: netBalance >= 0 ? context.appTheme.income : context.appTheme.expense,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Container(
              width: 1,
              height: 40,
              color: context.appTheme.borderSubtle,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        color: context.appTheme.income,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ingresos',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.compact(locale: 'es').format(dailyIncome),
                    style: TextStyle(
                      color: context.appTheme.income,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: context.appTheme.expense,
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Gastos',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.compact(locale: 'es').format(dailyExpense),
                    style: TextStyle(
                      color: context.appTheme.expense,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_CollapsibleHeaderDelegate oldDelegate) {
    return netBalance != oldDelegate.netBalance ||
        dailyIncome != oldDelegate.dailyIncome ||
        dailyExpense != oldDelegate.dailyExpense ||
        dateString != oldDelegate.dateString;
  }
}
