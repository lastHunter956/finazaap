// Reemplaza las importaciones conflictivas por estas líneas:
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
import 'package:finazaap/widgets/show_transaction_options.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:collection';
import 'package:finazaap/utils/currency_helper.dart';

// Importa todas las clases necesarias, ocultando AccountItem para evitar conflictos
// Importa todas las clases necesarias
import 'package:finazaap/Screens/selecctaccount.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/add_expense.dart';

// Añadir esta importación al inicio del archivo
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/Screens/daily_transactions.dart';
import 'package:home_widget/home_widget.dart';
import 'package:finazaap/Screens/ai_chat_screen.dart';
import 'package:finazaap/services/widget_service.dart';
import 'dart:async'; // Necesario para StreamSubscription
import 'package:gradient_borders/gradient_borders.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/features/notifications/presentation/screens/pending_transactions_screen.dart';

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

  // Mapa para almacenar colores de categorías
  Map<String, int> _categoryColors = {};

  // Estado para fechas expandidas
  Set<String> _expandedDates = {};

  // Listeners para limpiar recursos
  late final VoidCallback _boxListener;
  late final ValueListenable<Box<Add_data>> _boxListenable;
  StreamSubscription? _widgetSubscription;
  Timer? _widgetRefreshTimer;
  Map<String, List<Add_data>>? _groupedTransactionsCache;

  @override
  void initState() {
    super.initState();
    _loadCategoryMetadata(); // Cargar colores de categorías
    _updateAvailableBalance(); // Llamada inicial
    
    // Expandir la fecha actual por defecto
    final now = DateTime.now();
    final todayKey = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    _expandedDates.add(todayKey);

    // Definir y registrar listener (guardamos referencia para removeListener correcto)
    _boxListenable = box.listenable();
    _boxListener = () {
      if (mounted) {
        _groupedTransactionsCache = null;
        setState(() {});
        _updateAvailableBalance();
        _loadCategoryMetadata();
      }
    };
    _boxListenable.addListener(_boxListener);

    // Check for Widget Launch
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_handleWidgetLaunch);
    
    // Listen for Widget Launch while app is running
    _widgetSubscription = HomeWidget.widgetClicked.listen(_handleWidgetLaunch);
  }

  void _handleWidgetLaunch(Uri? uri) {
    if (uri?.scheme == 'finazaap' && uri?.host == 'add_operation') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AddExpenseScreen()),
      );
    }
  }

  @override
  void dispose() {
    // Limpiar listeners para evitar memory leaks
    _widgetRefreshTimer?.cancel();
    if (_widgetSubscription != null) _widgetSubscription!.cancel();
    _boxListenable.removeListener(_boxListener);
    availableBalanceNotifier.dispose();
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
        transaction.safeDate.month == _selectedMonth && 
        transaction.safeDate.year == _selectedYear
      ).toList();
    }
    
    return transactions;
  }

  // Cargar metadatos de categorías (colores e iconos)
  Future<void> _loadCategoryMetadata() async {
    try {
      final incomeCats = await CategoryService.getCategoriesWithMetadata('Income');
      final expenseCats = await CategoryService.getCategoriesWithMetadata('Expenses');
      
      final Map<String, int> colors = {};
      
      for (var cat in incomeCats) {
        colors[cat['text']] = cat['color'];
      }
      for (var cat in expenseCats) {
        colors[cat['text']] = cat['color'];
      }
      
      if (mounted) {
        setState(() {
          _categoryColors = colors;
        });
      }
    } catch (e) {
      debugPrint('Error loading category metadata: $e');
    }
  }

  // Balance contable: suma de ingresos - gastos (excluyendo transferencias)
  double accountingBalance() {
    final transactions = getTransactionsFilteredByDateOnly(); // Solo filtrar por fecha
    double balance = 0.0;
    
    for (var item in transactions) {
      if (item.IN == 'Income') {
        // Sumar ingresos
        balance += (double.tryParse(item.safeAmount) ?? 0.0);
      } else if (item.IN == 'Expenses') {
        // Restar gastos
        balance -= (double.tryParse(item.safeAmount) ?? 0.0);
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
        sum += (double.tryParse(item.safeAmount) ?? 0.0);
      } else if (item.IN == 'Expenses') {
        sum += (double.tryParse(item.safeAmount) ?? 0.0); // También suma para mostrar el total de ambos
      }
    }
    
    return sum;
  }

  // Total de ingresos (respeta filtros)
  double income() {
    final transactions = getTransactionsFilteredByDateOnly() // Solo filtrar por fecha
      .where((item) => item.IN == 'Income');
    return transactions.fold(0.0, (sum, item) => 
      sum + (double.tryParse(item.safeAmount) ?? 0.0)
    );
  }

  // Total de gastos (respeta filtros)
  double expenses() {
    final transactions = getTransactionsFilteredByDateOnly() // Solo filtrar por fecha
      .where((item) => item.IN == 'Expenses');
    return transactions.fold(0.0, (sum, item) => 
      sum + (double.tryParse(item.safeAmount) ?? 0.0)
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
        transaction.safeDate.month == _selectedMonth && 
        transaction.safeDate.year == _selectedYear
      ).toList();
    }
    
    return transactions;
  }

  Future<void> _updateAvailableBalance() async {
    final prefs = await PrefsManager.instance;
    final List<String>? accountsData = prefs.getStringList('accounts');

    if (accountsData != null) {
      double totalBalance = 0.0;
      for (final accountJson in accountsData) {
        final Map<String, dynamic> data = json.decode(accountJson);
        final bool includeInTotal = data['includeInTotal'] ?? true;
        final bool isCreditCard = data['subtitle'] == 'Tarjeta de Crédito';
        if (includeInTotal && !isCreditCard) {
          final raw = data['balance'];
          double balance;
          if (raw is String) {
            balance = double.tryParse(raw) ?? 0.0;
          } else if (raw is double) {
            balance = raw;
          } else if (raw is int) {
            balance = raw.toDouble();
          } else {
            balance = 0.0;
          }
          totalBalance += balance;
        }
      }
      availableBalanceNotifier.value = totalBalance;
      _widgetRefreshTimer?.cancel();
      _widgetRefreshTimer = Timer(const Duration(milliseconds: 500), () {
        WidgetService.refreshWidgetFromData();
      });
    }
  }

  // Método para recibir la selección de fecha
  void _onDateSelected(int month, int year) {
    setState(() {
      _selectedMonth = month;
      _selectedYear = year;
      _filterByDate = true;
      _groupedTransactionsCache = null;
      
      // Actualizar inmediatamente los valores en la UI
      // No es necesario llamar a estos métodos explícitamente
      // pues setState() ya reconstruirá el widget y ejecutará los cálculos
    });
  }

  Future<void> _openPendingInbox() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PendingTransactionsScreen(
          notifier: NotificationPipelineService.instance.pendingNotifier,
        ),
      ),
    );
    if (mounted) {
      setState(() {});
      await _updateAvailableBalance();
      await _loadCategoryMetadata();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Permitir salir por defecto, ajustar si se requiere confirmación
      onPopInvokedWithResult: (didPop, result) {
        // Lógica adicional si es necesario
      },
      child: Scaffold(
        backgroundColor: context.appTheme.primaryBackground,
        body: Column(
          children: [
            MoneoHeaderBar.primaryTab(
              title: 'Transacciones',
              actions: [
                ListenableBuilder(
                  listenable:
                      NotificationPipelineService.instance.pendingNotifier,
                  builder: (context, _) {
                    final count = NotificationPipelineService
                        .instance.pendingNotifier.count;
                    if (count <= 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: MoneoPressableScale(
                        child: InkWell(
                          key: const Key('home_pending_inbox_appbar_button'),
                          onTap: _openPendingInbox,
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: context.appTheme.accent
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.appTheme.accent
                                        .withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.move_to_inbox_rounded,
                                  color: context.appTheme.accent,
                                  size: 22,
                                ),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: context.appTheme.accent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  constraints: const BoxConstraints(minWidth: 18),
                                  child: Text(
                                    count > 99 ? '99+' : '$count',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: context.appTheme.buttonForeground,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                MoneoPressableScale(
                  child: InkWell(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const AiChatScreen()),
                      );
                      if (mounted) {
                        setState(() {});
                        await _updateAvailableBalance();
                        await _loadCategoryMetadata();
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.isDiurno &&
                                !LiquidGlassSurface.shouldReduceEffects(context)
                            ? null
                            : context.appTheme.accent.withValues(alpha: 0.12),
                        gradient: context.isDiurno &&
                                !LiquidGlassSurface.shouldReduceEffects(context)
                            ? const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFFFFFFFF), Color(0xFFEAF2FF)],
                              )
                            : null,
                        borderRadius: BorderRadius.circular(
                            context.isDiurno ? 14 : 12),
                        border: context.isDiurno &&
                                !LiquidGlassSurface.shouldReduceEffects(context)
                            ? GradientBoxBorder(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white,
                                    context.appTheme.accent
                                        .withValues(alpha: 0.45),
                                  ],
                                ),
                                width: 1.4,
                              )
                            : Border.all(
                                color: context.appTheme.accent
                                    .withValues(alpha: 0.4),
                                width: 1.5,
                              ),
                        boxShadow: [
                          BoxShadow(
                            color: context.appTheme.accent.withValues(
                                alpha: context.isDiurno ? 0.18 : 0.15),
                            blurRadius: context.isDiurno ? 12 : 10,
                            offset: context.isDiurno
                                ? const Offset(0, 3)
                                : Offset.zero,
                            spreadRadius: context.isDiurno ? 0 : 1,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.chat_rounded,
                        color: context.appTheme.accent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _boxListenable,
                builder: (context, value, child) {
                  final transactionsByDate =
                      _groupedTransactionsCache ??= _getTransactionsGroupedByDate();

                  return CustomScrollView(
                    slivers: [
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  SliverToBoxAdapter(
                    child: ListenableBuilder(
                      listenable:
                          NotificationPipelineService.instance.pendingNotifier,
                      builder: (context, _) {
                        final count = NotificationPipelineService
                            .instance.pendingNotifier.count;
                        if (count <= 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Material(
                            key: const Key('home_pending_notifications_banner'),
                            color: context.appTheme.cardBackground,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: _openPendingInbox,
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: context.appTheme.accent
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: context.appTheme.accent
                                            .withValues(alpha: 0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.notifications_active_rounded,
                                        color: context.appTheme.accent,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            count == 1
                                                ? '1 movimiento por revisar'
                                                : '$count movimientos por revisar',
                                            style: TextStyle(
                                              color:
                                                  context.appTheme.textPrimary,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'Detectados en tus notificaciones bancarias',
                                            style: TextStyle(
                                              color: context
                                                  .appTheme.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: context.appTheme.accent,
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
                            _groupedTransactionsCache = null;
                          });
                        },
                        onShowExpenses: () {
                          setState(() {
                            filter = 'Gastos';
                            _groupedTransactionsCache = null;
                          });
                        },
                        onShowIncome: () {
                          setState(() {
                            filter = 'Ingresos';
                            _groupedTransactionsCache = null;
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
                      child: Text(
                        'Historial de transacciones',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: context.appTheme.textPrimary,
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
                        final dailyIncome = _calculateDailyBalance(dailyTransactions);
                        
                        // Construimos la sección de fecha con sus transacciones
                        return _buildDateSection(dateKey, dailyIncome, dailyTransactions);
                      },
                      childCount: transactionsByDate.length,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MoneoLayoutMetrics.scrollBottomPadding(
                        context,
                        hasFab: true,
                      ).bottom,
                    ),
                  )
                ],
              );
            },
          ),
            ),
          ],
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
    final Map<String, DateTime> keyDates = {};
    
    for (var transaction in transactions) {
      final date = transaction.safeDate;
      // Creamos una clave de fecha: "dd/mm/yyyy"
      final dateKey = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
      
      // Si la fecha no existe como clave, la inicializamos
      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
        keyDates[dateKey] = DateTime(date.year, date.month, date.day);
      }
      
      // Añadimos la transacción al grupo correspondiente
      grouped[dateKey]!.add(transaction);
    }
    
    // Ordenamos las claves por fecha (más reciente primero)
    final sortedKeys = grouped.keys.toList()
      ..sort((a, b) => keyDates[b]!.compareTo(keyDates[a]!));
    
    // Ordenar las transacciones dentro de cada día (más reciente primero)
    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.safeDate.compareTo(a.safeDate));
    }
    
    // Creamos un nuevo mapa con las claves ordenadas
    final LinkedHashMap<String, List<Add_data>> sortedGrouped = LinkedHashMap();
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  // Calcular el total de ingresos del día
  double _calculateDailyBalance(List<Add_data> transactions) {
  double balance = 0.0;
  
  for (var transaction in transactions) {
    if (transaction.safeType == 'Income') {
      // Sumar ingresos
      balance += (double.tryParse(transaction.safeAmount) ?? 0.0);
    } else if (transaction.safeType == 'Expenses') {
      // Restar gastos
      balance -= (double.tryParse(transaction.safeAmount) ?? 0.0);
    }
    // Las transferencias no afectan el balance contable
  }
  
  return balance;
}

  // Construir la sección de fecha con sus transacciones
  Widget _buildDateSection(String dateKey, double dailyIncome, List<Add_data> transactions) {
    bool isExpanded = _expandedDates.contains(dateKey);

    // Calcular totales separados para el resumen
    double totalIncome = 0;
    double totalExpense = 0;
    for (var t in transactions) {
      double amount = double.tryParse(t.safeAmount) ?? 0;
      if (t.safeType == 'Income') {
        totalIncome += amount;
      } else if (t.IN == 'Expenses') {
        totalExpense += amount;
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado de fecha y total - CON GESTO TÁCTIL
          GestureDetector(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedDates.remove(dateKey);
                } else {
                  _expandedDates.add(dateKey);
                }
              });
            },
            behavior: HitTestBehavior.opaque, // Para facilitar el toque
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Fecha formateada
                      Text(
                        dateKey,
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Icono de flecha
                      Icon(
                        isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        color: context.appTheme.textSecondary,
                        size: 18,
                      ),
                    ],
                  ),
                  // Total del día
                  Text(
                    CurrencyHelper.format(dailyIncome),
                    style: TextStyle(
                      // Color dinámico según si es positivo (ingreso neto) o negativo (gasto neto)
                      color: dailyIncome >= 0 
                          ? context.appTheme.income // Verde
                          : context.appTheme.expense, // Rojo claro
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // MOSTRAR LISTA O RESUMEN SEGÚN ESTADO
          if (isExpanded)
            // === LISTA DE TRANSACCIONES (EXPANDIDO) ===
            Container(
              decoration: BoxDecoration(
                color: context.appTheme.cardBackground, // Color aplicado al contenedor principal
                borderRadius: BorderRadius.circular(context.isDiurno ? 18 : 16),
                border: context.isDefaultDark
                    ? null
                    : Border.all(
                        color: context.appTheme.borderSubtle,
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness == Brightness.light ? 0.06 : 0.1,
                    ),
                    blurRadius: context.isDiurno ? 12 : 4,
                    offset: Offset(0, context.isDiurno ? 4 : 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(context.isDiurno ? 18 : 16),
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
                            Divider(
                              color: context.isDefaultDark
                                  ? Colors.grey
                                  : context.appTheme.borderSubtle,
                              height: 1,
                              thickness: context.isDefaultDark ? 0.2 : 0.8,
                              indent: 60, // Indentación para que el divisor empiece después del icono
                              endIndent: 10,
                            ),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            )

          else
            // === TARJETA RESUMEN (CONTRAÍDO) ===
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DailyTransactionsScreen(
                      dateString: dateKey,
                      transactions: transactions,
                      dailyIncome: totalIncome,
                      dailyExpense: totalExpense,
                    ),
                  ),
                ).then((_) {
                  // Al volver, refrescar para mostrar cambios
                  setState(() {});
                  _updateAvailableBalance();
                });
              },
              borderRadius: BorderRadius.circular(context.isDiurno ? 18 : 16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.appTheme.cardBackground,
                  borderRadius: BorderRadius.circular(context.isDiurno ? 18 : 16),
                  border: Border.all(
                    color: context.appTheme.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: Theme.of(context).brightness == Brightness.light ? 0.06 : 0.1,
                      ),
                      blurRadius: context.isDiurno ? 12 : 4,
                      offset: Offset(0, context.isDiurno ? 4 : 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Ingresos (Fila superior)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (context.isDefaultDark
                                    ? Colors.green
                                    : context.appTheme.income)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded, // Ingreso (entrada)
                            color: context.isDefaultDark
                                ? Colors.green
                                : context.appTheme.income,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Ingresos",
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                CurrencyHelper.format(totalIncome),
                                style: TextStyle(
                                  color: context.appTheme.income,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    // Separador horizontal
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Divider(
                        color: context.appTheme.borderSubtle,
                        height: 1,
                      ),
                    ),

                    // Gastos (Fila inferior)
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (context.isDefaultDark
                                    ? Colors.redAccent
                                    : context.appTheme.expense)
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded, // Gasto (salida)
                            color: context.isDefaultDark
                                ? Colors.redAccent
                                : context.appTheme.expense,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Gastos",
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                CurrencyHelper.format(totalExpense),
                                style: TextStyle(
                                  color: context.appTheme.expense,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
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
      mainTitle = history.safeDetail.isNotEmpty 
          ? "Transferencia - ${history.safeDetail}" 
          : "Transferencia";
    } else {
      mainTitle = history.safeDetail.isNotEmpty 
          ? "${history.safeCategory} - ${history.safeDetail}" 
          : history.safeCategory;
    }
    
    // Determinar qué icono mostrar
    IconData transactionIcon;
    if (isTransfer) {
      transactionIcon = Icons.sync_alt;
    } else {
      transactionIcon = AppIcons.getIcon(history.safeIconCode);
    }

    // Envolver en InkWell para detectar toques y mostrar efecto visual
    return InkWell(
      onTap: () => showTransactionOptions(history, context, _editTransaction, _confirmDeleteTransaction),
      splashColor: Colors.blueAccent.withOpacity(0.1),
      highlightColor: Colors.blueAccent.withOpacity(0.05),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icono con fondo coloreado, borde claro y sombra oscura
            Container(
              decoration: BoxDecoration(
                color: isTransfer
                    ? Colors.blueAccent
                    : (isIncome ? Colors.green : Colors.redAccent),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3), // Borde claro para contraste
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3), // Sombra oscura estándar
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(
                transactionIcon,
                size: 22,
                color: Colors.white,
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
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.textPrimary,
                      height: 1.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Cuenta o ruta de transferencia
                  Text(
                    isTransfer 
                        ? (history.explain ?? '')  // Ruta de transferencia: "Cuenta origen > Cuenta destino"
                        : history.safeAccount,     // Nombre de la cuenta
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            
            // Monto y detalles de tarjeta (Columna derecha)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyHelper.formatString(history.safeAmount),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isTransfer 
                          ? context.appTheme.textSecondary 
                          : (isIncome
                              ? context.appTheme.income
                              : context.appTheme.expense),
                    ),
                  ),

                  // Detalles de tarjeta de crédito (si existen)
                  if (history.installments != null && history.installments != '1' && history.installments!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (context.isDefaultDark
                                ? Colors.blueAccent
                                : context.appTheme.accent)
                            .withValues(alpha: context.isDefaultDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (context.isDefaultDark
                                  ? Colors.blueAccent
                                  : context.appTheme.accent)
                              .withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        '${history.installments} cuotas',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.isDefaultDark
                              ? Colors.lightBlueAccent
                              : context.appTheme.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  
                  if (history.isInterestFree == true) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (context.isDefaultDark
                                ? Colors.greenAccent
                                : context.appTheme.income)
                            .withValues(alpha: context.isDefaultDark ? 0.2 : 0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (context.isDefaultDark
                                  ? Colors.greenAccent
                                  : context.appTheme.income)
                              .withValues(alpha: 0.4),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        'Sin interés',
                        style: TextStyle(
                          fontSize: 10,
                          color: context.isDefaultDark
                              ? Colors.greenAccent
                              : context.appTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
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

void _editTransaction(Add_data transaction) async {
  try {
    // Verificar si hay referencias eliminadas antes de abrir la pantalla de edición
    final deletedRefs = await CategoryService.checkForDeletedReferences(transaction);
    
    // Si hay categorías o cuentas eliminadas, mostrar advertencia
    if (deletedRefs['hasDeletedCategory'] == true || deletedRefs['hasDeletedAccount'] == true) {
      bool shouldContinue = await _showDeletedReferenceWarning(
        transaction, 
        deletedRefs['hasDeletedCategory'] ?? false,
        deletedRefs['hasDeletedAccount'] ?? false
      );
      
      if (!shouldContinue) {
        // Usuario eligió eliminar en lugar de editar
        await _deleteTransaction(transaction);
        return;
      }
    }
    
    // Continuar con la edición normalmente...
    int? transactionKey = _findTransactionKey(transaction);
    
    if (transactionKey == null) {
      throw Exception('No se pudo encontrar la transacción en la base de datos');
    }
    
    // Añadir depuración adicional
    debugPrint('🔍 Editando transacción: ${transaction.explain}');
    if (transaction.IN == 'Income' || transaction.IN == 'Expenses') {
      debugPrint('📊 Datos clave: Cuenta=${transaction.name}, Categoría=${transaction.explain}');
    } else {
      debugPrint('📊 Datos clave: Ruta=${transaction.explain}');
    }
    
    // Verificar y corregir datos antes de editar
    if (transaction.IN == 'Income') {
      await _verifyDataBeforeEdit(transaction);
    } else if (transaction.IN == 'Expenses') {
      await _verifyDataBeforeEdit(transaction);
    }
    
    // Crear la pantalla de edición adecuada según el tipo
    Widget editScreen;
    
    if (transaction.IN == 'Transfer') {
      editScreen = TransferScreen(
        isEditing: true,
        transaction: transaction,
        transactionKey: transactionKey,
        onTransactionUpdated: () {
          setState(() {});
          _updateAvailableBalance();
          // Sincronizar saldos después de la edición
          TransactionService.syncAccountBalances();
        },
      );
    } else if (transaction.IN == 'Income') {
      editScreen = Add_Screen(
        isEditing: true,
        transaction: transaction,
        transactionKey: transactionKey,
        onTransactionUpdated: () {
          setState(() {});
          _updateAvailableBalance();
          TransactionService.syncAccountBalances();
        },
      );
    } else { // Expenses
      editScreen = AddExpenseScreen(
        isEditing: true,
        transaction: transaction,
        transactionKey: transactionKey,
        onTransactionUpdated: () {
          setState(() {});
          _updateAvailableBalance();
          TransactionService.syncAccountBalances();
        },
      );
    }
    
    // Navegar a la pantalla de edición
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => editScreen),
    );
    
  } catch (e) {
    debugPrint('❌ Error al preparar edición de transacción: $e');
    AlertHelper.error(context, 'Error al editar: $e');
  }
}

// Método auxiliar para verificar y corregir datos antes de editar
Future<void> _verifyDataBeforeEdit(Add_data transaction) async {
  final prefs = await SharedPreferences.getInstance();
  
  if (transaction.IN == 'Income') {
    // Verificar categorías de ingresos
    List<String> savedCategories = prefs.getStringList('income_categories') ?? [];
    
    // Si la categoría no existe, añadirla a la lista permanente
    if (!savedCategories.contains(transaction.explain)) {
      debugPrint('⚠️ Reparando: Categoría de ingreso no encontrada: ${transaction.explain}');
      
      // Verificar que no esté duplicada en otra forma (mayúsculas/minúsculas)
      bool isDuplicate = false;
      String duplicateOf = "";
      
      for (final category in savedCategories) {
        if (category.toLowerCase() == (transaction.explain?.toLowerCase() ?? '')) {
          isDuplicate = true;
          duplicateOf = category;
          break;
        }
      }
      
      if (isDuplicate) {
        debugPrint('⚠️ Es un duplicado de: $duplicateOf - Actualizando transacción');
        transaction.explain = duplicateOf; // Actualizar al nombre "canónico"
      } else {
        // Agregar como nueva categoría
        savedCategories.add(transaction.explain ?? '');
        await prefs.setStringList('income_categories', savedCategories);
        debugPrint('✅ Categoría agregada: ${transaction.explain}');
      }
    }
    
    // Verificar también la cuenta
    List<String>? accountsData = prefs.getStringList('accounts') ?? [];
    List<String> accountNames = accountsData
        .map((data) => (json.decode(data) as Map<String, dynamic>)['title'] as String)
        .toList();
    
    if (!accountNames.contains(transaction.name)) {
      debugPrint('⚠️ Advertencia: La cuenta ${transaction.name} ya no existe');
    }
  } 
  else if (transaction.IN == 'Expenses') {
    // Verificar categorías de gastos
    List<String> savedCategories = prefs.getStringList('expense_categories') ?? [];
    
    // Si la categoría no existe, añadirla a la lista permanente
    if (!savedCategories.contains(transaction.explain)) {
      debugPrint('⚠️ Reparando: Categoría de gasto no encontrada: ${transaction.explain}');
      
      // Verificar que no esté duplicada en otra forma (mayúsculas/minúsculas)
      bool isDuplicate = false;
      String duplicateOf = "";
      
      for (final category in savedCategories) {
        if (category.toLowerCase() == (transaction.explain?.toLowerCase() ?? '')) {
          isDuplicate = true;
          duplicateOf = category;
          break;
        }
      }
      
      if (isDuplicate) {
        debugPrint('⚠️ Es un duplicado de: $duplicateOf - Actualizando transacción');
        transaction.explain = duplicateOf; // Actualizar al nombre "canónico"
      } else {
        // Agregar como nueva categoría
        savedCategories.add(transaction.explain ?? '');
        await prefs.setStringList('expense_categories', savedCategories);
        debugPrint('✅ Categoría de gasto agregada: ${transaction.explain}');
      }
    }
    
    // Verificar también la cuenta
    List<String>? accountsData = prefs.getStringList('accounts') ?? [];
    List<String> accountNames = accountsData
        .map((data) => (json.decode(data) as Map<String, dynamic>)['title'] as String)
        .toList();
    
    if (!accountNames.contains(transaction.name)) {
      debugPrint('⚠️ Advertencia: La cuenta ${transaction.name} ya no existe');
    }
  }
  else if (transaction.IN == 'Transfer') {
    // Verificar cuentas de origen y destino en transferencias
    final parts = (transaction.explain ?? '').split(' > ');
    if (parts.length == 2) {
      final sourceAccount = parts[0].trim();
      final destAccount = parts[1].trim();
      
      List<String>? accountsData = prefs.getStringList('accounts') ?? [];
      List<String> accountNames = accountsData
          .map((data) => (json.decode(data) as Map<String, dynamic>)['title'] as String)
          .toList();
      
      if (!accountNames.contains(sourceAccount)) {
        debugPrint('⚠️ Advertencia: La cuenta de origen ${sourceAccount} ya no existe');
      }
      
      if (!accountNames.contains(destAccount)) {
        debugPrint('⚠️ Advertencia: La cuenta de destino ${destAccount} ya no existe');
      }
    }
  }
}

// Añadir este nuevo método para mostrar la advertencia
Future<bool> _showDeletedReferenceWarning(
  Add_data transaction,
  bool hasDeletedCategory,
  bool hasDeletedAccount
) async {
  String message = 'Lo sentimos, pero hemos detectado que eliminó ';
  
  if (hasDeletedCategory && hasDeletedAccount) {
    message += 'una categoría y una cuenta asociadas a este registro.';
  } else if (hasDeletedCategory) {
    message += 'una categoría asociada a este registro.';
  } else {
    message += 'una cuenta asociada a este registro.';
  }
  
  message += ' En caso que desee editar, no contará con la ';
  
  if (hasDeletedCategory && hasDeletedAccount) {
    message += 'categoría ni cuenta eliminada.';
  } else if (hasDeletedCategory) {
    message += 'categoría eliminada.';
  } else {
    message += 'cuenta eliminada.';
  }
  
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: context.appTheme.secondaryCardBackground,
      title: const Text(
        '⚠️ Referencia eliminada detectada',
        style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
      ),
      content: Text(
        message,
        style: TextStyle(color: context.appTheme.textPrimary),
      ),
      actions: [
        // Botón rojo de eliminar
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.red,
          ),
          onPressed: () {
            Navigator.of(context).pop(false); // No continuar con la edición
            _confirmDeleteTransaction(transaction); // Mostrar diálogo de eliminación
          },
          child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
        ),
        
        // Botón blanco de editar
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: context.appTheme.borderSubtle),
          ),
          onPressed: () {
            Navigator.of(context).pop(true); // Continuar con la edición
          },
          child: Text('Editar de todas formas', style: TextStyle(color: context.appTheme.textPrimary)),
        ),
      ],
    ),
  );
  
  // Retorna true si el usuario eligió editar, false si eligió eliminar
  return result ?? false;
}

  // Método para confirmar eliminación
  void _confirmDeleteTransaction(Add_data transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.secondaryCardBackground,
        title: Text('Confirmar eliminación', style: TextStyle(color: context.appTheme.textPrimary)),
        content: Text(
          '¿Estás seguro que deseas eliminar esta transacción? Esta acción no se puede deshacer.',
          style: TextStyle(color: context.appTheme.textSecondary),
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
Future<void> _deleteTransaction(Add_data transaction) async {
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
    AlertHelper.success(context, 'Transacción eliminada');

    // Sincronizar saldos después de eliminar
    await TransactionService.syncAccountBalances();
  } catch (e) {
    print('Error al eliminar transacción: $e');
    AlertHelper.error(context, 'Error al eliminar: $e');
  }
}

// Añadir este método utilitario
int? _findTransactionKey(Add_data transaction) {
  try {
    for (int i = 0; i < box.length; i++) {
      final current = box.getAt(i);
      if (current != null && 
          current.datetime == transaction.datetime &&
          current.amount == transaction.amount &&
          current.name == transaction.name &&
          current.IN == transaction.IN) {
        return box.keyAt(i);
      }
    }
    return null;
  } catch (e) {
    debugPrint('❌ Error buscando transacción: $e');
    return null;
  }
}
}