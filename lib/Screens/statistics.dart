import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:hive/hive.dart';

// Importaciones de tu proyecto
import '../data/model/add_date.dart';

// Estructura para gráficos
class ChartData {
  final String x;
  final double y;
  final Color color;
  ChartData(this.x, this.y, [this.color = Colors.teal]);
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

  @override
  void initState() {
    super.initState();
    _loadData();
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
  final Map<String, double> map = {};
  for (var item in filteredData) {
    double amount = double.tryParse(item.amount) ?? 0;
    // Usamos item.explain en lugar de item.name ya que explain contiene la categoría
    final category = item.explain.isEmpty ? 'Sin categoría' : item.explain;
    map[category] = (map[category] ?? 0) + amount;
  }

  final List<ChartData> list = [];
  int colorIndex = 0;

  // Ordenar por monto (de mayor a menor) para una mejor visualización
  final sortedEntries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  for (var entry in sortedEntries) {
    final color = colorPalette[colorIndex % colorPalette.length];
    colorIndex++;
    list.add(ChartData(entry.key, entry.value, color));
  }

  return list;
}



  /// Gráfico de dona “por cuenta” (usando item.explain como “cuenta”)
  List<ChartData> _getAccountData() {
  final Map<String, double> map = {};
  for (var item in filteredData) {
    double amount = double.tryParse(item.amount) ?? 0;
    final cuenta = item.explain.isEmpty ? 'Sin cuenta' : item.explain;
    map[cuenta] = (map[cuenta] ?? 0) + amount;
  }

  final List<ChartData> list = [];
  int colorIndex = 0;

  map.forEach((key, value) {
    final color = colorPalette[colorIndex % colorPalette.length];
    colorIndex++;
    list.add(ChartData(key, value, color));
  });

  return list;
  }


  /// Gráfico de barras por mes (cuando isMonthly=false)
  /// Muestra la distribución de todos los meses del año seleccionado
  /// (filtrando además por Ingresos/Gastos).
  List<ChartData> _getMonthDataForYear() {
  final Map<int, double> map = {};
  for (var item in filteredData) {
    final mes = item.datetime.month;
    final amount = double.tryParse(item.amount) ?? 0;
    map[mes] = (map[mes] ?? 0) + amount;
  }

  final List<ChartData> list = [];
  int colorIndex = 0;

  map.forEach((mes, total) {
    final label = '${_nombreMes(mes)} $selectedYear';
    final color = colorPalette[colorIndex % colorPalette.length];
    colorIndex++;
    list.add(ChartData(label, total, color));
  });

  return list;
  }


  /// Helper para nombre de mes en español
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

