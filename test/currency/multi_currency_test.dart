import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/app_theme_mode.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({'default_currency': 'COP'});
    await CurrencyHelper.loadCurrency();
  });

  group('CurrencyHelper multimoneda sin estado global mutado', () {
    test('expone catálogo soportado y normaliza códigos sin mutar _cachedCurrency', () {
      expect(CurrencyHelper.currencyCode, 'COP');
      expect(CurrencyHelper.supportedCurrencies, containsAll(['COP', 'USD', 'EUR', 'CLP', 'JPY']));
      expect(CurrencyHelper.isSupported('usd'), isTrue);
      expect(CurrencyHelper.isSupported('XYZ'), isFalse);
      expect(CurrencyHelper.normalizeCode(' eur '), 'EUR');
      expect(CurrencyHelper.normalizeCode('UNKNOWN', fallback: 'USD'), 'USD');
      expect(CurrencyHelper.normalizeCode(null), 'COP');

      expect(CurrencyHelper.symbolFor('USD'), '\$');
      expect(CurrencyHelper.symbolFor('EUR'), '€');
      expect(CurrencyHelper.symbolFor('JPY'), '¥');
      expect(CurrencyHelper.decimalDigitsFor('USD'), 2);
      expect(CurrencyHelper.decimalDigitsFor('CLP'), 0);
      expect(CurrencyHelper.decimalDigitsFor('JPY'), 0);

      // El estado global permanece intacto
      expect(CurrencyHelper.currencyCode, 'COP');
    });

    test('formatFor y cleanAmountStringFor respetan cada moneda independientemente del global', () {
      expect(CurrencyHelper.currencyCode, 'COP');

      expect(CurrencyHelper.formatFor(1234.56, 'USD'), '\$1,234.56');
      expect(CurrencyHelper.formatFor(1234.56, 'COP'), '\$ 1.234,56');
      expect(CurrencyHelper.formatFor(1234.56, 'EUR'), '1.234,56 €');
      expect(CurrencyHelper.formatFor(15990, 'CLP'), '\$ 15.990');
      expect(CurrencyHelper.formatFor(1500, 'JPY'), '¥1,500');

      expect(CurrencyHelper.cleanAmountStringFor('1,234.56', currencyCode: 'USD'), '1234.56');
      expect(CurrencyHelper.cleanAmountStringFor('1.234,56', currencyCode: 'COP'), '1234.56');
      expect(CurrencyHelper.cleanAmountStringFor('15.990', currencyCode: 'CLP'), '15990');

      expect(CurrencyHelper.currencyCode, 'COP');
    });

    test('ThousandsSeparatorInputFormatter con currencyCode explícito usa los separadores de esa moneda', () {
      final usdFormatter = ThousandsSeparatorInputFormatter(currencyCode: 'USD');
      final copFormatter = ThousandsSeparatorInputFormatter(currencyCode: 'COP');

      final usdEdited = usdFormatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '1234.56',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(usdEdited.text, '1,234.56');

      final copEdited = copFormatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(
          text: '1234,56',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(copEdited.text, '1.234,56');
    });
  });

  group('MultiCurrencyTotals y compatibilidad de transferencias', () {
    test('agrupa totales separados por moneda y nunca suma monedas distintas', () {
      final totals = MultiCurrencyTotals(fallbackCurrency: 'COP');
      totals.add('COP', 1000000.0);
      totals.add('cop', 500000.0);
      totals.add('USD', 200.0);
      totals.add('usd', 50.5);

      expect(totals.isMultiCurrency, isTrue);
      expect(totals.currencies, ['COP', 'USD']);
      expect(totals.totalFor('COP'), 1500000.0);
      expect(totals.totalFor('USD'), 250.5);
      expect(totals.totalFor('EUR'), 0.0);

      final lines = totals.formatLines();
      expect(lines.length, 2);
      expect(lines[0], contains('COP'));
      expect(lines[0], contains('1.500.000,00'));
      expect(lines[1], contains('USD'));
      expect(lines[1], contains('250.50'));
    });

    test('canTransferWithoutConversion solo permite transferencias entre misma moneda', () {
      expect(CurrencyHelper.canTransferWithoutConversion('COP', 'cop'), isTrue);
      expect(CurrencyHelper.canTransferWithoutConversion('USD', 'USD'), isTrue);
      expect(CurrencyHelper.canTransferWithoutConversion('COP', 'USD'), isFalse);
      expect(CurrencyHelper.canTransferWithoutConversion(null, 'USD'), isFalse);
      expect(CurrencyHelper.canTransferWithoutConversion(null, 'COP'), isTrue);
    });
  });

  group('TotalBalanceWidget presentación multimoneda', () {
    testWidgets('muestra totales separados por moneda cuando existen múltiples monedas', (tester) async {
      final balanceNotifier = ValueNotifier<double>(1000000.0);
      final byCurrencyNotifier = ValueNotifier<Map<String, double>>({
        'COP': 1000000.0,
        'USD': 250.0,
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildThemeData(AppThemeMode.diurno),
          home: Scaffold(
            body: SingleChildScrollView(
              child: TotalBalanceWidget(
                availableBalanceNotifier: balanceNotifier,
                availableBalancesByCurrencyNotifier: byCurrencyNotifier,
                accountingBalance: 800000.0,
                accountingBalancesByCurrency: const {
                  'COP': 800000.0,
                  'USD': 100.0,
                },
                totalExpenses: 200000.0,
                expensesByCurrency: const {
                  'COP': 200000.0,
                  'USD': 50.0,
                },
                totalIncome: 1000000.0,
                incomeByCurrency: const {
                  'COP': 1000000.0,
                  'USD': 150.0,
                },
                onManageAccounts: () {},
                onShowAll: () {},
                onShowExpenses: () {},
                onShowIncome: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('\$ 1.000.000,00 COP'), findsNWidgets(2));
      expect(find.text('\$250.00 USD'), findsOneWidget);
      expect(find.text('\$ 800.000,00 COP'), findsOneWidget);
      expect(find.text('\$100.00 USD'), findsOneWidget);
      expect(find.text('\$ 200.000,00 COP'), findsOneWidget);
      expect(find.text('\$50.00 USD'), findsOneWidget);
      expect(find.text('\$150.00 USD'), findsOneWidget);
    });
  });
}
