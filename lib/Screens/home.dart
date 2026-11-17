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
import 'package:finazaap/Screens/pin_code_screen.dart';
import 'package:finazaap/providers/pin_provider.dart';

// Añadir esta importación al inicio del archivo
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/data/monthly_summary_cache.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/core/prefs_manager.dart';
import 'package:finazaap/Screens/daily_transactions.dart';
import 'package:home_widget/home_widget.dart';
import 'package:finazaap/Screens/ai_chat_screen.dart';
import 'package:finazaap/services/widget_service.dart';
import 'dart:async'; // Necesario para StreamSubscription
import 'package:gradient_borders/gradient_borders.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';
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

  // Notificador de saldo disponible
  final ValueNotifier<double> availableBalanceNotifier =
      ValueNotifier<double>(0.0);
  final ValueNotifier<Map<String, double>> availableBalancesByCurrencyNotifier =
      ValueNotifier<Map<String, double>>({});

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
        MonthlySummaryCache.instance.invalidate();
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

  Future<void> _handleWidgetLaunch(Uri? uri) async {
    if (uri?.scheme != 'finazaap' || uri?.host != 'add_operation') {
      return;
    }
    if (!mounted) return;

    final pinProvider = PinProvider();
    await pinProvider.ensureInitialized();
    final isPinEnabled = pinProvider.isPinEnabled;
    if (!mounted) return;

    if (!isPinEnabled) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AddExpenseScreen()),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinCodeScreen(
          mode: PinMode.verify,
          onSuccess: (ctx) {
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(builder: (context) => AddExpenseScreen()),
            );
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Limpiar listeners para evitar memory leaks
    _widgetRefreshTimer?.cancel();
    _widgetSubscription?.cancel().catchError((_) {});
    _boxListenable.removeListener(_boxListener);
    availableBalanceNotifier.dispose();
    availableBalancesByCurrencyNotifier.dispose();
    super.dispose();
  }

  // Nuevo método que obtiene TODAS las transacciones sin filtros en O(1)
  List<Add_data> getAllTransactions() {
    return MonthlySummaryCache.instance.getAllTransactions();
  }

  // Añadir un nuevo método que solo filtra por fecha, ignorando el tipo de filtro
  List<Add_data> getTransactionsFilteredByDateOnly() {
    if (_filterByDate) {
      return MonthlySummaryCache.instance
          .getTransactionsForMonth(_selectedYear, _selectedMonth);
    }
    return MonthlySummaryCache.instance.getAllTransactions();
  }

  // Cargar metadatos de categorías (colores e iconos)
  Future<void> _loadCategoryMetadata() async {
    try {
      final incomeCats = await CategoryService.getCategoriesWithMetadata('Income');
      final expenseCats = await CategoryService.getCategoriesWithMetadata('Expenses');
      
      final Map<String, int> colors = {};
      
      for (var cat in incomeCats) {
        if (cat['text'] is String && cat['color'] is int) {
          colors[cat['text'] as String] = cat['color'] as int;
        }
      }
      for (var cat in expenseCats) {
        if (cat['text'] is String && cat['color'] is int) {
          colors[cat['text'] as String] = cat['color'] as int;
        }
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

  String _selectedPeriodLabel() {
    final date = DateTime(_selectedYear, _selectedMonth);
    try {
      return DateFormat.yMMMM('es').format(date);
    } catch (_) {
      return '${_selectedMonth.toString().padLeft(2, '0')}/$_selectedYear';
    }
  }

  String _formatDateSectionLabel(String dateKey) {
    try {
      final parts = dateKey.split('/');
      if (parts.length != 3) return dateKey;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final date = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      if (date == today) {
        final compact =
            DateFormat('dd MMM', 'es').format(date).replaceAll('.', '');
        return 'Hoy · $compact';
      }
      if (date == yesterday) {
        final compact =
            DateFormat('dd MMM', 'es').format(date).replaceAll('.', '');
        return 'Ayer · $compact';
      }
      final full =
          DateFormat('EEE dd MMM yyyy', 'es').format(date).replaceAll('.', '');
      if (full.isEmpty) return dateKey;
      return full[0].toUpperCase() + full.substring(1);
    } catch (_) {
      return dateKey;
    }
  }

  String _formatTime(DateTime date) {
    try {
      return DateFormat('HH:mm', 'es').format(date);
    } catch (_) {
      return DateFormat('HH:mm').format(date);
    }
  }

  Future<void> _openRegisterTransaction() async {
    final Widget target = filter == 'Ingresos'
        ? const Add_Screen()
        : const AddExpenseScreen();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => target),
    );
    if (mounted) {
      MonthlySummaryCache.instance.invalidate();
      _groupedTransactionsCache = null;
      setState(() {});
      await _updateAvailableBalance();
      await _loadCategoryMetadata();
    }
  }

  // Balance contable: suma de ingresos - gastos (excluyendo transferencias) en O(1)
  double accountingBalance() {
    final summary = _filterByDate
        ? MonthlySummaryCache.instance
            .getMonthSummary(_selectedYear, _selectedMonth)
        : MonthlySummaryCache.instance.getAllTimeSummary();
    return summary.netSavings;
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

  // Total de ingresos (respeta filtros) en O(1)
  double income() {
    final summary = _filterByDate
        ? MonthlySummaryCache.instance
            .getMonthSummary(_selectedYear, _selectedMonth)
        : MonthlySummaryCache.instance.getAllTimeSummary();
    return summary.totalIncome;
  }

  // Total de gastos (respeta filtros) en O(1)
  double expenses() {
    final summary = _filterByDate
        ? MonthlySummaryCache.instance
            .getMonthSummary(_selectedYear, _selectedMonth)
        : MonthlySummaryCache.instance.getAllTimeSummary();
    return summary.totalExpenses;
  }

  List<Add_data> getFilteredTransactions() {
    final String? typeFilter;
    if (filter == 'Gastos') {
      typeFilter = 'Expenses';
    } else if (filter == 'Ingresos') {
      typeFilter = 'Income';
    } else {
      typeFilter = null;
    }

    if (_filterByDate) {
      return MonthlySummaryCache.instance.getTransactionsForMonth(
        _selectedYear,
        _selectedMonth,
        typeFilter: typeFilter,
      );
    }

    return MonthlySummaryCache.instance.getAllTransactions(
      typeFilter: typeFilter,
    );
  }

  Future<void> _updateAvailableBalance() async {
    final prefs = await PrefsManager.instance;
    final List<String>? accountsData = prefs.getStringList('accounts');

    if (accountsData != null) {
      final MultiCurrencyTotals totals = MultiCurrencyTotals();
      for (final accountJson in accountsData) {
        final Map<String, dynamic> data = json.decode(accountJson);
        final bool includeInTotal = data['includeInTotal'] ?? true;
        final bool isCreditCard = data['subtitle'] == 'Tarjeta de Crédito';
        if (includeInTotal && !isCreditCard) {
          final raw = data['balance'];
          double balance;
          if (raw is String) {
            balance = double.tryParse(raw) ??
                double.tryParse(CurrencyHelper.cleanAmountString(raw)) ??
                0.0;
          } else if (raw is double) {
            balance = raw;
          } else if (raw is int) {
            balance = raw.toDouble();
          } else {
            balance = 0.0;
          }
          final String? accountCurrency = data['currencyCode']?.toString();
          totals.add(accountCurrency, balance);
        }
      }
      availableBalancesByCurrencyNotifier.value = totals.byCurrency;
      availableBalanceNotifier.value = totals.totalFor(CurrencyHelper.currencyCode);
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
                      padding: const EdgeInsets.only(right: 4),
                      child: Semantics(
                        button: true,
                        label: 'Bandeja de pendientes, $count por revisar',
                        excludeSemantics: true,
                        child: Tooltip(
                          message: 'Pendientes por revisar',
                          child: MoneoPressableScale(
                            child: InkWell(
                              key: const Key('home_pending_inbox_appbar_button'),
                              onTap: _openPendingInbox,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: Center(
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
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Semantics(
                  button: true,
                  label: 'Asistente IA Moneo',
                  excludeSemantics: true,
                  child: Tooltip(
                    message: 'Asistente IA Moneo',
                    child: MoneoPressableScale(
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
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          child: Center(
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
                                boxShadow: context.isDiurno
                                    ? [
                                        BoxShadow(
                                          color: context.appTheme.accent
                                              .withValues(alpha: 0.14),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                Icons.chat_rounded,
                                color: context.appTheme.accent,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
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
                        availableBalancesByCurrencyNotifier:
                            availableBalancesByCurrencyNotifier,
                        accountingBalance: accountingBalance(),
                        totalExpenses: expenses(),
                        totalIncome: income(),
                        onManageAccounts: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => MyHomePage(
                                      onBalanceUpdated: (double balance) {
                                        availableBalanceNotifier.value =
                                            balance;
                                        _updateAvailableBalance();
                                      },
                                    )),
                          );
                          if (mounted) {
                            await _updateAvailableBalance();
                            setState(() {});
                          }
                        },
                        selectedMonthYear: _selectedPeriodLabel(),
                        onDateSelected: _onDateSelected,
                      ),
                    ),
                  ),
                  // Título "Historial de transacciones" + MoneoSegmentedControl
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final textScaler = MediaQuery.textScalerOf(context);
                          final isWide = constraints.maxWidth >= 520 &&
                              textScaler.scale(14) <= 16.5;

                          const segmentedOptions = [
                            MoneoSegmentOption<String>(
                              value: 'Todos',
                              label: 'Todos',
                            ),
                            MoneoSegmentOption<String>(
                              value: 'Gastos',
                              label: 'Gastos',
                            ),
                            MoneoSegmentOption<String>(
                              value: 'Ingresos',
                              label: 'Ingresos',
                            ),
                          ];

                          final titleWidget = Text(
                            'Historial de transacciones',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: context.appTheme.textPrimary,
                            ),
                          );

                          final segmentedWidget = MoneoSegmentedControl<String>(
                            key: const Key('home_transaction_filter_segmented'),
                            options: segmentedOptions,
                            selectedValue: filter,
                            onChanged: (value) {
                              setState(() {
                                filter = value;
                                _groupedTransactionsCache = null;
                              });
                            },
                          );

                          if (isWide) {
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(child: titleWidget),
                                const SizedBox(width: 12),
                                SizedBox(width: 260, child: segmentedWidget),
                              ],
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              titleWidget,
                              const SizedBox(height: 10),
                              segmentedWidget,
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  // Estado vacío accionable o lista de transacciones agrupadas por fecha
                  if (transactionsByDate.isEmpty)
                    SliverToBoxAdapter(
                      child: _buildEmptyTransactionsState(),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final dateKey =
                              transactionsByDate.keys.elementAt(index);
                          final dailyTransactions =
                              transactionsByDate[dateKey]!;
                          final dailyIncome =
                              _calculateDailyBalance(dailyTransactions);

                          return _buildDateSection(
                            dateKey,
                            dailyIncome,
                            dailyTransactions,
                          );
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

  Widget _buildEmptyTransactionsState() {
    final t = context.appTheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final String filterTitle = switch (filter) {
      'Gastos' => 'Sin gastos en este período',
      'Ingresos' => 'Sin ingresos en este período',
      _ => 'Sin movimientos en este período',
    };
    final String filterDescription =
        'No hay movimientos registrados para ${_selectedPeriodLabel()} con el filtro "$filter".';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        key: const Key('home_empty_transactions_state'),
        padding: const EdgeInsets.all(AppSizes.paddingXLarge),
        decoration: BoxDecoration(
          color: t.cardBackground,
          borderRadius: BorderRadius.circular(
            context.isDiurno ? 18 : AppSizes.borderRadiusLarge,
          ),
          border: Border.all(color: t.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.1),
              blurRadius: context.isDiurno ? 12 : 4,
              offset: Offset(0, context.isDiurno ? 4 : 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: t.accent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.receipt_long_outlined,
                size: 28,
                color: t.accent,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              filterTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              filterDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textSecondary,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Semantics(
              button: true,
              label: 'Registrar movimiento',
              child: SizedBox(
                width: double.infinity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton.icon(
                    key: const Key('home_empty_register_cta'),
                    onPressed: _openRegisterTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.buttonBackground,
                      foregroundColor: t.buttonForeground,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingLarge,
                        vertical: AppSizes.paddingMedium,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadiusMedium,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add_rounded, size: 20),
                    label: const Text(
                      'Registrar movimiento',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Construir la sección de fecha con sus transacciones
  Widget _buildDateSection(String dateKey, double dailyIncome, List<Add_data> transactions) {
    final bool isExpanded = _expandedDates.contains(dateKey);
    final String dateLabel = _formatDateSectionLabel(dateKey);
    final bool isLight = Theme.of(context).brightness == Brightness.light;

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
          // Encabezado de fecha y total - accesible con target >= 44dp
          Semantics(
            button: true,
            expanded: isExpanded,
            label: '$dateLabel, ${CurrencyHelper.format(dailyIncome)}',
            excludeSemantics: true,
            child: InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedDates.remove(dateKey);
                  } else {
                    _expandedDates.add(dateKey);
                  }
                });
              },
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                dateLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: context.appTheme.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: context.appTheme.textSecondary,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 135),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            CurrencyHelper.format(dailyIncome),
                            maxLines: 1,
                            style: TextStyle(
                              color: dailyIncome >= 0
                                  ? context.appTheme.income
                                  : context.appTheme.expense,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
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

          // MOSTRAR LISTA O RESUMEN SEGÚN ESTADO
          if (isExpanded)
            // === LISTA DE TRANSACCIONES (EXPANDIDO) ===
            Container(
              decoration: BoxDecoration(
                color: context.appTheme.cardBackground,
                borderRadius: BorderRadius.circular(
                  context.isDiurno ? 18 : AppSizes.borderRadiusLarge,
                ),
                border: context.isDefaultDark
                    ? null
                    : Border.all(
                        color: context.appTheme.borderSubtle,
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: isLight ? 0.06 : 0.1,
                    ),
                    blurRadius: context.isDiurno ? 12 : 4,
                    offset: Offset(0, context.isDiurno ? 4 : 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  context.isDiurno ? 18 : AppSizes.borderRadiusLarge,
                ),
                child: Column(
                  children: [
                    ...transactions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final transaction = entry.value;

                      return Column(
                        children: [
                          _buildTransactionItem(transaction),
                          if (index < transactions.length - 1)
                            Divider(
                              color: context.appTheme.borderSubtle,
                              height: 1,
                              thickness: context.isDefaultDark ? 0.4 : 0.8,
                              indent: 60,
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
                  setState(() {});
                  _updateAvailableBalance();
                });
              },
              borderRadius: BorderRadius.circular(
                context.isDiurno ? 18 : AppSizes.borderRadiusLarge,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: context.appTheme.cardBackground,
                  borderRadius: BorderRadius.circular(
                    context.isDiurno ? 18 : AppSizes.borderRadiusLarge,
                  ),
                  border: Border.all(
                    color: context.appTheme.borderSubtle,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isLight ? 0.06 : 0.1,
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
                            color: context.appTheme.income
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_downward_rounded,
                            color: context.appTheme.income,
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
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
                            color: context.appTheme.expense
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_upward_rounded,
                            color: context.appTheme.expense,
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
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
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
    final bool isTransfer = history.IN == 'Transfer';
    final bool isIncome = history.IN == 'Income';

    final String mainTitle;
    if (isTransfer) {
      mainTitle = history.safeDetail.isNotEmpty
          ? "Transferencia - ${history.safeDetail}"
          : "Transferencia";
    } else {
      mainTitle = history.safeDetail.isNotEmpty
          ? "${history.safeCategory} - ${history.safeDetail}"
          : history.safeCategory;
    }

    final IconData transactionIcon =
        isTransfer ? Icons.sync_alt : AppIcons.getIcon(history.safeIconCode);

    final int? rawCategoryColorValue =
        isTransfer ? null : _categoryColors[history.safeCategory];
    final Color baseCategoryColor = rawCategoryColorValue != null
        ? Color(rawCategoryColorValue)
        : (isTransfer
            ? context.appTheme.secondaryAccent
            : (isIncome
                ? context.appTheme.income
                : context.appTheme.expense));
    final Color categoryColor =
        AppColors.getReadableColor(baseCategoryColor, context);

    final String timeFormatted = _formatTime(history.safeDate);
    final String accountOrRoute = isTransfer
        ? (history.explain ?? '').trim()
        : history.safeAccount.trim();
    final String subtitleText = accountOrRoute.isNotEmpty
        ? '$timeFormatted · $accountOrRoute'
        : timeFormatted;
    final String formattedAmount = CurrencyHelper.formatString(history.safeAmount);

    return Semantics(
      button: true,
      label: '$mainTitle, $subtitleText, $formattedAmount',
      child: InkWell(
        onTap: () => showTransactionOptions(
          history,
          context,
          _editTransaction,
          _confirmDeleteTransaction,
        ),
        splashColor: context.appTheme.accent.withValues(alpha: 0.1),
        highlightColor: context.appTheme.accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSmall),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double maxRightWidth =
                  ((constraints.maxWidth - 67) * 0.45).clamp(72.0, 160.0);
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    key: ValueKey('tx_icon_${history.safeCategory}'),
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: categoryColor.withValues(alpha: 0.45),
                        width: 1.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      transactionIcon,
                      size: 22,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        Text(
                          subtitleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: context.appTheme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    constraints: BoxConstraints(maxWidth: maxRightWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            formattedAmount,
                            maxLines: 1,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              color: isTransfer
                                  ? context.appTheme.textSecondary
                                  : (isIncome
                                      ? context.appTheme.income
                                      : context.appTheme.expense),
                            ),
                          ),
                        ),
                        if (history.installments != null &&
                            history.installments != '1' &&
                            history.installments!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.appTheme.accent
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: context.appTheme.accent
                                    .withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              '${history.installments} cuotas',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.appTheme.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        if (history.isInterestFree == true) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.appTheme.income
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: context.appTheme.income
                                    .withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'Sin interés',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: context.appTheme.income,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
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
    builder: (context) {
      final t = context.appTheme;
      return AlertDialog(
        backgroundColor: t.secondaryCardBackground,
        title: Text(
          '⚠️ Referencia eliminada detectada',
          style: TextStyle(color: t.warning, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: TextStyle(color: t.textPrimary),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: t.buttonForeground,
              backgroundColor: t.expense,
            ),
            onPressed: () {
              Navigator.of(context).pop(false);
              _confirmDeleteTransaction(transaction);
            },
            child: Text('Eliminar', style: TextStyle(color: t.buttonForeground)),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: t.borderSubtle),
            ),
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text(
              'Editar de todas formas',
              style: TextStyle(color: t.textPrimary),
            ),
          ),
        ],
      );
    },
  );
  
  // Retorna true si el usuario eligió editar, false si eligió eliminar
  return result ?? false;
}

  // Método para confirmar eliminación
  void _confirmDeleteTransaction(Add_data transaction) {
    showDialog(
      context: context,
      builder: (context) {
        final t = context.appTheme;
        return AlertDialog(
          backgroundColor: t.secondaryCardBackground,
          title: Text(
            'Confirmar eliminación',
            style: TextStyle(color: t.textPrimary),
          ),
          content: Text(
            '¿Estás seguro que deseas eliminar esta transacción? Esta acción no se puede deshacer.',
            style: TextStyle(color: t.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: t.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: t.expense,
                foregroundColor: t.buttonForeground,
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteTransaction(transaction);
              },
              child: Text(
                'Eliminar',
                style: TextStyle(color: t.buttonForeground),
              ),
            ),
          ],
        );
      },
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