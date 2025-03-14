import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hive/hive.dart';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../icon_lists.dart';
import '../data/model/add_date.dart';
import 'package:flutter/services.dart';

class AccountItem {
  String title;
  double balance;
  IconData? icon;
  Color? iconColor;

  AccountItem({
    required this.title,
    required this.balance,
    this.icon,
    this.iconColor,
  });

  factory AccountItem.fromJson(Map<String, dynamic> json) {
    // Extraer balance
    double balanceValue;
    if (json['balance'] is String) {
      balanceValue = double.tryParse(json['balance']) ?? 0.0;
    } else {
      balanceValue = (json['balance'] is double) ? json['balance'] : 0.0;
    }

    // Extraer icono
    IconData? iconData;
    if (json['icon'] != null) {
      iconData = IconData(json['icon'], fontFamily: 'MaterialIcons');
    }

    // Extraer color del icono
    Color? iconColor;
    if (json['iconColor'] != null) {
      iconColor = Color(json['iconColor']);
    }

    return AccountItem(
      title: json['title'] ?? '',
      balance: balanceValue,
      icon: iconData,
      iconColor: iconColor,
    );
  }
}

// Estructura para gráficos
class ChartData {
  final String x;
  final double y;
  final Color color;
  final int iconCode; // Añadir este campo

  ChartData(this.x, this.y,
      [this.color = Colors.teal, this.iconCode = 0]); // Actualizar constructor
}

class Statistics extends StatefulWidget {
  const Statistics({Key? key}) : super(key: key);

  @override
  State<Statistics> createState() => _StatisticsState();
}

class _StatisticsState extends State<Statistics> {
  // Alternar entre “Ingresos” y “Gastos”
  bool isIncomeSelected = true;

  // Alternar entre “Mensual” y “Anual”
  bool isMonthly = true;

  // Listado completo de transacciones (leído de Hive)
  List<Add_data> allData = [];

  // Datos filtrados según el modo (mensual/anual) y el toggle (Ingresos/Gastos)
  List<Add_data> filteredData = [];

  // Años y meses disponibles (solo los que tienen registros)
  // yearToMonths: para cada año, un Set de meses que tienen datos
  final Set<int> availableYears = {};
  final Map<int, Set<int>> yearToMonths = {};

  // Año y mes seleccionados
  int selectedYear = DateTime.now().year;
  int selectedMonth = DateTime.now().month;

  List<AccountItem> _accountsList = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadAccounts(); // Añadir esta línea para cargar las cuentas
  }

  /// Carga los datos de Hive (o tu fuente de datos) y construye
  /// la estructura de años y meses disponibles.
  void _loadData() {
    final box = Hive.box<Add_data>('data');
    allData = box.values.toList();

    _buildAvailableDates();
    _pickInitialDate();
    _updateData();
  }

  /// Carga las cuentas desde SharedPreferences
  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');
    if (accountsData != null) {
      setState(() {
        _accountsList = accountsData
            .map((item) => AccountItem.fromJson(json.decode(item)))
            .toList();
      });
    }
  }

  /// Construye los años y meses disponibles a partir de allData
  void _buildAvailableDates() {
    availableYears.clear();
    yearToMonths.clear();

    for (var item in allData) {
      final y = item.datetime.year;
      final m = item.datetime.month;
      availableYears.add(y);
      yearToMonths.putIfAbsent(y, () => {});
      yearToMonths[y]!.add(m);
    }
  }

  /// Selecciona por defecto el año y mes actual si existen en los datos.
  /// Si no existen, selecciona el primero disponible en `availableYears`.
  void _pickInitialDate() {
    final now = DateTime.now();
    if (availableYears.contains(now.year)) {
      // Si el año actual tiene registros
      selectedYear = now.year;
      final availableMonths = yearToMonths[now.year]!;
      if (availableMonths.contains(now.month)) {
        // Si el mes actual también tiene registros
        selectedMonth = now.month;
      } else {
        // Seleccionamos el primer mes disponible en ese año
        selectedMonth = availableMonths.first;
      }
    } else if (availableYears.isNotEmpty) {
      // Si el año actual no está, seleccionamos el primer año disponible
      final sortedYears = availableYears.toList()..sort();
      selectedYear = sortedYears.first;
      // Tomamos el primer mes disponible de ese año
      final firstYearMonths = yearToMonths[selectedYear]!;
      selectedMonth = firstYearMonths.first;
    } else {
      // Si no hay datos, no hacemos nada especial
      // (filteredData quedará vacío)
    }
  }

  /// Actualiza `filteredData` según el modo (mensual/anual) y “Ingresos/Gastos”.
  void _updateData() {
    // Primero filtramos por año y (opcionalmente) mes
    List<Add_data> baseData;
    if (isMonthly) {
      // Modo Mensual: filtrar por año y mes
      baseData = allData.where((item) {
        return item.datetime.year == selectedYear &&
            item.datetime.month == selectedMonth;
      }).toList();
    } else {
      // Modo Anual: filtrar por año
      baseData = allData.where((item) {
        return item.datetime.year == selectedYear;
      }).toList();
    }

    // Luego filtramos por Ingresos/Gastos
    if (isIncomeSelected) {
      filteredData = baseData.where((item) => item.IN == 'Income').toList();
    } else {
      filteredData = baseData.where((item) => item.IN == 'Expenses').toList();
    }

    setState(() {});
  }

  // Puedes usar los que quieras, aquí hay un ejemplo
  final List<Color> colorPalette = [
    Color(0xFF4CAF50), // Verde
    Color(0xFFFF9800), // Naranja
    Color(0xFF2196F3), // Azul
    Color(0xFFE91E63), // Rosa
    Color(0xFF9C27B0), // Morado
    Color(0xFFFFC107), // Ámbar
    Color(0xFF00BCD4), // Cian
    Color(0xFF8BC34A), // Verde claro
    Color(0xFFFF5722), // Naranja oscuro
    Color(0xFF795548), // Café
    Color(0xFF673AB7), // Púrpura
    Color(0xFF3F51B5), // Índigo
    Color(0xFF009688), // Verde azulado
    Color(0xFFCDDC39), // Lima
    Color(0xFFFFEB3B), // Amarillo
    Color(0xFFFF4081), // Rosa fuerte
    Color(0xFF607D8B), // Azul grisáceo
    Color(0xFF8E24AA), // Púrpura oscuro
    Color(0xFF5E35B1), // Índigo oscuro
    Color(0xFF3949AB), // Azul oscuro
    Color(0xFF1E88E5), // Azul claro
    Color(0xFF039BE5), // Azul celeste
    Color(0xFF00ACC1), // Cian oscuro
    Color(0xFF00897B), // Verde azulado oscuro
    Color(0xFF43A047), // Verde oscuro
    Color(0xFF7CB342), // Lima oscuro
    Color(0xFFC0CA33), // Lima claro
    Color(0xFFFDD835), // Amarillo oscuro
    Color(0xFFFFB300), // Ámbar oscuro
    Color(0xFFFB8C00), // Naranja claro
    Color(0xFFF4511E), // Naranja fuerte
    Color(0xFF6D4C41), // Marrón
    Color(0xFF757575), // Gris
    Color(0xFF546E7A), // Azul grisáceo oscuro
    Color(0xFFEF5350), // Rojo claro
    Color(0xFFAB47BC), // Púrpura claro
    Color(0xFF26A69A), // Verde azulado claro
    Color(0xFF42A5F5), // Azul claro
    Color(0xFF7E57C2), // Púrpura medio
    Color(0xFF66BB6A), // Verde medio
  ];

  // ===================== LÓGICA PARA CONSTRUIR GRÁFICOS =====================
  /// Gráfico de dona “por categoría”
  List<ChartData> _getCategoryData() {
    final Map<String, Map<String, dynamic>> map = {};

    for (var item in filteredData) {
      double amount = double.tryParse(item.amount) ?? 0;
      final category = item.explain.isEmpty ? 'Sin categoría' : item.explain;

      if (!map.containsKey(category)) {
        // DEBUGGING: Imprimir el iconCode encontrado
        print("Nueva categoría: $category con iconCode: ${item.iconCode}");

        map[category] = {
          'amount': amount,
          'iconCode': item.iconCode > 0
              ? item.iconCode
              : _getDefaultIconCodeForCategory(category)
        };
      } else {
        map[category]!['amount'] += amount;
        // Mantener un iconCode válido si ya existe uno
        if (item.iconCode > 0 && map[category]!['iconCode'] == 0) {
          print("Actualizando iconCode para $category a: ${item.iconCode}");
          map[category]!['iconCode'] = item.iconCode;
        }
      }
    }

    final List<ChartData> list = [];
    int colorIndex = 0;

    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value['amount'].compareTo(a.value['amount']));

    for (var entry in sortedEntries) {
      final color = colorPalette[colorIndex % colorPalette.length];
      colorIndex++;
      list.add(ChartData(entry.key, entry.value['amount'], color,
          entry.value['iconCode'] // Pasamos el iconCode al ChartData
          ));
    }

    return list;
  }

  List<ChartData> _getAccountData() {
    final Map<String, Map<String, dynamic>> map = {};

    for (var item in filteredData) {
      double amount = double.tryParse(item.amount) ?? 0;
      final cuenta = item.name.isEmpty ? 'Sin cuenta' : item.name;

      // Buscar iconCode basado en el nombre de la cuenta
      IconData accountIconData = _getAccountIcon(cuenta);
      int iconCode = accountIconData.codePoint;

      if (!map.containsKey(cuenta)) {
        map[cuenta] = {'amount': amount, 'iconCode': iconCode};
      } else {
        map[cuenta]!['amount'] += amount;
      }
    }

    final List<ChartData> list = [];
    int colorIndex = 0;

    final sortedEntries = map.entries.toList()
      ..sort((a, b) => b.value['amount'].compareTo(a.value['amount']));

    for (var entry in sortedEntries) {
      final color = colorPalette[colorIndex % colorPalette.length];
      colorIndex++;
      list.add(ChartData(entry.key, entry.value['amount'], color,
          entry.value['iconCode'] // Incluir el iconCode en ChartData
          ));
    }

    return list;
  }

