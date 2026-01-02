import 'package:home_widget/home_widget.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive/hive.dart';
import 'package:finazaap/utils/currency_helper.dart';

class WidgetService {
  static const String appGroupId = 'group.finazaap';
  static const String androidWidgetName = 'FinazaapWidgetProvider';
  
  /// Update the widget with income and expense totals
  static Future<void> updateWidget({
    required double income,
    required double expense,
  }) async {
    try {
      final formattedIncome = CurrencyHelper.format(income);
      final formattedExpense = CurrencyHelper.format(expense);

      // Save Data to Widget
      await HomeWidget.saveWidgetData<String>('income', formattedIncome);
      await HomeWidget.saveWidgetData<String>('expense', formattedExpense);
      
      // Update Widget
      await HomeWidget.updateWidget(
        name: androidWidgetName,
      );
      print('✅ Widget updated - Income: $formattedIncome, Expense: $formattedExpense');
    } catch (e) {
      print('❌ Error updating widget: $e');
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
      
      for (var item in box.values) {
        if (item.safeDate.month == now.month && item.safeDate.year == now.year) {
          final amount = double.tryParse(item.safeAmount) ?? 0;
          if (item.safeType == 'Income') {
            totalIncome += amount;
          } else if (item.safeType == 'Expenses') {
            totalExpense += amount;
          }
        }
      }
      
      await updateWidget(income: totalIncome, expense: totalExpense);
    } catch (e) {
      print('❌ Error refreshing widget data: $e');
    }
  }
}
