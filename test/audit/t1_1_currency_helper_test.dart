import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> setCurrency(String code) async {
    SharedPreferences.setMockInitialValues({'default_currency': code});
    await PrefsManager.init();
    await CurrencyHelper.loadCurrency();
  }

  test('L1.10 CLP: lectura, edición con ThousandsSeparatorInputFormatter y guardado de montos CLP', () async {
    await setCurrency('CLP');

    // Lectura / formateo
    expect(CurrencyHelper.format(10000.0, showSymbol: false), '10.000');
    expect(CurrencyHelper.format(10000.0), '\$ 10.000');

    // Edición en campo monetario
    final formatter = ThousandsSeparatorInputFormatter();
    final edited = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '10000', selection: TextSelection.collapsed(offset: 5)),
    );
    expect(edited.text, '10.000');

    // Guardado / limpieza a número parseable
    expect(double.parse(CurrencyHelper.cleanAmountString(edited.text)), closeTo(10000.0, 0.01));
    expect(double.parse(CurrencyHelper.cleanAmountString('1.250.000')), closeTo(1250000.0, 0.01));
  });

  test('Regresión monedas punto-miles / coma-decimal (COP, ARS, BRL, UYU, VES, EUR)', () async {
    final formatter = ThousandsSeparatorInputFormatter();
    for (final code in const ['COP', 'ARS', 'BRL', 'UYU', 'VES', 'EUR']) {
      await setCurrency(code);

      final formatted = CurrencyHelper.format(1234.56, showSymbol: false);
      expect(formatted, '1.234,56', reason: 'format($code)');
      expect(
        double.parse(CurrencyHelper.cleanAmountString(formatted)),
        closeTo(1234.56, 0.01),
        reason: 'cleanAmountString($code)',
      );

      final edited = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '1234,56', selection: TextSelection.collapsed(offset: 7)),
      );
      expect(edited.text, '1.234,56', reason: 'formatter($code)');
    }
  });

  test('Regresión monedas coma-miles / punto-decimal (USD, MXN, PEN, GBP, JPY)', () async {
    final formatter = ThousandsSeparatorInputFormatter();
    for (final code in const ['USD', 'MXN', 'PEN', 'GBP']) {
      await setCurrency(code);

      final formatted = CurrencyHelper.format(1234.56, showSymbol: false);
      expect(formatted, '1,234.56', reason: 'format($code)');
      expect(
        double.parse(CurrencyHelper.cleanAmountString(formatted)),
        closeTo(1234.56, 0.01),
        reason: 'cleanAmountString($code)',
      );

      final edited = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '1234.56', selection: TextSelection.collapsed(offset: 7)),
      );
      expect(edited.text, '1,234.56', reason: 'formatter($code)');
    }

    await setCurrency('JPY');
    final jpyFormatted = CurrencyHelper.format(10000.0, showSymbol: false);
    expect(jpyFormatted, '10,000');
    expect(double.parse(CurrencyHelper.cleanAmountString(jpyFormatted)), closeTo(10000.0, 0.01));
    final jpyEdited = formatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      const TextEditingValue(text: '10000', selection: TextSelection.collapsed(offset: 5)),
    );
    expect(jpyEdited.text, '10,000');
  });
}
