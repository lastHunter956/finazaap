// Reemplaza las importaciones conflictivas por estas líneas:
import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
import 'package:finazaap/widgets/transaction_list_widget.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:collection';

// Importa todas las clases necesarias, ocultando AccountItem para evitar conflictos
import 'package:finazaap/screens/selecctaccount.dart' hide AccountItem;
import 'package:finazaap/Screens/transfer.dart' hide AccountItem;
import 'package:finazaap/Screens/add.dart' hide AccountItem;
import 'package:finazaap/Screens/add_expense.dart' hide AccountItem;
import 'package:finazaap/data/utlity.dart' hide AccountItem;

// Añadir esta importación al inicio del archivo
import 'package:finazaap/data/transaction_service.dart';

// Definir una clase AccountItem local para home.dart
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
}

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
  final ValueNotifier<double> availableBalanceNotifier =
      ValueNotifier<double>(0.0);

  // Agregar estas variables para almacenar el filtro de fecha
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  bool _filterByDate = true; // <-- Cambiado a true por defecto

  @override
  void initState() {
    super.initState();
    _updateAvailableBalance();
    
    // Registrar listener adicional para cuando cambian los datos
    box.listenable().addListener(() {
      if (mounted) {
        setState(() {});
        _updateAvailableBalance();
      }
    });
  }

  @override
  void dispose() {
    // Limpiar listeners si es necesario
    super.dispose();
  }

  // Nuevo método que obtiene TODAS las transacciones sin filtros
  List<Add_data> getAllTransactions() {
    return box.values.toList();
  }

  // Añadir un nuevo método que solo filtra por fecha, ignorando el tipo de filtro
  List<Add_data> getTransactionsFilteredByDateOnly() {
    List<Add_data> transactions = box.values.toList();
    
    // Solo aplicar filtro por fecha si está activado
    if (_filterByDate) {
      return transactions.where((transaction) => 
        transaction.datetime.month == _selectedMonth && 
        transaction.datetime.year == _selectedYear
      ).toList();
    }
    
    return transactions;
  }

  // Balance contable: suma de ingresos - gastos (excluyendo transferencias)
  double accountingBalance() {
    final transactions = getTransactionsFilteredByDateOnly(); // Solo filtrar por fecha
    double balance = 0.0;
    
    for (var item in transactions) {
      if (item.IN == 'Income') {
        // Sumar ingresos
        balance += (double.tryParse(item.amount) ?? 0.0);
      } else if (item.IN == 'Expenses') {
        // Restar gastos
        balance -= (double.tryParse(item.amount) ?? 0.0);
      }
      // Las transferencias se ignoran completamente
    }
    
    return balance;
  }

  // Total para la visualización (respeta los filtros)
  double total() {
    final transactions = getFilteredTransactions();
    double sum = 0.0;
    
    for (var item in transactions) {
      // Solo sumar ingresos y gastos, ignorar transferencias
      if (item.IN == 'Income') {
        sum += (double.tryParse(item.amount) ?? 0.0);
      } else if (item.IN == 'Expenses') {
        sum += (double.tryParse(item.amount) ?? 0.0); // También suma para mostrar el total de ambos
      }
    }
    
    return sum;
  }

  // Total de ingresos (respeta filtros)
  double income() {
    final transactions = getTransactionsFilteredByDateOnly() // Solo filtrar por fecha
      .where((item) => item.IN == 'Income');
    return transactions.fold(0.0, (sum, item) => 
      sum + (double.tryParse(item.amount) ?? 0.0)
    );
  }

  // Total de gastos (respeta filtros)
  double expenses() {
    final transactions = getTransactionsFilteredByDateOnly() // Solo filtrar por fecha
      .where((item) => item.IN == 'Expenses');
    return transactions.fold(0.0, (sum, item) => 
      sum + (double.tryParse(item.amount) ?? 0.0)
    );
  }

  List<Add_data> getFilteredTransactions() {
    // Primero filtramos por tipo (Todos/Gastos/Ingresos)
    List<Add_data> transactions;
    if (filter == 'Todos') {
      transactions = box.values.toList();
    } else if (filter == 'Gastos') {
      transactions = box.values.where((item) => item.IN == 'Expenses').toList();
    } else if (filter == 'Ingresos') {
      transactions = box.values.where((item) => item.IN == 'Income').toList();
    } else {
      transactions = box.values.toList();
    }
    
    // Luego filtramos por fecha si _filterByDate está activado
    if (_filterByDate) {
      return transactions.where((transaction) => 
        transaction.datetime.month == _selectedMonth && 
        transaction.datetime.year == _selectedYear
      ).toList();
    }
    
    return transactions;
  }

  Future<void> _updateAvailableBalance() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? accountsData = prefs.getStringList('accounts');

    if (accountsData != null) {
      double totalBalance = 0.0;
      for (var accountJson in accountsData) {
        final Map<String, dynamic> data = json.decode(accountJson);
        // Convertir el balance a double (puede estar como String)
        final balance = data['balance'] is String
            ? double.tryParse(data['balance']) ?? 0.0
            : (data['balance'] is double ? data['balance'] : 0.0);
        totalBalance += balance;
      }

      // Actualiza el notificador con el valor calculado
      availableBalanceNotifier.value = totalBalance;
    }
  }

  // Método para recibir la selección de fecha
  void _onDateSelected(int month, int year) {
    setState(() {
      _selectedMonth = month;
      _selectedYear = year;
      _filterByDate = true;
      
      // Actualizar inmediatamente los valores en la UI
      // No es necesario llamar a estos métodos explícitamente
      // pues setState() ya reconstruirá el widget y ejecutará los cálculos
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Agregar la implementación y cerrar la función correctamente
        return true; // Permitir la navegación hacia atrás por defecto
      }, // Añadir esta coma
      child: Scaffold( // Mover el child aquí con la indentación correcta
        // Fondo original
        backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
        body: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, value, child) {
              _updateAvailableBalance();
              
              // Agrupar las transacciones por fecha primero
              final transactionsByDate = _getTransactionsGroupedByDate();
              
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: TotalBalanceWidget(
                        availableBalanceNotifier: availableBalanceNotifier,
                        accountingBalance: accountingBalance(), // Usar el nuevo método que excluye transferencias
                        totalExpenses: expenses(),
                        totalIncome: income(),
                        onManageAccounts: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MyHomePage(
                                      onBalanceUpdated: (double balance) {
                                        availableBalanceNotifier.value =
                                            balance; // Esta es la línea clave
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
                        selectedMonthYear: DateFormat.yMMMM('es').format(
                          DateTime(_selectedYear, _selectedMonth)
                        ), // <-- Inicializar con fecha actual
                        onDateSelected: _onDateSelected, // <-- Nuevo callback
                      ),
                    ),
                  ),
                  // Indicador de filtrado activo
                  if (_filterByDate) 
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        
                      ),
                    ),
                  // Título para "Historial de transacciones" (opcional)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
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
                  // Lista de transacciones agrupadas por fecha
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        // Obtenemos la fecha y las transacciones de ese día
                        final dateKey = transactionsByDate.keys.elementAt(index);
                        final dailyTransactions = transactionsByDate[dateKey]!;
                        final dailyIncome = _calculateDailyIncome(dailyTransactions);
                        
                        // Construimos la sección de fecha con sus transacciones
                        return _buildDateSection(dateKey, dailyIncome, dailyTransactions);
                      },
                      childCount: transactionsByDate.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: const SizedBox(height: 80),
                  )
                ],
              );
            },
          ),
        ),
        floatingActionButton: const FloatingActionMenu(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ), // Añadir esta coma
    ); // Cerrar correctamente el WillPopScope
  }

  // Método para agrupar transacciones por fecha
  Map<String, List<Add_data>> _getTransactionsGroupedByDate() {
    // Obtenemos las transacciones filtradas
    final transactions = getFilteredTransactions();
    
    // Creamos un mapa para agrupar por fecha (fecha -> lista de transacciones)
    final Map<String, List<Add_data>> grouped = {};
    
    for (var transaction in transactions) {
      // Creamos una clave de fecha: "dd/mm/yyyy"
      final dateKey = "${transaction.datetime.day.toString().padLeft(2, '0')}/${transaction.datetime.month.toString().padLeft(2, '0')}/${transaction.datetime.year}";
      
      // Si la fecha no existe como clave, la inicializamos
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      
      // Añadimos la transacción al grupo correspondiente
      grouped[dateKey]!.add(transaction);
    }
    
    // Ordenamos las claves por fecha (más reciente primero)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) {
        // Convertimos las fechas en formato dd/mm/yyyy a objetos DateTime
        final parts1 = a.split('/');
        final parts2 = b.split('/');
        
        final date1 = DateTime(
          int.parse(parts1[2]), // año
          int.parse(parts1[1]), // mes
          int.parse(parts1[0])  // día
        );
        
        final date2 = DateTime(
          int.parse(parts2[2]), // año
          int.parse(parts2[1]), // mes
          int.parse(parts2[0])  // día
        );
        
        // Ordenar de más reciente a más antigua
        return date2.compareTo(date1);
      });
    
    // Ordenar las transacciones dentro de cada día (más reciente primero)
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.datetime.compareTo(a.datetime));
    }
    
    // Creamos un nuevo mapa con las claves ordenadas
    final LinkedHashMap<String, List<Add_data>> sortedGrouped = LinkedHashMap();
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  // Calcular el total de ingresos del día
  double _calculateDailyIncome(List<Add_data> transactions) {
    return transactions
        .where((t) => t.IN == 'Income')
        .fold(0.0, (sum, t) => sum + (double.tryParse(t.amount) ?? 0.0));
  }

  // Construir la sección de fecha con sus transacciones
  Widget _buildDateSection(String dateKey, double dailyIncome, List<Add_data> transactions) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de fecha y total - AHORA SIN FONDO DE COLOR
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Fecha formateada
                Text(
                  dateKey,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                // Total de ingresos del día
                Text(
                  NumberFormat.currency(locale: 'es', symbol: '\$').format(dailyIncome),
                  style: const TextStyle(
                    color: Color.fromARGB(255, 167, 226, 169), // Verde para ingresos
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          // NUEVO CONTENEDOR CON BORDES REDONDEADOS para las transacciones
          Container(
            decoration: BoxDecoration(
              color: const Color.fromRGBO(42, 49, 67, 1), // Color aplicado al contenedor principal
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  // Lista de transacciones del día
                  ...transactions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final transaction = entry.value;
                    
                    return Column(
                      children: [
                        _buildTransactionItem(transaction),
                        // Mostrar divisor solo si no es la última transacción
                        if (index < transactions.length - 1)
                          const Divider(
                            color: Colors.grey,
                            height: 1, 
                            thickness: 0.2,
                            indent: 60, // Indentación para que el divisor empiece después del icono
                            endIndent: 10,
                          ),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Widget para cada transacción - Con funcionalidad de edición y eliminación
  Widget _buildTransactionItem(Add_data history) {
    // Detectar tipo de transacción
    bool isTransfer = history.IN == 'Transfer';
    bool isIncome = history.IN == 'Income';
    
    // Construir el título según tipo de transacción
    String mainTitle;
    if (isTransfer) {
      mainTitle = history.detail.isNotEmpty 
          ? "Transferencia - ${history.detail}" 
          : "Transferencia";
    } else {
      mainTitle = history.detail.isNotEmpty 
          ? "${history.explain} - ${history.detail}" 
          : history.explain;
    }
    
    // Determinar qué icono mostrar
    IconData transactionIcon;
    if (isTransfer) {
      transactionIcon = Icons.sync_alt;
    } else {
      transactionIcon = IconData(
        history.iconCode > 0 ? history.iconCode : Icons.category.codePoint,
        fontFamily: 'MaterialIcons',
      );
    }

    // Envolver en InkWell para detectar toques y mostrar efecto visual
    return InkWell(
      onTap: () => _showTransactionOptions(history),
      splashColor: Colors.blueAccent.withOpacity(0.1),
      highlightColor: Colors.blueAccent.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono con fondo redondeado y sombra sutil
            Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(200, 255, 255, 255),
                borderRadius: BorderRadius.circular(50),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(
                transactionIcon,
                size: 22,
                color: isTransfer
                    ? Colors.blueAccent
                    : (isIncome ? Colors.green : Colors.redAccent),
              ),
            ),
            
            const SizedBox(width: 14),
            
            // Contenido de la transacción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título principal: Categoría - Descripción
                  Text(
                    mainTitle,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Cuenta o ruta de transferencia
                  Text(
                    isTransfer 
                        ? history.explain  // Ruta de transferencia: "Cuenta origen > Cuenta destino"
                        : history.name,     // Nombre de la cuenta
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white60,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            // Monto con color según tipo
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Text(
                NumberFormat.currency(locale: 'es', symbol: '\$')
                    .format(double.parse(history.amount)),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  color: isTransfer 
                      ? Colors.grey
                      : (isIncome
                          ? const Color.fromARGB(255, 167, 226, 169)
                          : const Color.fromARGB(255, 230, 172, 168)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Método para mostrar opciones de edición/eliminación
  // Método mejorado para mostrar opciones de transacción
void _showTransactionOptions(Add_data transaction) {
  // Preparar datos de la transacción
  final bool isTransfer = transaction.IN == 'Transfer';
  final bool isIncome = transaction.IN == 'Income';
  final String transactionTitle = transaction.detail.isNotEmpty 
      ? transaction.detail 
      : (isTransfer ? 'Transferencia' : transaction.explain);
  final String formattedAmount = NumberFormat.currency(locale: 'es', symbol: '\$')
      .format(double.parse(transaction.amount));
  
  // Definir colores y estilos
  final Color primaryColor = isTransfer 
      ? const Color(0xFF3D7AF0)  // Azul refinado
      : (isIncome ? const Color(0xFF2E9E5B) : const Color(0xFFE53935)); // Verde y rojo premium
  
  final Gradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryColor.withOpacity(0.12),
      primaryColor.withOpacity(0.04),
    ],
  );
  
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Opciones de transacción",
    barrierColor: Colors.black.withOpacity(0.7),
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => Container(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutQuint,
      );
      
      return ScaleTransition(
        scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
        child: FadeTransition(
          opacity: animation,
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.88,
                constraints: BoxConstraints(
                  maxWidth: 400, // Limitar ancho máximo
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF222939),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -5,
                    ),
                    BoxShadow(
                      color: primaryColor.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 5),
                      spreadRadius: -2,
                    ),
                  ],
                  border: Border.all(
                    color: primaryColor.withOpacity(0.15),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ===== CABECERA =====
                      Container(
                        decoration: BoxDecoration(
                          gradient: backgroundGradient,
                        ),
                        child: Stack(
                          children: [
                            // Decoración de fondo
                            Positioned(
                              right: -20,
                              top: -20,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: primaryColor.withOpacity(0.05),
                              ),
                            ),
                            
                            // Contenido de la cabecera
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                              child: Column(
                                children: [
                                  // Icono principal
                                  Container(
                                    height: 65,
                                    width: 65,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          primaryColor.withOpacity(0.2),
                                          primaryColor.withOpacity(0.1),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(50),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primaryColor.withOpacity(0.2),
                                          blurRadius: 15,
                                          spreadRadius: 0,
                                        ),
                                      ],
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.5),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      isTransfer ? Icons.swap_horiz_rounded : 
                                      (isIncome ? Icons.north_rounded : Icons.south_rounded),
                                      size: 30,
                                      color: primaryColor,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 20),
                                  
                                  // Título de la transacción
                                  Text(
                                    transactionTitle,
                                    style: const TextStyle(
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Tipo de transacción
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14, 
                                      vertical: 6
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: primaryColor.withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      isTransfer ? "Transferencia" : 
                                      (isIncome ? "Ingreso" : "Gasto"),
                                      style: TextStyle(
                                        color: primaryColor,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 18),
                                  
                                  // Monto destacado
                                  Text(
                                    formattedAmount,
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: primaryColor,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  
                                  // Información de cuenta(s)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.1),
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Etiqueta
                                        Text(
                                          isTransfer ? "Ruta de transferencia" : "Cuenta",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 6),
                                        
                                        // Valor
                                        Row(
                                          children: [
                                            Icon(
                                              isTransfer ? Icons.compare_arrows_rounded : Icons.account_balance_wallet,
                                              size: 16,
                                              color: primaryColor.withOpacity(0.8),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                isTransfer ? transaction.explain : transaction.name,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 10),
                                  
                                  // Fecha y hora
                                  Container(
                                    width: double.infinity,
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: Colors.white.withOpacity(0.5),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          DateFormat('dd/MM/yyyy - HH:mm').format(transaction.datetime),
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // ===== ACCIONES =====
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Botón Editar - Solo icono con tamaño fijo
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _editTransaction(transaction);
                                },
                                borderRadius: BorderRadius.circular(18),
                                splashColor: const Color(0xFFFFA726).withOpacity(0.2),
                                highlightColor: const Color(0xFFFFA726).withOpacity(0.1),
                                child: Ink(
                                  width: 160, // Tamaño fijo para el contenedor
                                  height: 80, // Tamaño fijo para el contenedor
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFFFA726).withOpacity(0.2),
                                        const Color(0xFFFFA726).withOpacity(0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFFFA726).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.edit_rounded,
                                      size: 28,
                                      color: const Color(0xFFFFA726),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 32),
                            
                            // Botón Eliminar - Solo icono con tamaño fijo
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _confirmDeleteTransaction(transaction);
                                },
                                borderRadius: BorderRadius.circular(18),
                                splashColor: const Color(0xFFE53935).withOpacity(0.2),
                                highlightColor: const Color(0xFFE53935).withOpacity(0.1),
                                child: Ink(
                                  width: 160, // Tamaño fijo para el contenedor
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(0xFFE53935).withOpacity(0.2),
                                        const Color(0xFFE53935).withOpacity(0.08),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFFE53935).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      Icons.delete_rounded,
                                      size: 28,
                                      color: const Color(0xFFE53935),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // ===== PIE DE DIÁLOGO =====
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.2),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.close_rounded,
                                    size: 16,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cerrar',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.3,
                                    ),
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
              ),
            ),
          ),
        ),
      );
    },
  );
}

// Widget de botón premium con efecto de presión
Widget _buildPremiumButton({
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: color.withOpacity(0.1),
      highlightColor: color.withOpacity(0.05),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withOpacity(0.15),
              color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono con fondo
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: color.withOpacity(0.9),
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Etiqueta
              Text(
                label,
                style: TextStyle(
                  color: color.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  // Método _editTransaction
void _editTransaction(Add_data transaction) async {
  Widget editScreen;
  
  // Obtener la key directamente del objeto HiveObject
  final dynamic transactionKey = box.keyAt(box.values.toList().indexOf(transaction));
  
  if (transaction.IN == 'Transfer') {
    // Para transferencias
    editScreen = TransferScreen(
      isEditing: true,
      transaction: transaction,
      transactionKey: transactionKey,  // Pasar la key
      onTransactionUpdated: () {
        setState(() {});
        _updateAvailableBalance();
      },
    );
  } else if (transaction.IN == 'Income') {
    // Para ingresos
    editScreen = Add_Screen(
      isEditing: true,
      transaction: transaction,
      transactionKey: transactionKey,  // Pasar la key
      onTransactionUpdated: () {
        setState(() {});
        _updateAvailableBalance();
      },
    );
  } else {
    // Para gastos
    editScreen = AddExpenseScreen(
      isEditing: true,
      transaction: transaction,
      transactionKey: transactionKey,  // Pasar la key
      onTransactionUpdated: () {
        setState(() {});
        _updateAvailableBalance();
      },
    );
  }
  
  try {
    // Mostrar indicador de carga opcional
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(child: CircularProgressIndicator());
      },
    );
    
    // Navegar a la pantalla de edición
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => editScreen),
    );
    
    // Cerrar el indicador de carga
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    // Actualizar la UI después de regresar
    if (mounted) {
      setState(() {});
      await _updateAvailableBalance();
      
      // Forzar actualización del widget ValueListenableBuilder
      // No llamar a notifyListeners, simplemente actualizar el estado
    }
  } catch (e) {
    // Cerrar el indicador de carga si hay un error
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    
    print('Error durante la edición: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al editar: ${e.toString()}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  // Método para confirmar eliminación
  void _confirmDeleteTransaction(Add_data transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A3A),
        title: const Text('Confirmar eliminación', style: TextStyle(color: Colors.white)),
        content: const Text(
          '¿Estás seguro que deseas eliminar esta transacción? Esta acción no se puede deshacer.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.redAccent)),
          ),
            ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
            ),
            onPressed: () {
              Navigator.pop(context);
              _deleteTransaction(transaction);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // Corregir la llamada a deleteTransaction
void _deleteTransaction(Add_data transaction) async {
  try {
    // Usar el servicio centralizado para eliminar la transacción
    bool success = await TransactionService.deleteTransaction(transaction);
    
    if (!success) {
      throw Exception('Error al actualizar los saldos');
    }
    
    // Actualizar UI
    setState(() {});
    
    // Actualizar saldo disponible global
    await _updateAvailableBalance();
    
    // Mostrar confirmación
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transacción eliminada'),
        backgroundColor: Colors.redAccent,
      ),
    );
  } catch (e) {
    print('Error al eliminar transacción: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Error al eliminar: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Añadir este nuevo método para revertir transferencias
Future<void> _revertTransfer(Add_data transaction) async {
  try {
    final amount = double.parse(transaction.amount);
    
    // Obtener nombres de cuentas de origen y destino
    final parts = transaction.explain.split(' > ');
    if (parts.length != 2) {
      throw Exception('Formato de transferencia inválido');
    }
    
    final sourceAccount = parts[0].trim();
    final destAccount = parts[1].trim();
    
    // 1. Revertir en cuenta de origen (devolver dinero)
    await _updateAccountBalance(sourceAccount, amount, true);
    
    // 2. Revertir en cuenta de destino (quitar dinero)
    await _updateAccountBalance(destAccount, amount, false);
  } catch (e) {
    print('Error revirtiendo transferencia: $e');
    throw e; // Re-lanzar para manejo superior
  }
}

// Método auxiliar para actualizar el saldo de una cuenta específica
Future<void> _updateAccountBalance(String accountName, double amount, bool add) async {
  final prefs = await SharedPreferences.getInstance();
  List<String>? accountsData = prefs.getStringList('accounts');
  
  if (accountsData != null) {
    List<Map<String, dynamic>> accounts = [];
    bool updated = false;
    
    for (var accountJson in accountsData) {
      final Map<String, dynamic> data = json.decode(accountJson);
      
      // Si es la cuenta que buscamos, actualizar su saldo
      if (data['title'] == accountName) {
        double currentBalance;
        if (data['balance'] is String) {
          currentBalance = double.tryParse(data['balance']) ?? 0.0;
        } else {
          currentBalance = (data['balance'] is double) ? data['balance'] : 0.0;
        }
        
        // Actualizar saldo según la operación
        if (add) {
          currentBalance += amount; // Sumar (devolver dinero)
        } else {
          currentBalance -= amount; // Restar (quitar dinero)
        }
        
        // Preservar el tipo original
        if (data['balance'] is String) {
          data['balance'] = currentBalance.toString();
        } else {
          data['balance'] = currentBalance;
        }
        
        updated = true;
      }
      
      accounts.add(data);
    }
    
    if (updated) {
      List<String> updatedAccountsData = accounts.map((data) => json.encode(data)).toList();
      await prefs.setStringList('accounts', updatedAccountsData);
    }
  }
}

  // Actualizar saldo de la cuenta después de eliminar una transacción
  Future<void> _updateAccountBalanceAfterDeletion(
  String accountName,
  double amount,
  bool wasIncome
) async {
  final prefs = await SharedPreferences.getInstance();
  List<String>? accountsData = prefs.getStringList('accounts');
  
  if (accountsData != null) {
    // Trabajar directamente con los mapas para preservar todos los campos originales
    List<Map<String, dynamic>> accounts = [];
    bool updated = false;
    
    // Procesar cada cuenta manteniendo su estructura original
    for (var accountJson in accountsData) {
      // Preservar el mapa completo original
      final Map<String, dynamic> data = json.decode(accountJson);
      
      // Actualizar solo la cuenta afectada
      if (data['title'] == accountName) {
        double currentBalance;
        // Manejar el caso donde balance puede ser String o double
        if (data['balance'] is String) {
          currentBalance = double.tryParse(data['balance']) ?? 0.0;
        } else {
          currentBalance = (data['balance'] is double) ? data['balance'] : 0.0;
        }
        
        // Aplicar el ajuste según el tipo de transacción
        if (wasIncome) {
          currentBalance -= amount; // Revertir ingreso
        } else {
          currentBalance += amount; // Revertir gasto
        }
        
        // Guardar el balance respetando el tipo original
        if (data['balance'] is String) {
          data['balance'] = currentBalance.toString();
        } else {
          data['balance'] = currentBalance;
        }
        
        updated = true;
      }
      
      // Añadir la cuenta (modificada o no) a la lista
      accounts.add(data);
    }
    
    // Guardar TODAS las cuentas independientemente de si hubo actualización
    List<String> updatedAccountsData = accounts.map((data) => json.encode(data)).toList();
    await prefs.setStringList('accounts', updatedAccountsData);
    
    // Actualizar el saldo global para reflejar el cambio
    await _updateAvailableBalance();
  }
}
}