  /// Formato para números grandes
  String _formatNumber(double value) {
  // Utiliza siempre el formato con separadores de miles, sin abreviar
  return NumberFormat('#,##0').format(value);
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
    // Filtramos solo el mes y año seleccionados
    final currentData = data.where(
      (t) =>
          t.datetime.year == selectedYear &&
          t.datetime.month == selectedMonth,
    );

    // Agrupamos por semana del mes (Semana 1, 2, 3, etc.)
    final Map<int, double> weeklyMap = {};
    for (var item in currentData) {
      final amount = double.tryParse(item.amount) ?? 0;
      final weekNum = _getWeekOfMonth(item.datetime);
      weeklyMap[weekNum] = (weeklyMap[weekNum] ?? 0) + amount;
    }

    // Construimos la lista ChartData
    final List<ChartData> weeklyList = [];
    weeklyMap.forEach((week, total) {
      weeklyList.add(ChartData('Semana $week', total, Colors.teal));
    });
    return weeklyList;
  } else {
    // Modo anual: agrupamos por mes
    final currentData =
        data.where((t) => t.datetime.year == selectedYear);

    final Map<int, double> monthlyMap = {};
    for (var item in currentData) {
      final amount = double.tryParse(item.amount) ?? 0;
      monthlyMap[item.datetime.month] =
          (monthlyMap[item.datetime.month] ?? 0) + amount;
    }

    final List<ChartData> monthlyList = [];
    monthlyMap.forEach((mes, total) {
      monthlyList.add(ChartData(_nombreMesCompleto(mes), total, Colors.teal));
    });
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
        title: const Text(
          'Informes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.bold,
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

              // Total
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Total: \$${_formatNumber(total)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ejemplo de uso: Mostrar datos de ingresos (agrupados) en una tarjeta
              _buildIncomeGroupingCard(),
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
  Widget _buildMonthSelector() {
    if (availableYears.isEmpty) {
      // No hay datos
      return const SizedBox();
    }
    // Meses disponibles para el año seleccionado
    final months = yearToMonths[selectedYear]?.toList() ?? [];
    months.sort(); // Para mostrarlos en orden ascendente

    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: months.length,
        itemBuilder: (context, index) {
          final mes = months[index];
          final selected = (mes == selectedMonth);
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedMonth = mes;
                _updateData();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: selected
                    ? const Color.fromARGB(255, 47, 125, 121)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                _nombreMes(mes),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
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
    return const SizedBox(
      height: 150,
      child: Center(
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  // Calcular el total para mostrarlo en el centro
  final totalAmount = data.fold<double>(0, (sum, item) => sum + item.y);
  final formattedTotal = _formatCurrencyCompact(totalAmount);

  return Column(
    children: [
      SizedBox(
        height: 220, // Aumentado para mejor visualización
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fondo circular sutil para el centro
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.03),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
            ),
            
            // Gráfico de dona principal
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
                          fontSize: 24, // Aumentado
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Text(
                        'TOTAL',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          letterSpacing: 1.0,
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
                  radius: '85%', // Ligeramente mayor
                  innerRadius: '65%', // Ligeramente mayor
                  enableTooltip: true, // Habilitar tooltips
                  strokeWidth: 1.5, // Borde sutil entre secciones
                  strokeColor: Colors.black12, // Color del borde
                )
              ],
            ),
          ],
        ),
      ),
      
      // Pequeña descripción o subtítulo
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          "Distribución de ${isIncomeSelected ? 'ingresos' : 'gastos'} por categoría",
          style: TextStyle(
            color: Colors.white.withOpacity(0.7),
            fontStyle: FontStyle.italic,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      
      const SizedBox(height: 20),
      
      // Lista detallada de categorías
      _buildCategoryDetailsList(data, totalAmount),
    ],
  );
}

// Nuevo método para formatear cantidades de manera compacta con símbolo de moneda
String _formatCurrencyCompact(double amount) {
  if (amount >= 1000000) {
    return '\$${(amount / 1000000).toStringAsFixed(1)}M';
  } else if (amount >= 1000) {
    return '\$${(amount / 1000).toStringAsFixed(1)}K';
  } else {
    return '\$${amount.toStringAsFixed(0)}';
  }
}

// Método mejorado para construir la lista detallada de categorías con diseño premium y elegante
Widget _buildCategoryDetailsList(List<ChartData> data, double totalAmount) {
  return Column(
    children: data.map((item) {
      final percentage = (item.y / totalAmount * 100).toStringAsFixed(1);
      final iconData = _getCategoryIcon(item.x);
      
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: [
            // ICONO con tamaño aumentado y mejor diseño
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: item.color.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                iconData,
                color: item.color,
                size: 22,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // CONTENIDO PRINCIPAL (nombre, barra y valores)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre de categoría y valor en la misma fila
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Nombre de categoría con mayor tamaño y en negrita
                      Expanded(
                        child: Text(
                          item.x,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      
                      // Valor numérico
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '\$${NumberFormat('#,##0').format(item.y)}',  // Esto garantiza que NUNCA se comprima
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Barra de progreso y porcentaje
                  Row(
                    children: [
                      // Barra de progreso reducida en grosor (60% menos)
                      Expanded(
                        flex: 85,
                        child: Container(
                          height: 6, // Reducido en 60% (de 16px a 6px)
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                widthFactor: item.y / totalAmount,
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
                                        blurRadius: 2,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Porcentaje con espacio adecuado
                      SizedBox(
                        width: 50,
                        child: Text(
                          '$percentage%',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
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

// Método mejorado para obtener el icono según la categoría (asegurando que se muestren)
IconData _getCategoryIcon(String categoryName) {
  // Importar de lib/icon_lists.dart si no lo has hecho
  // import '../icon_lists.dart';
  
  // Mapa ampliado de categorías a iconos (más completo)
  final Map<String, IconData> categoryIcons = {
    // Ingresos
    'salario': Icons.work,
    'nómina': Icons.work,
    'sueldo': Icons.work,
    'inversiones': Icons.trending_up,
    'inversión': Icons.trending_up,
    'intereses': Icons.account_balance,
    'dividendos': Icons.account_balance,
    'regalos': Icons.card_giftcard,
    'premios': Icons.emoji_events,
    'ventas': Icons.monetization_on,
    'venta': Icons.monetization_on,
    'negocio': Icons.store,
    'devoluciones': Icons.replay,
    'reembolsos': Icons.replay,
    'transferencia': Icons.sync_alt,
    'préstamos': Icons.attach_money,
    'préstamo': Icons.attach_money,
    
    // Gastos
    'alimentación': Icons.restaurant,
    'comida': Icons.restaurant,
    'restaurantes': Icons.restaurant,
    'transporte': Icons.directions_car,
    'taxi': Icons.local_taxi,
    'combustible': Icons.local_gas_station,
    'entretenimiento': Icons.movie,
    'ocio': Icons.sports_esports,
    'servicios': Icons.build,
    'servicio': Icons.build,
    'facturas': Icons.receipt,
    'factura': Icons.receipt,
    'agua': Icons.water_drop,
    'luz': Icons.lightbulb,
    'electricidad': Icons.power,
    'gas': Icons.fireplace,
    'internet': Icons.wifi,
    'teléfono': Icons.phone,
    'celular': Icons.smartphone,
    'cable': Icons.tv,
    'streaming': Icons.live_tv,
    'salud': Icons.medical_services,
    'médico': Icons.health_and_safety,
    'farmacia': Icons.local_pharmacy,
    'educación': Icons.school,
    'colegio': Icons.school,
    'universidad': Icons.school,
    'libros': Icons.book,
    'cursos': Icons.auto_stories,
    'ropa': Icons.shopping_bag,
    'vestimenta': Icons.checkroom,
    'hogar': Icons.home,
    'casa': Icons.home,
    'alquiler': Icons.home,
    'hipoteca': Icons.home,
    'viajes': Icons.flight,
    'vacaciones': Icons.beach_access,
    'hoteles': Icons.hotel,
    'tecnología': Icons.computer,
    'electrónica': Icons.devices,
    'gimnasio': Icons.fitness_center,
    'deporte': Icons.sports_soccer,
    'mascota': Icons.pets,
    'mascotas': Icons.pets,
    'seguro': Icons.security,
    'seguros': Icons.security,
    'impuestos': Icons.receipt_long,
    'compras': Icons.shopping_cart,
    'ahorro': Icons.savings,
  };
  
  // Normalizar a minúsculas para facilitar la coincidencia
  final normalizedName = categoryName.toLowerCase();
  
  // 1. Buscar coincidencia exacta primero
  if (categoryIcons.containsKey(normalizedName)) {
    return categoryIcons[normalizedName]!;
  }
  
  // 2. Buscar coincidencia parcial
  for (final entry in categoryIcons.entries) {
    if (normalizedName.contains(entry.key)) {
      return entry.value;
    }
    if (entry.key.contains(normalizedName) && normalizedName.length > 3) {
      return entry.value;
    }
  }
  
  // 3. Intentar extraer el iconCode de la categoría (si está guardado en el modelo)
  try {
    // Verificar si hay datos disponibles para esta categoría
    final matchingData = filteredData.firstWhere(
      (item) => item.explain.toLowerCase() == normalizedName,
      orElse: () => Add_data(
        '', // IN
        '0', // amount
        DateTime.now(), // datetime
        '', // detail
        '', // explain
        '', // name
        0, // iconCode
      ),
    );
    
    if (matchingData.iconCode > 0) {
      return IconData(matchingData.iconCode, fontFamily: 'MaterialIcons');
    }
  } catch (e) {
    // Ignorar errores para continuar con las opciones siguientes
  }
  
  // 4. Usar icono predeterminado según sea ingreso o gasto
  return isIncomeSelected ? Icons.arrow_upward : Icons.arrow_downward;
}

  Widget _buildBarChart(List<ChartData> data) {
  if (data.isEmpty) {
    return const SizedBox(
      height: 150,
      child: Center(
        child: Text(
          'No hay datos disponibles',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }

  return SizedBox(
    height: 200,
    child: SfCartesianChart(
      backgroundColor: Colors.transparent,
      plotAreaBorderWidth: 0, // Sin borde en el área de la gráfica

      // Ejes minimalistas
      primaryXAxis: CategoryAxis(
        labelStyle: const TextStyle(color: Colors.white70),
        axisLine: const AxisLine(width: 0),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
      ),
      primaryYAxis: NumericAxis(
        labelStyle: const TextStyle(color: Colors.white70),
        axisLine: const AxisLine(width: 0),
        majorGridLines: const MajorGridLines(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
      ),

      series: <CartesianSeries>[
        ColumnSeries<ChartData, String>(
          dataSource: data,
          xValueMapper: (ChartData item, _) => item.x,
          yValueMapper: (ChartData item, _) => item.y,
          pointColorMapper: (ChartData item, _) => item.color,
          dataLabelSettings: const DataLabelSettings(
            isVisible: true,
            textStyle: TextStyle(color: Colors.white, fontSize: 12),
          ),
          width: 0.6,            // Barra ligeramente más angosta
          borderRadius: BorderRadius.circular(8),
          color: Colors.teal,    // O un gradiente si lo deseas
        ),
      ],
    ),
  );
}

/// Reemplaza el card de "Detalle de ingresos/gastos" para usar datos agrupados
/// cuando el toggle está en "Ingresos".
Widget _buildDetailCard() {
  // Para ingresos, usamos el método _getIncomeGrouped(), 
  // Para gastos, mostramos los registros sin agrupar (o podrías crear un método análogo).
  final List<ChartData> data = isIncomeSelected
      ? _getIncomeGrouped()
      : filteredData.map((item) {
          final amount = double.tryParse(item.amount) ?? 0;
          return ChartData(
            '${item.datetime.day}-${item.datetime.month}-${item.datetime.year}',
            amount,
            Colors.red,
          );
        }).toList();

  if (data.isEmpty) {
    return _buildCard(
      title: 'Detalle de ${isIncomeSelected ? 'ingresos' : 'gastos'}',
      child: const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text('No hay datos para el periodo seleccionado',
            style: TextStyle(color: Colors.white70)),
      ),
    );
  }

  return _buildCard(
    title: 'Detalle de ${isIncomeSelected ? 'ingresos' : 'gastos'}',
    child: Column(
      children: data.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Etiqueta (Semana # o Mes si es ingreso agrupado, o fecha si es gasto)
              Text(
                item.x,
                style: const TextStyle(color: Colors.white),
              ),
              // Monto con formateo de miles
              Text(
                '\$${_formatNumber(item.y)}',
                style: TextStyle(
                  color: isIncomeSelected ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    ),
  );
}

  /// Ejemplo de uso: Mostrar datos de ingresos (agrupados) en una tarjeta
  Widget _buildIncomeGroupingCard() {
    final List<ChartData> data = _getIncomeGrouped();
    if (data.isEmpty) {
      return _buildCard(
        title: 'Ingresos Agrupados',
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No hay datos de ingresos para el periodo seleccionado',
              style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    return _buildCard(
      title: 'Ingresos Agrupados',
      child: Column(
        children: data.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.x,
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  '\$${_formatNumber(item.y)}',
                  style: const TextStyle(color: Colors.green),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
