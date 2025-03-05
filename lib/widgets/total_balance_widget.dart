import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class TotalBalanceWidget extends StatefulWidget {
  // ========= Valores dinámicos =========
  final ValueNotifier<double> availableBalanceNotifier; // Notificador de saldo disponible
  final double accountingBalance;  // Balance contable (puede ser negativo)
  final double totalExpenses;      // Total de egresos
  final double totalIncome;        // Total de ingresos

  // ========= Callbacks para botones =========
  final VoidCallback onManageAccounts;
  final VoidCallback onShowAll;
  final VoidCallback onShowExpenses;
  final VoidCallback onShowIncome;

  // Texto inicial del botón de fecha
  final String selectedMonthYear;

  const TotalBalanceWidget({
    Key? key,
    required this.availableBalanceNotifier,
    required this.accountingBalance,
    required this.totalExpenses,
    required this.totalIncome,
    required this.onManageAccounts,
    required this.onShowAll,
    required this.onShowExpenses,
    required this.onShowIncome,
    this.selectedMonthYear = 'Diciembre 2025',
  }) : super(key: key);

  @override
  _TotalBalanceWidgetState createState() => _TotalBalanceWidgetState();
}

class _TotalBalanceWidgetState extends State<TotalBalanceWidget> {
  String selectedFilter = 'Todos';

  // Variables para manejar el mes y año seleccionados
  late String _selectedMonthYear;  // Texto mostrado en el botón
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    // Inicializa la configuración regional (lo ideal es hacerlo una sola vez en main())
    initializeDateFormatting('es', null);

    // Asigna valores iniciales
    _selectedMonthYear = widget.selectedMonthYear;
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
  }

  // Abre el menú desplegable de mes y año
  void _showMonthYearSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // Para ver bordes redondeados
      builder: (BuildContext context) {
        // Variables locales para la selección, inicializadas con el estado actual
        int localMonth = _selectedMonth;
        int localYear = _selectedYear;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateSB) {
            final List<String> months = [
              'Ene', 'Feb', 'Mar', 'Abr',
              'May', 'Jun', 'Jul', 'Ago',
              'Sep', 'Oct', 'Nov', 'Dic',
            ];

            return Container(
              padding: const EdgeInsets.all(16.0),
              decoration: const BoxDecoration(
                color: Color(0xFF2A2A3A),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Cabecera con flechas para el año
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, color: Colors.white),
                        onPressed: () {
                          setStateSB(() {
                            localYear--;
                          });
                        },
                      ),
                      Text(
                        '$localYear',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, color: Colors.white),
                        onPressed: () {
                          setStateSB(() {
                            localYear++;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Grid de 12 meses
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 12,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, // 4 columnas
                      childAspectRatio: 2.0,
                    ),
                    itemBuilder: (context, index) {
                      final monthNumber = index + 1;
                      final isSelected = (monthNumber == localMonth);

                      return GestureDetector(
                        onTap: () {
                          setStateSB(() {
                            localMonth = monthNumber;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.all(4.0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF368983) // Color de selección
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            months[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade200,
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Botón Aceptar
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF368983),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      // Actualiza la selección en el estado principal
                      setState(() {
                        _selectedMonth = localMonth;
                        _selectedYear = localYear;
                        final date = DateTime(_selectedYear, _selectedMonth);
                        _selectedMonthYear = DateFormat.yMMMM('es').format(date);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Aceptar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Formateador de moneda
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '',
      decimalDigits: 2,
    );

    // Porcentaje de ingresos vs. total (ingresos + egresos)
    final double total = widget.totalIncome + widget.totalExpenses;
    double ratio = total > 0 ? widget.totalIncome / total : 0;

    return ValueListenableBuilder<double>(
      valueListenable: widget.availableBalanceNotifier,
      builder: (context, availableBalance, child) {
        return Container(
          decoration: BoxDecoration(
            color: const Color.fromRGBO(42, 49, 67, 1),
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FILA SUPERIOR: Disponible, Balance contable y gráfica
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Textos de Disponible y Balance contable
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disponible',
                        style: TextStyle(
                          color: Colors.grey.shade200,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${currencyFormat.format(availableBalance)} COP',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Balance Contable: '
                        '${widget.accountingBalance < 0 ? "- " : ""}'
                        '${currencyFormat.format(widget.accountingBalance.abs())} COP',
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  // Gráfica: Anillo que muestra el % de ingresos (sin ícono)
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: CircularProgressIndicator(
                      value: ratio.clamp(0, 1),
                      strokeWidth: 5,
                      backgroundColor: Colors.grey.shade700,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF368983),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA DE BOTONES: Gestionar cuentas y Fecha (selector de mes/año)
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: widget.onManageAccounts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2639),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    icon: const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Gestionar cuentas',
                      style: TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _showMonthYearSelector,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1F2639),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    icon: const Icon(
                      Icons.calendar_month,
                      size: 16,
                      color: Colors.white,
                    ),
                    label: Text(
                      _selectedMonthYear,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA: Total de egresos y Total de ingresos
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(right: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2639),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de egresos',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currencyFormat.format(widget.totalExpenses)} COP',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(left: 4.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1F2639),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de ingresos',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${currencyFormat.format(widget.totalIncome)} COP',
                            style: const TextStyle(
                              color: Color(0xFF50FA7B),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA DE PESTAÑAS: Todos, Gastos, Ingresos
              Row(
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedFilter = 'Todos';
                      });
                      widget.onShowAll();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedFilter == 'Todos'
                          ? const Color(0xFF1F2639)
                          : const Color.fromRGBO(42, 49, 67, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Todos', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedFilter = 'Gastos';
                      });
                      widget.onShowExpenses();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedFilter == 'Gastos'
                          ? const Color(0xFF1F2639)
                          : const Color.fromRGBO(42, 49, 67, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Gastos', style: TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        selectedFilter = 'Ingresos';
                      });
                      widget.onShowIncome();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedFilter == 'Ingresos'
                          ? const Color(0xFF1F2639)
                          : const Color.fromRGBO(42, 49, 67, 1),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Ingresos', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}