// Añade este método a la clase _StatisticsState
  IconData _getAccountIcon(String accountName) {
    // Buscar en la lista de cuentas por nombre
    for (var account in _accountsList) {
      if (account.title.toLowerCase() == accountName.toLowerCase()) {
        return account.icon ?? Icons.account_balance_wallet;
      }
    }

    // Iconos por defecto según el tipo de cuenta
    if (accountName.toLowerCase().contains('efectivo') ||
        accountName.toLowerCase().contains('cash')) {
      return Icons.money;
    } else if (accountName.toLowerCase().contains('banco') ||
        accountName.toLowerCase().contains('bank')) {
      return Icons.account_balance;
    } else if (accountName.toLowerCase().contains('tarjeta') ||
        accountName.toLowerCase().contains('card')) {
      return Icons.credit_card;
    }

    // Icono por defecto
    return Icons.account_balance_wallet;
  }

// Mejora del método para obtener el iconCode para categorías usando la lista existente
  int _getDefaultIconCodeForCategory(String category) {
    final normalizedCategory = category.toLowerCase();

    // 1. Buscar en la lista predefinida de iconos
    // Los iconos tienen nombres descriptivos como "shopping_cart", "restaurant", etc.
    for (int i = 0; i < categoryIcons.length; i++) {
      // Extraer el nombre del icono (la parte después del punto)
      String iconName =
          categoryIcons[i].toString().split('.').last.toLowerCase();

      // Buscar coincidencias entre el nombre de la categoría y el nombre del icono
      if (normalizedCategory.contains(iconName) ||
          iconName.contains(normalizedCategory)) {
        print(
            "Coincidencia encontrada: '$normalizedCategory' con icono '$iconName'");
        return categoryIcons[i].codePoint;
      }
    }

    // 2. Si no hay coincidencia, elegir un icono apropiado de la lista
    // Usar índices específicos para categorías comunes
    if (normalizedCategory.contains('salario') ||
        normalizedCategory.contains('ingreso') ||
        normalizedCategory.contains('sueldo')) {
      // Índice de un icono apropiado para ingresos
      return categoryIcons[10].codePoint; // Por ejemplo: work o money
    } else if (normalizedCategory.contains('comida') ||
        normalizedCategory.contains('restaurante')) {
      return categoryIcons[3].codePoint; // restaurant
    }

    // 3. Si todo lo demás falla, usar el primer icono según el tipo
    int defaultIndex =
        isIncomeSelected ? 4 : 0; // Índice diferente para ingresos/gastos
    return categoryIcons[defaultIndex].codePoint;
  }

  /// Gráfico de barras por mes (cuando isMonthly=false)
  /// Muestra la distribución de todos los meses del año seleccionado
  /// (filtrando además por Ingresos/Gastos).
  List<ChartData> _getMonthDataForYear() {
    final Map<int, Map<String, dynamic>> map = {};

    for (var item in filteredData) {
      final mes = item.datetime.month;
      final amount = double.tryParse(item.amount) ?? 0;

      if (!map.containsKey(mes)) {
        map[mes] = {
          'amount': amount,
          // Asignar icono de calendario para representar meses
          'iconCode': Icons.calendar_month.codePoint
        };
      } else {
        map[mes]!['amount'] += amount;
      }
    }

    final List<ChartData> list = [];
    int colorIndex = 0;

    // Ordenar los meses cronológicamente
    final sortedMonths = map.keys.toList()..sort();

    for (var mes in sortedMonths) {
      final label = '${_nombreMes(mes)} $selectedYear';
      final color = colorPalette[colorIndex % colorPalette.length];
      colorIndex++;
      list.add(ChartData(label, map[mes]!['amount'], color,
          map[mes]!['iconCode'] // Incluir el iconCode en ChartData
          ));
    }

    return list;
  }

