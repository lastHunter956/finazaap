import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Helper class para formatear cantidades con la divisa configurada por el usuario
class CurrencyHelper {
  static String _cachedCurrency = 'COP';
  
  /// Configuración Maestra de Monedas
  /// Define explícitamente cómo debe verse cada moneda, independiente del locale del dispositivo
  static const Map<String, Map<String, dynamic>> _currencyConfig = {
    // ════════════════════════════════════════════════════════════════════════════
    // GRUPO 1: Formato "Americano" (Coma para miles, Punto para decimales)
    // Ejemplo: $1,234.56
    // ════════════════════════════════════════════════════════════════════════════
    'USD': {
      'locale': 'en_US', 
      'symbol': '\$', 
      'position': 'left', 
      'space': false, 
      'decimals': 2
    },
    'MXN': {
      'locale': 'en_US', // Forzamos en_US para garantizar , y .
      'symbol': '\$', 
      'position': 'left', 
      'space': false, 
      'decimals': 2
    },
    'PEN': {
      'locale': 'en_US', 
      'symbol': 'S/', 
      'position': 'left', 
      'space': true, // S/ 1,234.56
      'decimals': 2
    },
    'GBP': {
      'locale': 'en_GB', 
      'symbol': '£', 
      'position': 'left', 
      'space': false, 
      'decimals': 2
    },

    // ════════════════════════════════════════════════════════════════════════════
    // GRUPO 2: Formato "Latino/Europeo" (Punto para miles, Coma para decimales)
    // Ejemplo: $ 1.234,56
    // ════════════════════════════════════════════════════════════════════════════
    'COP': {
      'locale': 'es_AR', // Forzamos es_AR que garantiza . y , (es_CO a veces varía)
      'symbol': '\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'ARS': {
      'locale': 'es_AR', 
      'symbol': '\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'BRL': {
      'locale': 'pt_BR', 
      'symbol': 'R\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'UYU': {
      'locale': 'es_UY', // o es_AR
      'symbol': '\$U', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'VES': {
      'locale': 'es_VE', // o es_AR
      'symbol': 'Bs.', 
      'position': 'left', 
      'space': true, 
      'decimals': 2
    },
    'CLP': {
      'locale': 'es_CL', // o es_AR
      'symbol': '\$', 
      'position': 'left', 
      'space': true, 
      'decimals': 0 // Sin decimales
    },
    'EUR': {
      'locale': 'es_ES', 
      'symbol': '€', 
      'position': 'right', // Euro va a la derecha: 1.234,56 €
      'space': true, 
      'decimals': 2
    },
    
    // Otros
    'JPY': {
      'locale': 'ja_JP', 
      'symbol': '¥', 
      'position': 'left', 
      'space': false, 
      'decimals': 0
    },
  };
  
  /// Carga la divisa desde SharedPreferences y actualiza el cache
  static Future<void> loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _cachedCurrency = prefs.getString('default_currency') ?? 'COP';
  }
  
  /// Obtiene el código de la divisa actual
  static String get currencyCode => _cachedCurrency;
  
  /// Obtiene el símbolo
  static String get currencySymbol {
    final config = _currencyConfig[_cachedCurrency];
    return config != null ? config['symbol'] as String : '\$';
  }
  
  /// Formatea una cantidad con control TOTAL sobre la posición y separadores
  static String format(double amount, {bool showSymbol = true, int? decimalDigits}) {
    // 1. Obtener configuración
    final config = _currencyConfig[_cachedCurrency] ?? _currencyConfig['USD']!;
    
    final locale = config['locale'] as String;
    final symbol = config['symbol'] as String;
    final position = config['position'] as String; // 'left' or 'right'
    final space = config['space'] as bool;
    final defaultDecimals = config['decimals'] as int;
    
    final digits = decimalDigits ?? defaultDecimals;
    
    // 2. Formatear SÓLO el número (sin símbolo) usando NumberFormat
    // Usamos currency(symbol: '') para obtener los separadores correctos pero sin el símbolo default
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: '', 
      decimalDigits: digits,
    );
    
    String formattedNumber = formatter.format(amount).trim();
    
    // 3. Construir el string final manualmente
    if (!showSymbol) return formattedNumber;
    
    final spacer = space ? ' ' : '';
    
    if (position == 'left') {
      return '$symbol$spacer$formattedNumber';
    } else {
      return '$formattedNumber$spacer$symbol';
    }
  }
  
  /// Formatea desde String
  static String formatString(String amountStr, {bool showSymbol = true, int? decimalDigits}) {
    final amount = double.tryParse(amountStr) ?? 0.0;
    return format(amount, showSymbol: showSymbol, decimalDigits: decimalDigits);
  }

  /// Formatea compacto (1M, 10K)
  static String formatCompact(double amount, {bool showSymbol = true}) {
    // Para compacto, delegamos al sistema pero intentamos respetar el locale
    final config = _currencyConfig[_cachedCurrency] ?? _currencyConfig['USD']!;
    final locale = config['locale'] as String;
    final symbol = config['symbol'] as String;
    
    final formatter = NumberFormat.compactCurrency(
      locale: locale,
      symbol: showSymbol ? symbol : '',
    );
    
    return formatter.format(amount);
  }
  
  // Getter legacy para compatibilidad si alguien lo usa
  static NumberFormat getFormatter({bool showSymbol = true, int? decimalDigits}) {
    // Advertencia: Este método retorna un formatter estándar y podría no respetar 
    // exactamenta la posición forzada en format(). Usar format() preferiblemente.
    final config = _currencyConfig[_cachedCurrency] ?? _currencyConfig['USD']!;
    return NumberFormat.currency(
      locale: config['locale'] as String,
      symbol: showSymbol ? config['symbol'] as String : '',
      decimalDigits: decimalDigits ?? config['decimals'] as int,
    );
  }
}
