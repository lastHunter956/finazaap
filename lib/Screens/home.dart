import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/utlity.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
import 'package:finazaap/widgets/transaction_list_widget.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importa la pantalla de cuentas
import 'package:finazaap/screens/selecctaccount.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final box = Hive.box<Add_data>('data');
  String filter = 'Todos';

  final List<String> day = [
    'lunes',
    "martes",
    "miércoles",
    "jueves",
    'viernes',
    'sábado',
    'domingo'
  ];

  // Notificador de saldo disponible
  final ValueNotifier<double> availableBalanceNotifier = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _updateAvailableBalance();
  }

  // Funciones para calcular totales
  double total() {
    return box.values.fold(
        0.0, (sum, item) => sum + (double.tryParse(item.amount) ?? 0.0));
  }

  double income() {
    return box.values
        .where((item) => item.IN == 'Income')
        .fold(0.0, (sum, item) => sum + (double.tryParse(item.amount) ?? 0.0));
  }

  double expenses() {
    return box.values
        .where((item) => item.IN == 'Expenses')
        .fold(0.0, (sum, item) => sum + (double.tryParse(item.amount) ?? 0.0));
  }

  List<Add_data> getFilteredTransactions() {
    if (filter == 'Todos') {
      return box.values.toList();
    } else if (filter == 'Gastos') {
      return box.values.where((item) => item.IN == 'Expenses').toList();
    } else if (filter == 'Ingresos') {
      return box.values.where((item) => item.IN == 'Income').toList();
    }
    return [];
  }

  void _updateAvailableBalance() {
    availableBalanceNotifier.value = total();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Fondo original
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, value, child) {
            _updateAvailableBalance();
            return CustomScrollView(
              slivers: [
                // Título superior "Transacciones" en un container azul a lo ancho de la pantalla
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(42, 49, 67, 1),
                    ),
                    child: const Center(
                      child: Text(
                        'Transacciones',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                // Espacio entre el título y el siguiente contenedor
                const SliverToBoxAdapter(
                  child: SizedBox(height: 20),
                ),
                // Contenedor con TotalBalanceWidget
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: TotalBalanceWidget(
                      availableBalanceNotifier: availableBalanceNotifier,
                      accountingBalance: total(), // Ajusta según tu lógica
                      totalExpenses: expenses(),
                      totalIncome: income(),
                      onManageAccounts: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => MyHomePage(
                                onBalanceUpdated: (double balance) {
                                  availableBalanceNotifier.value = balance; // Esta es la línea clave
                                },
                              )),
                        );
                      },
                      // Se ha removido onSelectDate, ya que el widget maneja internamente la selección de fecha.
                      onShowAll: () {
                        setState(() {
                          filter = 'Todos';
                        });
                      },
                      onShowExpenses: () {
                        setState(() {
                          filter = 'Gastos';
                        });
                      },
                      onShowIncome: () {
                        setState(() {
                          filter = 'Ingresos';
                        });
                      },
                    ),
                  ),
                ),
                // Título para "Historial de transacciones" (opcional)
                SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: const Text(
                      'Historial de transacciones',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Lista de transacciones
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final history = getFilteredTransactions()[index];
                      return Dismissible(
                        key: UniqueKey(),
                        onDismissed: (direction) => history.delete(),
                        child: _buildTransactionItem(history),
                      );
                    },
                    childCount: getFilteredTransactions().length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: const FloatingActionMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // Widget para cada transacción
  Widget _buildTransactionItem(Add_data history) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          color: const Color.fromARGB(200, 255, 255, 255),
          padding: const EdgeInsets.all(8),
          child: Icon(
            IconData(
              history.iconCode,
              fontFamily: 'MaterialIcons',
            ),
            size: 25,
            color: const Color.fromRGBO(31, 38, 57, 1),
          ),
        ),
      ),
      title: Row(
        children: [
          Text(
            history.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          Text(
            " • ${history.explain}",
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${day[history.datetime.weekday - 1]}  ${history.datetime.year}-${history.datetime.day}-${history.datetime.month}',
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          Text(
            NumberFormat.currency(locale: 'es', symbol: '\$')
                .format(double.parse(history.amount)),
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 17,
              color: history.IN == 'Income'
                  ? const Color.fromARGB(255, 167, 226, 169)
                  : const Color.fromARGB(255, 230, 172, 168),
            ),
          ),
        ],
      ),
    );
  }
}