// Opcionalmente: mantén la otra función para el resto de la interfaz si la necesitas
  String _formatNumberCompact(double value) {
    if (value >= 1000000) {
      final millones = value / 1000000;
      return '${millones.toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      final miles = value / 1000;
      return '${miles.toStringAsFixed(1)}K';
    } else {
      return NumberFormat('#,##0').format(value);
    }
  }

  /// Devuelve una lista agrupada de ingresos, ya sea por semanas (modo mensual)
  /// o por meses (modo anual).
  List<ChartData> _getIncomeGrouped() {
    // Solo tomamos ingresos
    final data = allData.where((t) => t.IN == 'Income').toList();

    if (isMonthly) {
      // Modo mensual: agrupar por semanas
      final currentData = data.where(
        (t) =>
            t.datetime.year == selectedYear &&
            t.datetime.month == selectedMonth,
      );

      // Agrupamos por semana del mes
      final Map<int, Map<String, dynamic>> weeklyMap = {};
      for (var item in currentData) {
        final amount = double.tryParse(item.amount) ?? 0;
        final weekNum = _getWeekOfMonth(item.datetime);

        if (!weeklyMap.containsKey(weekNum)) {
          weeklyMap[weekNum] = {
            'amount': amount,
            // Icono para representar semanas
            'iconCode': Icons.date_range.codePoint
          };
        } else {
          weeklyMap[weekNum]!['amount'] += amount;
        }
      }

      // Construir la lista ordenada por número de semana
      final List<ChartData> weeklyList = [];
      final sortedWeeks = weeklyMap.keys.toList()..sort();

      for (var week in sortedWeeks) {
        weeklyList.add(ChartData(
            'Semana $week',
            weeklyMap[week]!['amount'],
            Colors.greenAccent, // Agregamos el color como tercer parámetro
            weeklyMap[week]!['iconCode'] // Y el iconCode como cuarto parámetro
            ));
      }
      return weeklyList;
    } else {
      // Modo anual: agrupar por meses
      final currentData = data.where((t) => t.datetime.year == selectedYear);

      final Map<int, Map<String, dynamic>> monthlyMap = {};
      for (var item in currentData) {
        final amount = double.tryParse(item.amount) ?? 0;
        final month = item.datetime.month;

        if (!monthlyMap.containsKey(month)) {
          monthlyMap[month] = {
            'amount': amount,
            // Icono para representar meses
            'iconCode': Icons.calendar_month.codePoint
          };
        } else {
          monthlyMap[month]!['amount'] += amount;
        }
      }

      // Construir la lista ordenada por mes
      final List<ChartData> monthlyList = [];
      final sortedMonths = monthlyMap.keys.toList()..sort();

      for (var mes in sortedMonths) {
        monthlyList.add(ChartData(
            _nombreMesCompleto(mes),
            monthlyMap[mes]!['amount'],
            Colors.greenAccent, // Agregamos el color como tercer parámetro
            monthlyMap[mes]!['iconCode'] // Y el iconCode como cuarto parámetro
            ));
      }
      return monthlyList;
    }
  }

  /// Devuelve una lista agrupada de gastos, ya sea por semanas (modo mensual)
  /// o por meses (modo anual).
  List<ChartData> _getExpensesGrouped() {
    // Solo tomamos gastos
    final data = allData.where((t) => t.IN == 'Expenses').toList();

    if (isMonthly) {
      // Modo mensual: agrupar por semanas
      final currentData = data.where(
        (t) =>
            t.datetime.year == selectedYear &&
            t.datetime.month == selectedMonth,
      );

      // Agrupamos por semana del mes
      final Map<int, Map<String, dynamic>> weeklyMap = {};
      for (var item in currentData) {
        final amount = double.tryParse(item.amount) ?? 0;
        final weekNum = _getWeekOfMonth(item.datetime);

        if (!weeklyMap.containsKey(weekNum)) {
          weeklyMap[weekNum] = {
            'amount': amount,
            // Icono para representar semanas
            'iconCode': Icons.date_range.codePoint
          };
        } else {
          weeklyMap[weekNum]!['amount'] += amount;
        }
      }

      // Construir la lista ordenada por número de semana
      final List<ChartData> weeklyList = [];
      final sortedWeeks = weeklyMap.keys.toList()..sort();

      for (var week in sortedWeeks) {
        weeklyList.add(ChartData(
            'Semana $week',
            weeklyMap[week]!['amount'],
            Colors.redAccent, // Color rojo para gastos
            weeklyMap[week]!['iconCode']));
      }
      return weeklyList;
    } else {
      // Modo anual: agrupar por meses
      final currentData = data.where((t) => t.datetime.year == selectedYear);

      final Map<int, Map<String, dynamic>> monthlyMap = {};
      for (var item in currentData) {
        final amount = double.tryParse(item.amount) ?? 0;
        final month = item.datetime.month;

        if (!monthlyMap.containsKey(month)) {
          monthlyMap[month] = {
            'amount': amount,
            // Icono para representar meses
            'iconCode': Icons.calendar_month.codePoint
          };
        } else {
          monthlyMap[month]!['amount'] += amount;
        }
      }

      // Construir la lista ordenada por mes
      final List<ChartData> monthlyList = [];
      final sortedMonths = monthlyMap.keys.toList()..sort();

      for (var mes in sortedMonths) {
        monthlyList.add(ChartData(
            _nombreMesCompleto(mes),
            monthlyMap[mes]!['amount'],
            Colors.redAccent, // Color rojo para gastos
            monthlyMap[mes]!['iconCode']));
      }
      return monthlyList;
    }
  }

  /// Calcula la semana del mes en una fecha dada (1, 2, 3, 4 o 5).
  int _getWeekOfMonth(DateTime date) {
    final firstDayOfMonth = DateTime(date.year, date.month, 1);
    final dayOffset = firstDayOfMonth.weekday - 1; // Para ajustar L-D
    return ((date.day + dayOffset) / 7).ceil();
  }

  /// Nombre de mes completo
  String _nombreMesCompleto(int mes) {
    switch (mes) {
      case 1:
        return 'Enero';
      case 2:
        return 'Febrero';
      case 3:
        return 'Marzo';
      case 4:
        return 'Abril';
      case 5:
        return 'Mayo';
      case 6:
        return 'Junio';
      case 7:
        return 'Julio';
      case 8:
        return 'Agosto';
      case 9:
        return 'Septiembre';
      case 10:
        return 'Octubre';
      case 11:
        return 'Noviembre';
      case 12:
        return 'Diciembre';
      default:
        return '';
    }
  }

  /// Helper para nombre de mes abreviado en español
  String _nombreMes(int mes) {
    switch (mes) {
      case 1:
        return 'Ene.';
      case 2:
        return 'Feb.';
      case 3:
        return 'Mar.';
      case 4:
        return 'Abr.';
      case 5:
        return 'May.';
      case 6:
        return 'Jun.';
      case 7:
        return 'Jul.';
      case 8:
        return 'Ago.';
      case 9:
        return 'Sep.';
      case 10:
        return 'Oct.';
      case 11:
        return 'Nov.';
      case 12:
        return 'Dic.';
      default:
        return '';
    }
  }

  /// Formato para números con separadores de miles
  String _formatNumber(double value) {
    // Utiliza siempre el formato con separadores de miles, sin abreviar
    return NumberFormat('#,##0').format(value);
  }

