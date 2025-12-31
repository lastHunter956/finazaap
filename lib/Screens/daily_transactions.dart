
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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:finazaap/utils/currency_helper.dart';

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

  // Actualizar la lista si cambia algo en la base de datos
  void _refreshTransactions() {
    setState(() {
      // Re-filtrar desde la caja global usando la fecha actual
       final parts = widget.dateString.split('/');
       final day = int.parse(parts[0]);
       final month = int.parse(parts[1]);
       final year = int.parse(parts[2]);
       
       _transactions = box.values.where((t) => 
         t.safeDate.day == day && 
         t.safeDate.month == month && 
         t.safeDate.year == year
       ).toList();
       
       // Ordenar de nuevo
       _transactions.sort((a, b) => b.safeDate.compareTo(a.safeDate));
       
       // Recalcular totales
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
    // Calcular balance neto del día
    final netBalance = _dailyIncome - _dailyExpense;
    
    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header colapsable
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
            
            // Lista de transacciones
            _transactions.isEmpty
                ? SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Colors.white.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay transacciones',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
    
    // Construir título
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

    return InkWell(
      onTap: () => showTransactionOptions(history, context, _editTransaction, _confirmDeleteTransaction),
      splashColor: Colors.blueAccent.withOpacity(0.1),
      highlightColor: Colors.blueAccent.withOpacity(0.05),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color.fromRGBO(42, 49, 67, 1),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
             // Icono con fondo coloreado
            Container(
              decoration: BoxDecoration(
                color: isTransfer
                    ? Colors.blueAccent
                    : (isIncome ? Colors.green : Colors.redAccent),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(
                transactionIcon,
                size: 22,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(width: 14),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mainTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white60,
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
                          ? Colors.grey
                          : (isIncome
                              ? const Color.fromARGB(255, 167, 226, 169)
                              : const Color.fromARGB(255, 230, 172, 168)),
                    ),
                  ),
                  if (history.installments != null && history.installments != '1' && history.installments!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 0.5),
                      ),
                      child: Text(
                        '${history.installments} cuotas',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.lightBlueAccent,
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
    );
  }

  // --- LOGICA DE EDICIÓN / ELIMINACIÓN ---

  void _confirmDeleteTransaction(Add_data transaction) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 30, 30, 30),
          title: const Text('Eliminar transacción', style: TextStyle(color: Colors.white)),
          content: const Text(
            '¿Estás seguro de que deseas eliminar esta transacción?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteTransaction(transaction);
              },
              child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteTransaction(Add_data transaction) async {
    await _updateAccountBalanceAfterDeletion(transaction);
    await transaction.delete();
    
    _refreshTransactions();
    TransactionService.syncAccountBalances();
    
    AlertHelper.success(context, 'Transacción eliminada');
  }

  Future<void> _updateAccountBalanceAfterDeletion(Add_data transaction) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> accountsData = prefs.getStringList('accounts') ?? [];
    List<Map<String, dynamic>> accounts = accountsData
        .map((e) => json.decode(e) as Map<String, dynamic>)
        .toList();

    double amount = double.parse(transaction.safeAmount);

    if (transaction.IN == 'Income') {
       for (var acc in accounts) {
         if (acc['name'] == transaction.safeAccount) {
           double currentBalance = (acc['balance'] is String)
               ? double.parse(acc['balance'])
               : (acc['balance'] as num).toDouble();
           acc['balance'] = currentBalance - amount;
           break;
         }
       }
    } else if (transaction.IN == 'Expenses') {
       for (var acc in accounts) {
         if (acc['name'] == transaction.safeAccount) {
           double currentBalance = (acc['balance'] is String)
               ? double.parse(acc['balance'])
               : (acc['balance'] as num).toDouble();
           acc['balance'] = currentBalance + amount;
           break;
         }
       }
    } else if (transaction.IN == 'Transfer') {
       List<String> parts = (transaction.explain ?? '').split(' > ');
       if (parts.length == 2) {
         String sourceName = parts[0];
         String destName = parts[1];
         
         for (var acc in accounts) {
           if (acc['name'] == sourceName) {
             double currentBalance = (acc['balance'] is String)
                 ? double.parse(acc['balance'])
                 : (acc['balance'] as num).toDouble();
             acc['balance'] = currentBalance + amount;
           } else if (acc['name'] == destName) {
             double currentBalance = (acc['balance'] is String)
                 ? double.parse(acc['balance'])
                 : (acc['balance'] as num).toDouble();
             acc['balance'] = currentBalance - amount;
           }
         }
       }
    }

    List<String> updatedAccountsData = accounts.map((e) => json.encode(e)).toList();
    await prefs.setStringList('accounts', updatedAccountsData);
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
    // Calcular progreso de colapso: 0.0 (expandido) a 1.0 (colapsado)
    final progress = shrinkOffset / (maxExtent - minExtent);
    final progressClamped = progress.clamp(0.0, 1.0);
    
    // Determinar si mostrar versión colapsada (threshold 20% para cambio)
    final bool showCollapsed = progressClamped > 0.2;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color.fromRGBO(42, 49, 67, 1),
            const Color.fromRGBO(35, 42, 58, 1),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // HEADER FIJO (siempre visible)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                  onPressed: onBackPressed,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transacciones del día',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        dateString,
                        style: const TextStyle(
                          color: Colors.white,
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
          
          // CONTENIDO ANIMADO (cambia entre expandido y colapsado)
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeInOut,
              switchOutCurve: Curves.easeInOut,
              child: showCollapsed
                  ? _buildCompactSummary()
                  : _buildExpandedSummary(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedSummary() {
    return Padding(
      key: const ValueKey('expanded'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        children: [
          // Balance neto
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
                      color: netBalance >= 0
                          ? const Color.fromARGB(255, 167, 226, 169)
                          : const Color(0xFFEF9A9A),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Balance del Día',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
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
                    color: netBalance >= 0
                        ? const Color.fromARGB(255, 167, 226, 169)
                        : const Color(0xFFEF9A9A),
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Ingresos y Gastos
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
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Color.fromARGB(255, 167, 226, 169),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Ingresos",
                            style: TextStyle(
                              color: Colors.white60,
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
                        style: const TextStyle(
                          color: Color.fromARGB(255, 167, 226, 169),
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
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Color(0xFFEF9A9A),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            "Gastos",
                            style: TextStyle(
                              color: Colors.white60,
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
                        style: const TextStyle(
                          color: Color(0xFFEF9A9A),
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

  Widget _buildCompactSummary() {
    return Padding(
      key: const ValueKey('compact'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Balance
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        netBalance >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: netBalance >= 0
                            ? const Color.fromARGB(255, 167, 226, 169)
                            : const Color(0xFFEF9A9A),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Balance',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.6),
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
                      color: netBalance >= 0
                          ? const Color.fromARGB(255, 167, 226, 169)
                          : const Color(0xFFEF9A9A),
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Separador
            Container(
              width: 1,
              height: 40,
              color: Colors.white.withOpacity(0.1),
            ),
            
            const SizedBox(width: 12),
            
            // Ingresos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_downward_rounded,
                        color: const Color.fromARGB(255, 167, 226, 169),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ingresos',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.compact(locale: 'es').format(dailyIncome),
                    style: const TextStyle(
                      color: Color.fromARGB(255, 167, 226, 169),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Gastos
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        color: const Color(0xFFEF9A9A),
                        size: 12,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Gastos',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    NumberFormat.compact(locale: 'es').format(dailyExpense),
                    style: const TextStyle(
                      color: Color(0xFFEF9A9A),
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

  Widget _buildExpandedView() {
    return Column(
      children: [
        // Barra superior
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
                onPressed: onBackPressed,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Transacciones del día',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateString,
                      style: const TextStyle(
                        color: Colors.white,
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
        
        // Resumen financiero
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              // Balance neto
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
                          color: netBalance >= 0
                              ? const Color.fromARGB(255, 167, 226, 169)
                              : const Color(0xFFEF9A9A),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Balance del Día',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
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
                        color: netBalance >= 0
                            ? const Color.fromARGB(255, 167, 226, 169)
                            : const Color(0xFFEF9A9A),
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Ingresos y Gastos
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
                                child: const Icon(
                                  Icons.arrow_downward_rounded,
                                  color: Color.fromARGB(255, 167, 226, 169),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Ingresos",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyHelper.format(dailyIncome),
                            style: const TextStyle(
                              color: Color.fromARGB(255, 167, 226, 169),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
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
                                child: const Icon(
                                  Icons.arrow_upward_rounded,
                                  color: Color(0xFFEF9A9A),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                "Gastos",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CurrencyHelper.format(dailyExpense),
                            style: const TextStyle(
                              color: Color(0xFFEF9A9A),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: onBackPressed,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  dateString,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      CurrencyHelper.format(netBalance),
                      style: TextStyle(
                        color: netBalance >= 0
                            ? const Color.fromARGB(255, 167, 226, 169)
                            : const Color(0xFFEF9A9A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '•',
                       style: TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_downward_rounded,
                      size: 10,
                      color: const Color.fromARGB(255, 167, 226, 169),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      NumberFormat.compact(locale: 'es').format(dailyIncome),
                      style: const TextStyle(
                        color: Color.fromARGB(255, 167, 226, 169),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_upward_rounded,
                      size: 10,
                      color: const Color(0xFFEF9A9A),
                    ),
                    const SizedBox(width: 2),
                    Text(
                      NumberFormat.compact(locale: 'es').format(dailyExpense),
                      style: const TextStyle(
                        color: Color(0xFFEF9A9A),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
