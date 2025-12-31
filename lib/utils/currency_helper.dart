import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class para formatear cantidades con la divisa configurada por el usuario
class CurrencyHelper {
  static String _cachedCurrency = 'COP';
  static String _cachedSymbol = '\$';
  
  /// Mapeo de códigos de divisa a sus símbolos
  static const Map<String, String> _currencySymbols = {
    'COP': '\$',
    'USD': '\$',
    'EUR': '€',
    'MXN': '\$',
    'ARS': '\$',
    'BRL': 'R\$',
    'PEN': 'S/',
    'CLP': '\$',
    'GBP': '£',
    'JPY': '¥',
  };
  
  /// Mapeo de códigos de divisa a sus locales
  static const Map<String, String> _currencyLocales = {
    'COP': 'es_CO',
    'USD': 'en_US',
    'EUR': 'es_ES',
    'MXN': 'es_MX',
    'ARS': 'es_AR',
    'BRL': 'pt_BR',
    'PEN': 'es_PE',
    'CLP': 'es_CL',
    'GBP': 'en_GB',
    'JPY': 'ja_JP',
  };
  
  /// Carga la divisa desde SharedPreferences y actualiza el cache
  static Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedCurrency = prefs.getString('default_currency') ?? 'COP';
    _cachedSymbol = _currencySymbols[_cachedCurrency] ?? '\$';
  }
  
  /// Obtiene el código de la divisa actual (sincrónico, usa cache)
  static String get currencyCode => _cachedCurrency;
  
  /// Obtiene el símbolo de la divisa actual (sincrónico, usa cache)
  static String get currencySymbol => _cachedSymbol;
  
  /// Formatea una cantidad con la divisa configurada
  /// @param amount - Cantidad a formatear
  /// @param showSymbol - Si se debe mostrar el símbolo (default: true)
  /// @param decimalDigits - Número de decimales (default: 0)
  static String format(double amount, {bool showSymbol = true, int decimalDigits = 0}) {
    final locale = _currencyLocales[_cachedCurrency] ?? 'es';
    final symbol = showSymbol ? _cachedSymbol : '';
    
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
      decimalDigits: decimalDigits,
    ).format(amount);
  }
  
  /// Formatea una cantidad de tipo String con la divisa configurada
  static String formatString(String amountStr, {bool showSymbol = true, int decimalDigits = 0}) {
    final amount = double.tryParse(amountStr) ?? 0.0;
    return format(amount, showSymbol: showSymbol, decimalDigits: decimalDigits);
  }
  
  /// Obtiene un NumberFormat configurado con la divisa actual
  /// Útil para casos donde se necesita el formatter completo
  static NumberFormat getFormatter({bool showSymbol = true, int decimalDigits = 0}) {
    final locale = _currencyLocales[_cachedCurrency] ?? 'es';
    final symbol = showSymbol ? _cachedSymbol : '';
    
    return NumberFormat.currency(
      locale: locale,
      symbol: symbol,
    );
  }

  /// Formatea una cantidad en formato compacto (e.g. 1.2M, 50K) con la divisa configurada
  static String formatCompact(double amount, {bool showSymbol = true}) {
    final locale = _currencyLocales[_cachedCurrency] ?? 'es';
    final symbol = showSymbol ? _cachedSymbol : '';
    
    return NumberFormat.compactCurrency(
      locale: locale,
      symbol: symbol,
    ).format(amount);
  }
}