// Añade este método a la clase _StatisticsState
  String _formatCurrencyCompact(double value) {
    if (value >= 1000000) {
      final millones = value / 1000000;
      return '\$${millones.toStringAsFixed(1)}M';
    } else if (value >= 1000) {
      final miles = value / 1000;
      return '\$${miles.toStringAsFixed(1)}K';
    } else {
      return '\$${NumberFormat('#,##0').format(value)}';
    }
  }

// Método para obtener datos históricos (diario o mensual según el modo)
  List<ChartData> _getHistoricalData() {
    if (isMonthly) {
      // Modo mensual: datos por día para el mes seleccionado
      return _getDailyDataForMonth();
    } else {
      // Modo anual: datos por mes para el año seleccionado
      return _getMonthDataForYearHistorical();
    }
  }

// Datos por día para el mes seleccionado
  List<ChartData> _getDailyDataForMonth() {
    // Mapa para agregar valores por día
    Map<int, double> dailyData = {};

    // Filtrar transacciones del tipo correcto (ingresos o gastos)
    final filteredByType = allData
        .where((item) =>
            item.IN == (isIncomeSelected ? 'Income' : 'Expenses') &&
            item.datetime.year == selectedYear &&
            item.datetime.month == selectedMonth)
        .toList();

    // Obtener el último día del mes seleccionado (28, 29, 30 o 31)
    final lastDayOfMonth = DateTime(selectedYear, selectedMonth + 1, 0).day;

    // Inicializar todos los días del mes con valor 0
    for (int day = 1; day <= lastDayOfMonth; day++) {
      dailyData[day] = 0;
    }

    // Sumar los montos para cada día
    for (var item in filteredByType) {
      final day = item.datetime.day;
      final amount = double.tryParse(item.amount) ?? 0;
      dailyData[day] = (dailyData[day] ?? 0) + amount;
    }

    // Convertir a lista de ChartData
    List<ChartData> result = [];
    for (int day = 1; day <= lastDayOfMonth; day++) {
      // Solo incluir días con datos para no sobrecargar el gráfico
      if (dailyData[day]! > 0) {
        result.add(ChartData(
            day.toString(),
            dailyData[day]!,
            isIncomeSelected
                ? const Color(0xFF27AE60)
                : const Color(0xFFE53935),
            isIncomeSelected
                ? Icons.arrow_upward.codePoint
                : Icons.arrow_downward.codePoint));
      }
    }

    return result;
  }

// Datos mensuales para un año (versión para gráfica histórica)
  List<ChartData> _getMonthDataForYearHistorical() {
    // Mapa para agregar valores por mes
    Map<int, double> monthlyData = {};

    // Inicializar todos los meses con valor 0
    for (int month = 1; month <= 12; month++) {
      monthlyData[month] = 0;
    }

    // Filtrar transacciones del tipo correcto (ingresos o gastos)
    final filteredByType = allData
        .where((item) =>
            item.IN == (isIncomeSelected ? 'Income' : 'Expenses') &&
            item.datetime.year == selectedYear)
        .toList();

    // Sumar los montos para cada mes
    for (var item in filteredByType) {
      final month = item.datetime.month;
      final amount = double.tryParse(item.amount) ?? 0;
      monthlyData[month] = (monthlyData[month] ?? 0) + amount;
    }

    // Convertir a lista de ChartData
    List<ChartData> result = [];
    for (int month = 1; month <= 12; month++) {
      // Solo incluir meses con datos para no sobrecargar el gráfico
      if (monthlyData[month]! > 0) {
        result.add(ChartData(
            _nombreMesCompleto(month),
            monthlyData[month]!,
            isIncomeSelected
                ? const Color(0xFF27AE60)
                : const Color(0xFFE53935),
            isIncomeSelected
                ? Icons.arrow_upward.codePoint
                : Icons.arrow_downward.codePoint));
      }
    }

    return result;
  }

