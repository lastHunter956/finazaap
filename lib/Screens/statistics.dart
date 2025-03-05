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
    map[item.name] = (map[item.name] ?? 0) + amount;
  }

  final List<ChartData> list = [];
  int colorIndex = 0;

  map.forEach((key, value) {
    // Tomamos el color de la paleta usando módulo
    final color = colorPalette[colorIndex % colorPalette.length];
    colorIndex++;
    list.add(ChartData(key, value, color));
  });

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
    if (value >= 1000000) {
      final millones = value / 1000000;
      return '${millones.toStringAsFixed(1)}M';
    } else {
      return NumberFormat('#,##0').format(value);
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
        backgroundColor: const Color.fromARGB(255, 31, 38, 57),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Informes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
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
              _buildCard(
                title: 'Detalle de ${isIncomeSelected ? 'ingresos' : 'gastos'}',
                child: Column(
                  children: filteredData.map((item) {
                    final amount = double.tryParse(item.amount) ?? 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Fecha
                          Text(
                            '${item.datetime.day}-${item.datetime.month}-${item.datetime.year}',
                            style: const TextStyle(color: Colors.white),
                          ),
                          // Monto
                          Text(
                            '\$${_formatNumber(amount)}',
                            style: TextStyle(
                              color: isIncomeSelected ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),

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
    return SizedBox(
      height: 200,
      child: SfCircularChart(
        backgroundColor: Colors.transparent,
        legend: Legend(
          isVisible: true,
          textStyle: const TextStyle(color: Colors.white70),
          position: LegendPosition.bottom,
        ),
        series: <CircularSeries>[
          DoughnutSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (ChartData item, _) => item.x,
            yValueMapper: (ChartData item, _) => item.y,
            pointColorMapper: (ChartData item, _) => item.color,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(color: Colors.white),
            ),
            radius: '70%',
            innerRadius: '60%',
          )
        ],
      ),
    );
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
        primaryXAxis: CategoryAxis(
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        primaryYAxis: NumericAxis(
          labelStyle: const TextStyle(color: Colors.white70),
        ),
        series: <CartesianSeries>[
          ColumnSeries<ChartData, String>(
            dataSource: data,
            xValueMapper: (ChartData item, _) => item.x,
            yValueMapper: (ChartData item, _) => item.y,
            pointColorMapper: (ChartData item, _) => item.color,
            dataLabelSettings: const DataLabelSettings(
              isVisible: true,
              textStyle: TextStyle(color: Colors.white),
            ),
            borderRadius: BorderRadius.circular(5),
            color: Colors.teal,
          )
        ],
      ),
    );
  }
}
