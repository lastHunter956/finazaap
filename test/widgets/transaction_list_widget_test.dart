import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/transaction_list_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const days = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'USD'});
    await CurrencyHelper.loadCurrency();
  });

  testWidgets(
    'TransactionListWidget renderiza lista pre-filtrada y respeta maxVisibleCount sin overflow',
    (tester) async {
      final items = List<Add_data>.generate(
        25,
        (i) => Add_data(
          i.isEven ? 'Expenses' : 'Income',
          '${(i + 1) * 10}',
          DateTime(2026, 11, (i % 28) + 1),
          'Detalle $i',
          'Categoría $i',
          'Cuenta Principal',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildThemeData(AppThemeMode.diurno),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                TransactionListWidget(
                  transactions: items,
                  maxVisibleCount: 5,
                  day: days,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Categoría 0 - Detalle 0'), findsOneWidget);
      expect(find.text('Categoría 1 - Detalle 1'), findsOneWidget);
      expect(find.text('Categoría 20 - Detalle 20'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