// Widget para mostrar la gráfica histórica
  Widget _buildHistoricalChart() {
    final data = _getHistoricalData();

    if (data.isEmpty) {
      return _buildEmptyDataIndicator(
          'No hay datos históricos disponibles para este período');
    }

    // Título descriptivo según el modo
    final String title = isMonthly
        ? 'Evolución diaria de ${isIncomeSelected ? 'ingresos' : 'gastos'} en ${_nombreMesCompleto(selectedMonth)}'
        : 'Evolución mensual de ${isIncomeSelected ? 'ingresos' : 'gastos'} en $selectedYear';

    // Color principal según tipo (ingreso/gasto)
    final Color primaryColor =
        isIncomeSelected ? const Color(0xFF27AE60) : const Color(0xFFE53935);

    // Encontrar valores máximos y mínimos para destacarlos
    final maxEntry = data.reduce((a, b) => a.y > b.y ? a : b);

    // Solo considerar valores mayores que cero para el mínimo
    final nonZeroData = data.where((item) => item.y > 0).toList();
    final minEntry = nonZeroData.isEmpty
        ? data.first
        : nonZeroData.reduce((a, b) => a.y < b.y ? a : b);

    // Calcular promedio para la línea de referencia
    final double avgValue =
        data.fold(0.0, (sum, item) => sum + item.y) / data.length;

    // Determinar unidad de tiempo para mejor contexto
    final String timeUnit = isMonthly ? 'día' : 'mes';

    // Período seleccionado actualmente (para mostrar detalles)
    String _selectedPeriod = '';

    return Container(
      height: 550, // Altura aumentada para gráfica más detallada
      padding: const EdgeInsets.only(top: 16, right: 0, left: 0, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado con título y descripción
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título con icono y tooltip de ayuda
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    Tooltip(
                      message: 'Toca en cualquier punto para ver detalles',
                      textStyle:
                          const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.help_outline,
                        color: Colors.white.withOpacity(0.6),
                        size: 20,
                      ),
                    ),
                  ],
                ),

                // Descripción con contexto
                Padding(
                  padding: const EdgeInsets.only(left: 2, top: 6, right: 10),
                  child: Text(
                    'Visualiza patrones de ${isIncomeSelected ? 'ingresos' : 'gastos'} por ${timeUnit} y detecta tendencias',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                // Nota sobre interactividad
                if (_selectedPeriod.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, top: 6, right: 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.touch_app,
                          color: primaryColor.withOpacity(0.7),
                          size: 14,
                        ),
                        const SizedBox(width: 0),
                        Text(
                          'Toca un punto para ver detalles de ese ${timeUnit}',
                          style: TextStyle(
                            color: primaryColor.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Contenedor principal del gráfico con borde y sombras
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    // Fondo degradado sutilmente animado para dar profundidad
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(seconds: 20),
                        builder: (context, value, child) {
                          return CustomPaint(
                            painter: BackgroundGradientPainter(
                              color: primaryColor,
                              progress: value,
                            ),
                          );
                        },
                      ),
                    ),

                    // Gráfico principal
                    SfCartesianChart(
                      backgroundColor: Colors.transparent,
                      plotAreaBorderWidth: 0,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 16),

                      // Ejes X e Y con diseño profesional
                      primaryXAxis: CategoryAxis(
                        labelStyle: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        axisLine:
                            const AxisLine(width: 0.7, color: Colors.white24),
                        majorGridLines: const MajorGridLines(width: 0),
                        majorTickLines: const MajorTickLines(
                            size: 4, color: Colors.white24),
                        labelPlacement: LabelPlacement.onTicks,
                        labelRotation:
                            isMonthly ? 0 : -30, // Rotación según el modo
                        labelAlignment: LabelAlignment.center,
                        labelIntersectAction: AxisLabelIntersectAction.wrap,
                        maximumLabels: isMonthly ? 10 : 12,
                        interval:
                            isMonthly ? (data.length > 15 ? 5 : null) : null,
                        edgeLabelPlacement: EdgeLabelPlacement.shift,
                      ),
                      primaryYAxis: NumericAxis(
                        labelStyle: const TextStyle(
                            color: Colors.white54, fontSize: 11),
                        axisLine: const AxisLine(width: 0),
                        majorGridLines: const MajorGridLines(
                          width: 0.6,
                          color: Colors.white10,
                          dashArray: <double>[3, 3],
                        ),
                        majorTickLines: const MajorTickLines(
                            size: 4, color: Colors.white24),
                        minorTicksPerInterval: 1,
                        numberFormat: NumberFormat.compact(),
                        labelFormat: '\${value}',
                        decimalPlaces: 0,
                        rangePadding: ChartRangePadding.additional,
                      ),

                      // Tooltip avanzado con detalles y botón de acción
                      tooltipBehavior: TooltipBehavior(
                        enable: true,
                        color: const Color(0xFF2A3143),
                        textStyle: const TextStyle(color: Colors.white),
                        borderColor: Colors.white24,
                        borderWidth: 1,
                        duration: 4000,
                        canShowMarker: true,
                        builder:
                            (data, point, series, pointIndex, seriesIndex) {
                          final item = data as ChartData;
                          _selectedPeriod =
                              item.x; // Guardar el período seleccionado

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2A3143),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.4),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ],
                              border:
                                  Border.all(color: Colors.white10, width: 1),
                            ),
                            width: 160,
                            height: 160,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Encabezado
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isMonthly
                                          ? '$timeUnit ${item.x}'
                                          : item.x,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isMonthly ? '$selectedYear' : 'Total',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(
                                  color: Colors.white24,
                                  height: 16,
                                ),

                                // Detalle principal
                                Row(
                                  children: [
                                    Container(
                                      height: 12,
                                      width: 12,
                                      decoration: BoxDecoration(
                                        color: primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white70, width: 1),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isIncomeSelected ? 'Ingreso:' : 'Gasto:',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '\$${_formatNumber(item.y)}',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Información contextual
                                Text(
                                  item.y > avgValue
                                      ? 'Por encima del promedio (+${((item.y / avgValue - 1) * 100).toStringAsFixed(0)}%)'
                                      : 'Por debajo del promedio (${((item.y / avgValue - 1) * 100).toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    color: item.y > avgValue
                                        ? Colors.green[200]
                                        : Colors.orange[200],
                                    fontSize: 11,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),

                                const Spacer(),
                              ],
                            ),
                          );
                        },
                      ),

                      // Series de gráficas mejoradas
                      series: <CartesianSeries<ChartData, String>>[
                        // Área sombreada para fondo con gradiente degradado
                        AreaSeries<ChartData, String>(
                          dataSource: data,
                          xValueMapper: (ChartData item, _) => item.x,
                          yValueMapper: (ChartData item, _) => item.y,
                          name: isIncomeSelected
                              ? 'Área de Ingresos'
                              : 'Área de Gastos',
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.1, 0.3, 0.9],
                            colors: [
                              primaryColor.withOpacity(0.5),
                              primaryColor.withOpacity(0.2),
                              primaryColor.withOpacity(0.05),
                            ],
                          ),
                          borderColor: primaryColor.withOpacity(0.9),
                          borderWidth: 2,
                          animationDuration: 1500,
                          animationDelay: 500,
                          enableTooltip: false,
                          borderDrawMode: BorderDrawMode.top,
                        ),

                        // Línea promedio con estilo punteado
                        LineSeries<ChartData, String>(
                          dataSource: [
                            ChartData(data.first.x, avgValue, Colors.white70,
                                Icons.bar_chart.codePoint),
                            ChartData(data.last.x, avgValue, Colors.white70,
                                Icons.bar_chart.codePoint),
                          ],
                          xValueMapper: (ChartData item, _) => item.x,
                          yValueMapper: (ChartData item, _) => item.y,
                          color: Colors.white70,
                          width: 1.5,
                          dashArray: const <double>[3, 3],
                          markerSettings:
                              const MarkerSettings(isVisible: false),
                          animationDuration: 500,
                          enableTooltip: false,
                          name: 'Promedio',
                          legendItemText: 'Promedio',
                        ),

                        // Línea principal con efecto de sombra y marcadores elegantes
                        LineSeries<ChartData, String>(
                          dataSource: data,
                          xValueMapper: (ChartData item, _) => item.x,
                          yValueMapper: (ChartData item, _) => item.y,
                          name: isIncomeSelected ? 'Ingresos' : 'Gastos',
                          color: primaryColor,
                          width: 3.5,
                          opacity: 0.95,
                          markerSettings: MarkerSettings(
                            isVisible: true,
                            height: 10,
                            width: 10,
                            shape: DataMarkerType.circle,
                            borderWidth: 2.5,
                            borderColor: primaryColor,
                            color: Colors.white,
                          ),
                          onPointTap: (ChartPointDetails details) {
                            // Acción alternativa al tocar un punto si es necesario
                          },
                          emptyPointSettings: EmptyPointSettings(
                            mode: EmptyPointMode.zero,
                            color: Colors.grey.withOpacity(0.3),
                          ),
                          animationDuration: 1800,
                          animationDelay: 800,
                          enableTooltip: true,
                        ),
                      ],

                      // Leyenda mejorada
                      legend: Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        alignment: ChartAlignment.center,
                        itemPadding: 12,
                        padding: 5,
                        backgroundColor: Colors.transparent,
                        legendItemBuilder: (String name, dynamic series,
                            dynamic point, int index) {
                          // Color diferente según la serie
                          Color itemColor = primaryColor;
                          if (name == 'Promedio') {
                            itemColor = Colors.white70;
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: itemColor.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: itemColor,
                                    shape: name == 'Promedio'
                                        ? BoxShape.rectangle
                                        : BoxShape.circle,
                                    borderRadius: name == 'Promedio'
                                        ? BorderRadius.circular(2)
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.9),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Zoom y desplazamiento mejorados
                      zoomPanBehavior: ZoomPanBehavior(
                        enablePanning: true,
                        zoomMode: ZoomMode.xy,
                        enablePinching: true,
                        enableDoubleTapZooming: true,
                        enableMouseWheelZooming: true,
                        enableSelectionZooming: true,
                        selectionRectBorderColor: primaryColor.withOpacity(0.8),
                        selectionRectBorderWidth: 1,
                        selectionRectColor: primaryColor.withOpacity(0.1),
                      ),

                      // Crosshairs para mejor precisión
                      crosshairBehavior: CrosshairBehavior(
                        enable: true,
                        activationMode: ActivationMode.singleTap,
                        lineType: CrosshairLineType.vertical,
                        lineDashArray: <double>[5, 5],
                        lineWidth: 1,
                        lineColor: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tarjeta de estadísticas con efecto de cristal
          Container(
            margin: const EdgeInsets.only(top: 0, left: 0, right: 0, bottom: 0),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: _buildHistoricalStats(data),
          ),
        ],
      ),
    );
  }

