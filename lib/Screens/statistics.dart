import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
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

  ChartData(this.x, this.y, [this.color = Colors.teal, this.iconCode = 0]); // Actualizar constructor
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
  // Agrega más si quieres
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
        'iconCode': item.iconCode > 0 ? item.iconCode : _getDefaultIconCodeForCategory(category)
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
    list.add(ChartData(
      entry.key, 
      entry.value['amount'], 
      color,
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
      map[cuenta] = {
        'amount': amount,
        'iconCode': iconCode
      };
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
    list.add(ChartData(
      entry.key, 
      entry.value['amount'], 
      color,
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
    String iconName = categoryIcons[i].toString().split('.').last.toLowerCase();
    
    // Buscar coincidencias entre el nombre de la categoría y el nombre del icono
    if (normalizedCategory.contains(iconName) || iconName.contains(normalizedCategory)) {
      print("Coincidencia encontrada: '$normalizedCategory' con icono '$iconName'");
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
  }
  else if (normalizedCategory.contains('comida') || 
           normalizedCategory.contains('restaurante')) {
    return categoryIcons[3].codePoint; // restaurant
  }
  
  // 3. Si todo lo demás falla, usar el primer icono según el tipo
  int defaultIndex = isIncomeSelected ? 4 : 0; // Índice diferente para ingresos/gastos
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
    list.add(ChartData(
      label, 
      map[mes]!['amount'], 
      color,
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
      (t) => t.datetime.year == selectedYear && t.datetime.month == selectedMonth,
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
      (t) => t.datetime.year == selectedYear && t.datetime.month == selectedMonth,
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
        weeklyMap[week]!['iconCode']
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
        Colors.redAccent, // Color rojo para gastos
        monthlyMap[mes]!['iconCode']
      ));
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
    case 1:  return 'Enero';
    case 2:  return 'Febrero';
    case 3:  return 'Marzo';
    case 4:  return 'Abril';
    case 5:  return 'Mayo';
    case 6:  return 'Junio';
    case 7:  return 'Julio';
    case 8:  return 'Agosto';
    case 9:  return 'Septiembre';
    case 10: return 'Octubre';
    case 11: return 'Noviembre';
    case 12: return 'Diciembre';
    default: return '';
  }
}

/// Helper para nombre de mes abreviado en español
String _nombreMes(int mes) {
  switch (mes) {
    case 1:  return 'Ene.';
    case 2:  return 'Feb.';
    case 3:  return 'Mar.';
    case 4:  return 'Abr.';
    case 5:  return 'May.';
    case 6:  return 'Jun.';
    case 7:  return 'Jul.';
    case 8:  return 'Ago.';
    case 9:  return 'Sep.';
    case 10: return 'Oct.';
    case 11: return 'Nov.';
    case 12: return 'Dic.';
    default: return '';
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

  @override
  Widget build(BuildContext context) {
    final total = filteredData.fold<double>(
      0, (sum, item) => sum + (double.tryParse(item.amount) ?? 0),
    );

    // Título “Ene. 2025” o “Año 2025” según el modo
    final String titleDate = isMonthly
        ? '${_nombreMes(selectedMonth)} $selectedYear'
        : 'Año $selectedYear';

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 31, 38, 57),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1), // Color actualizado
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
                    fillColor: const Color.fromARGB(255, 47, 125, 121),
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        child: Text('Mensual', style: TextStyle(fontSize: 16)),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      IconButton(
                        icon: const Icon(Icons.arrow_right, color: Colors.white),
                        onPressed: _selectNextYear,
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Selector de mes si isMonthly = true
              if (isMonthly)
                _buildMonthSelector(),

              // Botón para Ingresos/Gastos
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      isIncomeSelected = !isIncomeSelected;
                      _updateData();
                    },
                    child: Text(
                      isIncomeSelected ? 'Ingresos' : 'Gastos',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
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
                title: '${isIncomeSelected ? 'Ingresos' : 'Gastos'} por categoría',
                child: _buildDoughnutChart(_getCategoryData()),
              ),

              // Gráfico de dona por cuenta
              _buildCard(
                title: '${isIncomeSelected ? 'Ingresos' : 'Gastos'} por cuentas',
                child: _buildDoughnutChart(_getAccountData()),
              ),

              // Gráfico de barras por mes (solo en modo Anual)
              if (!isMonthly)
                _buildCard(
                  title: '${isIncomeSelected ? 'Ingresos' : 'Gastos'} por mes',
                  child: _buildBarChart(_getMonthDataForYear()),
                ),

              // Lista detallada
              _buildDetailCard(),

              

              // Ejemplo de uso: Mostrar datos de ingresos (agrupados) en una tarjeta
              // _buildIncomeGroupingCard(), // Elimina este método redundante que ya no necesitamos
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
  
  // Color para el mes seleccionado según el tipo de vista
  final accentColor = isIncomeSelected 
      ? const Color(0xFF2E9E5B)  // Verde para ingresos
      : const Color(0xFFE53935);  // Rojo para gastos

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
          color: Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
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
                        color: selected
                            ? accentColor
                            : Colors.transparent,
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
                            color: selected ? accentColor : Colors.white.withOpacity(0.8),
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: selected ? 14 : 13.5,
                            letterSpacing: selected ? 0.2 : 0,
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

  Widget _buildDoughnutChart(List<ChartData> data) {
  if (data.isEmpty) {
    return _buildEmptyDataIndicator('No hay datos disponibles');
  }

  // Calcular el total para mostrarlo en el centro
  final totalAmount = data.fold<double>(0, (sum, item) => sum + item.y);
  final formattedTotal = _formatCurrencyCompact(totalAmount);
  
  // Colores para el efecto de gradiente del fondo central
  final Color accentColor = isIncomeSelected 
      ? const Color(0xFF2E9E5B)  // Verde para ingresos
      : const Color(0xFFE53935);  // Rojo para gastos

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
                  radius: '85%',
                  innerRadius: '65%',
                  enableTooltip: true,
                  animationDuration: 1200, // Animación más suave
                  animationDelay: 600, // Retraso para un efecto más elegante
                  explode: true,  // Permite que los segmentos se separen ligeramente al tocarlos
                  explodeOffset: '3%', // Distancia de separación
                  explodeAll: false,
                  explodeGesture: ActivationMode.singleTap,
                  strokeWidth: 1.2,
                  strokeColor: Colors.black12,
                  cornerStyle: CornerStyle.bothCurve, // Esquinas con estilo redondeado
                )
              ],
            ),
          ],
        ),
      ),
      
      // Pequeña descripción con estilo premium
      Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: accentColor.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          "Distribución de ${isIncomeSelected ? 'ingresos' : 'gastos'} por categoría",
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
      
      IconData iconData = IconData(item.iconCode, fontFamily: 'MaterialIcons');
      
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                tween: Tween(begin: 0.0, end: item.y / totalAmount),
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
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: item.color.withOpacity(0.3),
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
    return _buildEmptyDataIndicator('No hay datos disponibles para este período');
  }

  // Color base según tipo de datos (ingresos o gastos)
  final Color baseColor = isIncomeSelected ? const Color(0xFF2E9E5B) : const Color(0xFFE53935);

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
  final List<ChartData> data = isIncomeSelected
      ? _getIncomeGrouped()
      : _getExpensesGrouped();
      
  final Color accentColor = isIncomeSelected ? const Color(0xFF2E9E5B) : const Color(0xFFE53935);

  if (data.isEmpty) {
    return _buildCard(
      title: 'Detalle de ${isIncomeSelected ? 'ingresos' : 'gastos'} agrupados',
      child: _buildEmptyDataIndicator('No hay datos para el periodo seleccionado'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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