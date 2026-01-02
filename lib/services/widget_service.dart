import 'package:home_widget/home_widget.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:intl/intl.dart';

class WidgetService {
  static const String appGroupId = 'group.finazaap';
  static const String androidWidgetName = 'FinazaapWidgetProvider';
  
  /// Update the widget with income, expense, balance and last transactions
  static Future<void> updateWidget({
    required double income,
    required double expense,
    List<Add_data>? lastTransactions,
  }) async {
    try {
      final formattedIncome = CurrencyHelper.format(income);
      final formattedExpense = CurrencyHelper.format(expense);
      final balance = income - expense;
      final formattedBalance = CurrencyHelper.format(balance);
      final isPositive = balance >= 0;

      // Save main data to Widget
      await HomeWidget.saveWidgetData<String>('income', formattedIncome);
      await HomeWidget.saveWidgetData<String>('expense', formattedExpense);
      await HomeWidget.saveWidgetData<String>('balance', formattedBalance);
      await HomeWidget.saveWidgetData<bool>('is_positive', isPositive);
      
      // Save last 3 transactions
      if (lastTransactions != null && lastTransactions.isNotEmpty) {
        for (int i = 0; i < 3; i++) {
          if (i < lastTransactions.length) {
            final t = lastTransactions[i];
            final isIncome = t.safeType == 'Income';
            final amount = double.tryParse(t.safeAmount) ?? 0;
            final formattedAmount = CurrencyHelper.format(amount);
            
            // Format date relative to today
            final dateStr = _formatRelativeDate(t.safeDate);
            
            // Determine name (category for non-transfers, "Transferencia" for transfers)
            final name = t.safeType == 'Transfer' 
                ? 'Transferencia' 
                : t.safeCategory;
            
            await HomeWidget.saveWidgetData<String>('t${i}_name', name);
            await HomeWidget.saveWidgetData<String>('t${i}_amount', formattedAmount);
            await HomeWidget.saveWidgetData<String>('t${i}_date', dateStr);
            await HomeWidget.saveWidgetData<bool>('t${i}_income', isIncome);
            await HomeWidget.saveWidgetData<bool>('t${i}_visible', true);
          } else {
            // Hide unused transaction rows
            await HomeWidget.saveWidgetData<bool>('t${i}_visible', false);
          }
        }
      } else {
        // No transactions, hide all rows
        for (int i = 0; i < 3; i++) {
          await HomeWidget.saveWidgetData<bool>('t${i}_visible', false);
        }
      }
      
      // Update Widget
      await HomeWidget.updateWidget(
        name: androidWidgetName,
      );
      print('✅ Widget updated - Income: $formattedIncome, Expense: $formattedExpense, Balance: $formattedBalance');
    } catch (e) {
      print('❌ Error updating widget: $e');
    }
  }

  /// Format date relative to today (Hoy, Ayer, or DD/MM)
  static String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDate = DateTime(date.year, date.month, date.day);
    
    final difference = today.difference(targetDate).inDays;
    
    if (difference == 0) {
      return 'Hoy';
    } else if (difference == 1) {
      return 'Ayer';
    } else if (difference < 7) {
      // Show day name for this week
      const days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return days[date.weekday - 1];
    } else {
      // Show date
      return DateFormat('dd/MM').format(date);
    }
  }

  /// Calculate totals from Hive box and update widget
  static Future<void> refreshWidgetFromData() async {
    try {
      var box = Hive.isBoxOpen('data') 
          ? Hive.box<Add_data>('data') 
          : await Hive.openBox<Add_data>('data');
      
      double totalIncome = 0;
      double totalExpense = 0;
      
      // Get current month data only
      final now = DateTime.now();
      final List<Add_data> monthTransactions = [];
      
      for (var item in box.values) {
        if (item.safeDate.month == now.month && item.safeDate.year == now.year) {
          final amount = double.tryParse(item.safeAmount) ?? 0;
          if (item.safeType == 'Income') {
            totalIncome += amount;
          } else if (item.safeType == 'Expenses') {
            totalExpense += amount;
          }
          monthTransactions.add(item);
        }
      }
      
      // Sort by date descending to get last transactions
      monthTransactions.sort((a, b) => b.safeDate.compareTo(a.safeDate));
      
      // Get last 3 transactions (or fewer if not enough)
      final lastTransactions = monthTransactions.take(3).toList();
      
      await updateWidget(
        income: totalIncome, 
        expense: totalExpense,
        lastTransactions: lastTransactions,
      );
    } catch (e) {
      print('❌ Error refreshing widget data: $e');
    }
  }
}