// Widget para mostrar estadísticas rápidas del histórico
  Widget _buildHistoricalStats(List<ChartData> data) {
    if (data.isEmpty) return const SizedBox.shrink();

    // Calcular estadísticas
    double total = 0;
    double average = 0;
    double max = 0;
    double min = double.infinity;
    String maxDate = '';
    String minDate = '';

    for (var item in data) {
      total += item.y;
      if (item.y > max) {
        max = item.y;
        maxDate = item.x;
      }
      if (item.y > 0 && item.y < min) {
        min = item.y;
        minDate = item.x;
      }
    }

    average = total / data.length;
    if (min == double.infinity) min = 0;

    // Color según tipo
    final Color statColor =
        isIncomeSelected ? const Color(0xFF27AE60) : const Color(0xFFE53935);

    // Formato compacto para fechas largas
    String formatDate(String date) {
      if (date.length > 6) {
        return date.substring(0, 6) + '...';
      }
      return date;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 0, left: 0, right: 0),
      // Añadir SingleChildScrollView para permitir scroll horizontal
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            children: [
              // Estadística: Promedio
              _buildStatCard(
                icon: Icons.timeline,
                label: 'Promedio',
                value: _formatCurrencyCompact(average),
                color: statColor,
              ),
              const SizedBox(width: 12),

              // Estadística: Mínimo y cuándo
              _buildStatCard(
                icon: Icons.arrow_circle_down,
                label: 'Mín: ${formatDate(minDate)}',
                value: _formatCurrencyCompact(min),
                color: statColor,
              ),
              const SizedBox(width: 12),

              // Estadística: Máximo y cuándo
              _buildStatCard(
                icon: Icons.arrow_circle_up,
                label: 'Máx: ${formatDate(maxDate)}',
                value: _formatCurrencyCompact(max),
                color: statColor,
              ),
              const SizedBox(width: 12),
              
              // Nueva tarjeta para Total
              _buildStatCard(
                icon: Icons.account_balance_wallet,
                label: 'Total',
                value: _formatCurrencyCompact(total),
                color: statColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

// Widget para tarjetas de estadísticas - versión mejorada
  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primera fila: icono y etiqueta juntos para ahorrar espacio vertical
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: color,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Valor con estilo destacado
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = filteredData.fold<double>(
      0,
      (sum, item) => sum + (double.tryParse(item.amount) ?? 0),
    );

    // Título “Ene. 2025” o “Año 2025” según el modo
    final String titleDate = isMonthly
        ? '${_nombreMes(selectedMonth)} $selectedYear'
        : 'Año $selectedYear';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 31, 38, 57),
      appBar: AppBar(
        backgroundColor:
            const Color.fromRGBO(42, 49, 67, 1), // Color actualizado
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 75, // Altura aumentada para acomodar el padding
        title: const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            'Informes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Column(
            children: [
              // FILA SUPERIOR: Toggle Mensual/Anual y Selección de Año
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Toggle: Mensual / Anual
                  ToggleButtons(
                    borderRadius: BorderRadius.circular(10),
                    isSelected: [isMonthly, !isMonthly],
                    onPressed: (index) {
                      isMonthly = (index == 0);
                      _updateData();
                    },
                    color: Colors.white,
                    selectedColor: Colors.white,
                    fillColor: const Color.fromARGB(255, 37, 96, 74),
                    children: const [
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text('Mensual', style: TextStyle(fontSize: 16)),
                      ),
                      Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text('Anual', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),

                  // Selección de Año (usando flechas y sólo años disponibles)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_left, color: Colors.white),
                        onPressed: _selectPreviousYear,
                      ),
                      Text(
                        '$selectedYear',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.arrow_right, color: Colors.white),
                        onPressed: _selectNextYear,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Selector de mes si isMonthly = true
              if (isMonthly) _buildMonthSelector(),

              // Botón para Ingresos/Gastos con aspecto mejorado
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Botón con aspecto mejorado
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            spreadRadius: -2,
                          ),
                        ],
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.1),
                            Colors.white.withOpacity(0.05),
                          ],
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            isIncomeSelected = !isIncomeSelected;
                            _updateData();
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isIncomeSelected
                                      ? Icons.arrow_upward
                                      : Icons.arrow_downward,
                                  color: isIncomeSelected
                                      ? const Color(0xFF27AE60)
                                      : const Color(0xFFE53935),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isIncomeSelected ? 'Ingresos' : 'Gastos',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.swap_vert,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Mostrar el título de la fecha
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    titleDate,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Gráfico de dona por categoría
              _buildCard(
                title:
                    '${isIncomeSelected ? 'Ingresos' : 'Gastos'} por categoría',
                child: _buildDoughnutChart(_getCategoryData(),
                    chartType: 'categoría'),
              ),

              // Gráfico de dona por cuenta
              _buildCard(
                title:
                    '${isIncomeSelected ? 'Ingresos' : 'Gastos'} por cuentas',
                child:
                    _buildDoughnutChart(_getAccountData(), chartType: 'cuenta'),
              ),

              // Gráfico de barras por mes (solo en modo Anual)
              if (!isMonthly)
                _buildCard(
                  title: '${isIncomeSelected ? 'Ingresos' : 'Gastos'} por mes',
                  child: _buildBarChart(_getMonthDataForYear()),
                ),

              // Lista detallada
              _buildDetailCard(),

              // Incluir esta sección antes de la lista detallada
              _buildCard(
                title:
                    'Histórico de ${isIncomeSelected ? 'Ingresos' : 'Gastos'}',
                child: _buildHistoricalChart(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======================= MÉTODOS PARA CAMBIAR DE AÑO =======================
  void _selectPreviousYear() {
    if (availableYears.isEmpty) return;
    // Ordenamos los años disponibles
    final sortedYears = availableYears.toList()..sort();
    // Buscamos la posición del actual
    int currentIndex = sortedYears.indexOf(selectedYear);
    if (currentIndex > 0) {
      // Pasamos al anterior
      currentIndex--;
      selectedYear = sortedYears[currentIndex];

      // Ajustamos el mes si esMonthly
      if (isMonthly) {
        final months = yearToMonths[selectedYear]!;
        // Si el mes actual no existe en el nuevo año, escogemos el primero
        if (!months.contains(selectedMonth)) {
          selectedMonth = months.first;
        }
      }
      _updateData();
    }
  }

  void _selectNextYear() {
    if (availableYears.isEmpty) return;
    final sortedYears = availableYears.toList()..sort();
    int currentIndex = sortedYears.indexOf(selectedYear);
    if (currentIndex < sortedYears.length - 1) {
      currentIndex++;
      selectedYear = sortedYears[currentIndex];
      if (isMonthly) {
        final months = yearToMonths[selectedYear]!;
        if (!months.contains(selectedMonth)) {
          selectedMonth = months.first;
        }
      }
      _updateData();
    }
  }

  // ====================== CONSTRUCCIÓN DEL SELECTOR DE MESES =================
  // Selector de meses mejorado con diseño premium
  Widget _buildMonthSelector() {
    if (availableYears.isEmpty) {
      return const SizedBox();
    }

    // Meses disponibles para el año seleccionado
    final months = yearToMonths[selectedYear]?.toList() ?? [];
    months.sort();

    // Color para el mes seleccionado según el tipo de vista - MEJORADO CONTRASTE
    final accentColor = isIncomeSelected
        ? const Color(0xFF27AE60) // Verde más oscuro (antes era 0xFF2E9E5B)
        : const Color(0xFFE53935); // Rojo para gastos

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Etiqueta descriptiva
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Seleccionar mes',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        // Contenedor principal con borde y efecto de sombra
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: Color.fromRGBO(42, 49, 67, 1).withOpacity(.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                spreadRadius: -5,
              ),
            ],
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: months.length,
            itemBuilder: (context, index) {
              final mes = months[index];
              final selected = (mes == selectedMonth);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      // Efecto háptico para feedback táctil
                      HapticFeedback.lightImpact();
                      setState(() {
                        selectedMonth = mes;
                        _updateData();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    splashColor: accentColor.withOpacity(0.1),
                    highlightColor: accentColor.withOpacity(0.05),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: EdgeInsets.symmetric(
                        horizontal: selected ? 16 : 14,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? accentColor.withOpacity(0.2)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected ? accentColor : Colors.transparent,
                          width: 1.5,
                        ),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: accentColor.withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: -2,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selected) ...[
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _nombreMesCompleto(mes),
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.8),
                              fontWeight: selected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: selected ? 14 : 13.5,
                              letterSpacing: selected ? 0.2 : 0,
                              // Añadir sombra para mejor legibilidad
                              shadows: selected
                                  ? [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        blurRadius: 10,
                                        offset: const Offset(0, 1),
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Espacio después del selector
        const SizedBox(height: 16),
      ],
    );
  }

  // ======================= WIDGETS PARA GRÁFICOS =======================
  Widget _buildCard({required String title, required Widget child}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          // Título
          Row(
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Contenido
          child,
        ],
      ),
    );
  }

  Widget _buildDoughnutChart(List<ChartData> data,
      {String chartType = 'categoría'}) {
    if (data.isEmpty) {
      return _buildEmptyDataIndicator('No hay datos disponibles');
    }

    // Calcular el total para mostrarlo en el centro
    final totalAmount = data.fold<double>(0, (sum, item) => sum + item.y);
    final formattedTotal = _formatCurrencyCompact(totalAmount);

    // Colores para el efecto de gradiente del fondo central
    final Color accentColor = isIncomeSelected
        ? const Color(0xFF27AE60) // Verde más oscuro para mejor contraste
        : const Color(0xFFE53935); // Rojo para gastos

    return Column(
      children: [
        SizedBox(
          height: 250, // Aumentado para mejor visualización
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fondo circular elegante para el centro
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withOpacity(0.15),
                      accentColor.withOpacity(0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7, 1.0],
                    radius: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 15,
                      spreadRadius: -5,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),

              // Borde sutil
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 2,
                  ),
                ),
              ),

              // Gráfico de dona principal con animación
              SfCircularChart(
                backgroundColor: Colors.transparent,
                annotations: [
                  CircularChartAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          formattedTotal,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                series: <CircularSeries>[
                  DoughnutSeries<ChartData, String>(
                    dataSource: data,
                    xValueMapper: (ChartData item, _) => item.x,
                    yValueMapper: (ChartData item, _) => item.y,
                    pointColorMapper: (ChartData item, _) => item.color,
                    dataLabelSettings: const DataLabelSettings(
                      isVisible: false, // Sin etiquetas en el gráfico mismo
                    ),
                    radius: '75%',
                    innerRadius: '79%',
                    enableTooltip: true,
                    animationDuration: 1200, // Animación más suave
                    animationDelay: 600, // Retraso para un efecto más elegante
                    explode:
                        true, // Permite que los segmentos se separen ligeramente al tocarlos
                    explodeOffset: '5%', // Distancia de separación
                    explodeAll: false,
                    explodeGesture: ActivationMode.singleTap,
                    strokeWidth: 1.2,
                    strokeColor: Colors.black12,
                    //sombreado

                    cornerStyle:
                        CornerStyle.bothCurve, // Esquinas con estilo redondeado
                  )
                ],
              ),
            ],
          ),
        ),

        // Pequeña descripción con estilo premium - CORREGIDA
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            "Distribución de ${isIncomeSelected ? 'ingresos' : 'gastos'} por $chartType",
            style: TextStyle(
              color: accentColor,
              fontWeight: FontWeight.w500,
              fontSize: 12.5,
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.center,
          ),
        ),

        const SizedBox(height: 24),

        // Lista detallada de categorías con diseño premium
        _buildCategoryDetailsList(data, totalAmount),
      ],
    );
  }

// Widget mejorado para mostrar mensaje de datos vacíos
  Widget _buildEmptyDataIndicator(String message) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 50,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontWeight: FontWeight.w500,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

// Método mejorado para construir la lista detallada de categorías con diseño premium
  Widget _buildCategoryDetailsList(List<ChartData> data, double totalAmount) {
    return Column(
      children: data.map((item) {
        final percentage = (item.y / totalAmount * 100).toStringAsFixed(1);

        IconData iconData =
            IconData(item.iconCode, fontFamily: 'MaterialIcons');

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          child: Row(
            children: [
              // ICONO con diseño premium
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      item.color,
                      item.color.withAlpha(200),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  iconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre de categoría y valor en la misma fila
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Nombre de categoría
                        Expanded(
                          child: Text(
                            item.x,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              letterSpacing: 0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),

                        // Valor numérico
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '\$${NumberFormat('#,##0').format(item.y)}',
                            style: TextStyle(
                              color: item.color.withOpacity(0.95),
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Barra de progreso y porcentaje
                    Row(
                      children: [
                        // Barra de progreso
                        Expanded(
                          flex: 85,
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Stack(
                              children: [
                                // Barra de progreso con animación
                                TweenAnimationBuilder<double>(
                                  tween: Tween(
                                      begin: 0.0, end: item.y / totalAmount),
                                  duration: const Duration(milliseconds: 800),
                                  curve: Curves.easeOutQuart,
                                  builder: (context, value, child) {
                                    return FractionallySizedBox(
                                      widthFactor: value,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              item.color,
                                              item.color.withOpacity(0.7),
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(3),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  item.color.withOpacity(0.3),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Porcentaje con mejor diseño
                        Container(
                          width: 50,
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '$percentage%',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
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
      }).toList(),
    );
  }

// Mejora del método _buildBarChart para una apariencia más premium
  Widget _buildBarChart(List<ChartData> data) {
    if (data.isEmpty) {
      return _buildEmptyDataIndicator(
          'No hay datos disponibles para este período');
    }

    // Color base según tipo de datos (ingresos o gastos)
    final Color baseColor =
        isIncomeSelected ? const Color(0xFF2E9E5B) : const Color(0xFFE53935);

    return Container(
      height: 240,
      padding: const EdgeInsets.only(top: 10, right: 10, bottom: 20),
      child: SfCartesianChart(
        backgroundColor: Colors.transparent,
        plotAreaBorderWidth: 0,
        margin: const EdgeInsets.all(0),
        borderWidth: 0,

        // Ejes con mejor estilo
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(width: 0),
          majorTickLines: const MajorTickLines(size: 0),
          labelRotation: -15, // Mejor legibilidad
          labelAlignment: LabelAlignment.center,
          labelIntersectAction: AxisLabelIntersectAction.multipleRows,
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
          axisLine: const AxisLine(width: 0),
          majorGridLines: const MajorGridLines(
            width: 0.5,
            color: Colors.white10,
            dashArray: <double>[4, 4],
          ),
          majorTickLines: const MajorTickLines(size: 0),
          numberFormat: NumberFormat.compact(),
          labelFormat: '\${value}',
        ),

        // Añadir tooltip personalizado
        tooltipBehavior: TooltipBehavior(
          enable: true,
          color: const Color(0xFF2A3143),
          textStyle: const TextStyle(color: Colors.white),
          borderColor: Colors.white24,
          borderWidth: 1,
          format: 'point.x: \${point.y}',
        ),

        series: <CartesianSeries>[
          // Barra principal con gradiente y sombras
          ColumnSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (ChartData item, _) => item.x,
            yValueMapper: (ChartData item, _) => item.y,
            pointColorMapper: (ChartData item, _) => item.color,
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              labelAlignment: ChartDataLabelAlignment.top,
              labelPosition: ChartDataLabelPosition.outside,
            ),
            width: 0.6,
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                baseColor.withOpacity(0.7),
                baseColor,
              ],
            ),
            animationDuration: 1200,
            animationDelay: 600,
          ),
        ],

        // Añadir zoom/pan para mejor interactividad
        zoomPanBehavior: ZoomPanBehavior(
          enablePanning: true,
          zoomMode: ZoomMode.x,
          enablePinching: true,
          enableDoubleTapZooming: true,
        ),
      ),
    );
  }

// Mejora de _buildDetailCard para una apariencia más premium
  Widget _buildDetailCard() {
    final List<ChartData> data =
        isIncomeSelected ? _getIncomeGrouped() : _getExpensesGrouped();

    final Color accentColor =
        isIncomeSelected ? const Color(0xFF2E9E5B) : const Color(0xFFE53935);

    if (data.isEmpty) {
      return _buildCard(
        title:
            'Detalle de ${isIncomeSelected ? 'ingresos' : 'gastos'} agrupados',
        child: _buildEmptyDataIndicator(
            'No hay datos para el periodo seleccionado'),
      );
    }

    // Calcular total para mostrar al final
    final totalAmount = data.fold<double>(0, (sum, item) => sum + item.y);

    return _buildCard(
      title: 'Detalle de ${isIncomeSelected ? 'ingresos' : 'gastos'} agrupados',
      child: Column(
        children: [
          // Lista con elementos
          ...data.map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icono con mejor diseño
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.color.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      IconData(item.iconCode, fontFamily: 'MaterialIcons'),
                      color: item.color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Etiqueta con mejor tipografía
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.x,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${(item.y / totalAmount * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Monto con mejor diseño
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: accentColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '\$${_formatNumber(item.y)}',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),

          // Total al final
          Padding(
            padding: const EdgeInsets.only(top: 16, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\$${_formatNumber(totalAmount)}',
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pintor para fondo de gradiente animado
class BackgroundGradientPainter extends CustomPainter {
  final Color color;
  final double progress;

  BackgroundGradientPainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Calcular posición dinámica para el gradiente radial
    final double centerX =
        size.width * (0.2 + 0.6 * math.sin(progress * math.pi * 2));
    final double centerY =
        size.height * (0.3 + 0.4 * math.cos(progress * math.pi));

    // Gradiente principal radial con movimiento sutil
    final Paint gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment(
          2.0 * centerX / size.width - 1.0,
          2.0 * centerY / size.height - 1.0,
        ),
        radius: 1.5,
        colors: [
          color.withOpacity(0.12),
          Colors.black.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    // Gradiente secundario para añadir profundidad
    final Paint secondaryPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [
          Colors.white.withOpacity(0.03),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);

    // Dibujar los gradientes
    canvas.drawRect(rect, gradientPaint);
    canvas.drawRect(rect, secondaryPaint);
  }

  @override
  bool shouldRepaint(BackgroundGradientPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
