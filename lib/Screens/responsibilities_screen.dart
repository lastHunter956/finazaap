import 'package:flutter/material.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/utils/currency_helper.dart'; // Import added
import 'package:finazaap/widgets/responsibility_dashboard_card.dart';
import 'package:finazaap/widgets/urgent_payments_section.dart';
import 'package:finazaap/widgets/responsibility_list_item.dart';
import 'package:finazaap/widgets/add_responsibility_dialog.dart';
import 'package:finazaap/widgets/responsibility_actions_menu.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/data/account_service.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/widgets/show_responsibility_options.dart';
import 'dart:ui';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class ResponsibilitiesScreen extends StatefulWidget {
  const ResponsibilitiesScreen({Key? key}) : super(key: key);

  @override
  State<ResponsibilitiesScreen> createState() => _ResponsibilitiesScreenState();
}

class _ResponsibilitiesScreenState extends State<ResponsibilitiesScreen> {
  List<String> _selectedCategories = ['Todos'];
  // Categorias comunes para mostrar en la barra rápida
  final List<String> _quickCategories = ['Todos', 'servicio', 'tarjeta', 'préstamo', 'educación'];
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  
  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      await ResponsibilityService.init();
      // Purge sample data once if they exist
      final box = ResponsibilityService.getBox();
      final sampleNames = {'Netflix', 'Luz', 'Internet', 'Manejo Visa', 'Gym', 'Spotify'};
      final toDelete = box.values.where((r) => sampleNames.contains(r.safeName)).toList();
      for (var r in toDelete) {
        await r.delete();
      }
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing responsibilities: $e');
    }
  }

  Future<void> _loadResponsibilities() async {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      appBar: AppBar(
        backgroundColor: context.appTheme.cardBackground,
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 75,
        title: Padding(
          padding: const EdgeInsets.all(10),
          child: Text(
            'Responsabilidades',
            style: TextStyle(
              color: context.appTheme.textPrimary,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: const [
          // Se movió al menú de acciones unificado en el FAB
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: ResponsibilityService.getBox().listenable(),
        builder: (context, Box<Responsibility> box, _) {
          final list = box.values.toList();
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
                    // Dashboard Card
                    SliverToBoxAdapter(
                      child: ResponsibilityDashboardCard(
                        responsibilities: [], 
                        selectedMonth: _selectedMonth,
                        selectedYear: _selectedYear,
                        onDateSelected: (day, month, year) {
                          setState(() {
                            _selectedMonth = month;
                            _selectedYear = year;
                          });
                          _loadResponsibilities();
                        },
                      ),
                    ),
                    
                    // Urgent Payments Section
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          UrgentPaymentsSection(
                            month: _selectedMonth,
                            year: _selectedYear,
                            day: null,
                            onTogglePaid: (id) async {
                              // Pass current view context to pay for the correct month
                              await ResponsibilityService.togglePaidStatus(id, month: _selectedMonth, year: _selectedYear);
                              setState(() {});
                            },
                            onTap: (r, m, y) {}, // No se usa directamente ahora que llama al utility dentro
                            onEdit: (r) => _showAddResponsibilityDialog(responsibility: r),
                            onDelete: (r) => _confirmDeleteResponsibility(r),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),

                    // Sticky Category Header
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _StickyCategoryDelegate(
                        child: Container(
                          color: context.appTheme.primaryBackground,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Obligaciones',
                                      style: TextStyle(
                                        color: context.appTheme.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '${box.length} total',
                                      style: TextStyle(
                                        color: context.appTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 48,
                                margin: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: context.appTheme.cardBackground.withOpacity(.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: context.appTheme.borderVisible,
                                    width: 1,
                                  ),
                                ),
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  // +1 para el botón de "Más"
                                  itemCount: _quickCategories.length + 1,
                                  itemBuilder: (context, index) {
                                    // Botón "Más Filtros" al final
                                    if (index == _quickCategories.length) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: _showFilterDialog,
                                            borderRadius: BorderRadius.circular(8),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: context.appTheme.darkBackground,
                                                borderRadius: BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: context.appTheme.borderSubtle,
                                                  width: 1,
                                                ),
                                              ),
                                              alignment: Alignment.center,
                                              child: Row(
                                                children: [
                                                  Icon(Icons.filter_list_rounded, size: 16, color: context.appTheme.textSecondary),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Más',
                                                    style: TextStyle(
                                                      color: context.appTheme.textPrimary,
                                                      fontSize: 12.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    final category = _quickCategories[index];
                                    final isSelected = _selectedCategories.contains(category);
                                    
                                    // Conteo: Si es 'Todos', cuenta total. Si es específico, cuenta filtrada.
                                    final count = category == 'Todos' 
                                        ? box.length 
                                        : box.values.where((r) => r.safeCategory == category).length;
                                    
                                    const accentColor = Color(0xFF3B82F6);
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            setState(() {
                                              if (category == 'Todos') {
                                                _selectedCategories = ['Todos'];
                                              } else {
                                                if (_selectedCategories.contains('Todos')) {
                                                  _selectedCategories.clear();
                                                }
                                                if (_selectedCategories.contains(category)) {
                                                  _selectedCategories.remove(category);
                                                  if (_selectedCategories.isEmpty) _selectedCategories.add('Todos');
                                                } else {
                                                  _selectedCategories.add(category);
                                                }
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(8),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 250),
                                            curve: Curves.easeOutCubic,
                                            padding: EdgeInsets.symmetric(
                                              horizontal: isSelected ? 16 : 14,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected ? accentColor.withOpacity(0.2) : Colors.transparent,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: isSelected ? accentColor : Colors.transparent,
                                                width: 1.5,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isSelected) ...[
                                                  const Icon(Icons.check_circle_rounded, size: 14, color: accentColor),
                                                  const SizedBox(width: 6),
                                                ],
                                                Text(
                                                  category == 'Todos' ? category : _capitalize(category),
                                                  style: TextStyle(
                                                    color: isSelected ? accentColor : context.appTheme.textPrimary,
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                    fontSize: isSelected ? 13 : 12.5,
                                                  ),
                                                ),
                                                if (count > 0) ...[
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    count.toString(),
                                                    style: TextStyle(
                                                      color: isSelected ? Colors.white : context.appTheme.textSecondary,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Responsibility List
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      sliver: _buildResponsibilitySliver(_selectedCategories),
                    ),
                  ],
          );
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withOpacity(0.4),
              blurRadius: 12,
              spreadRadius: -2,
              offset: const Offset(0, 4),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: FloatingActionButton(
          heroTag: "responsibilities_fab",
          onPressed: _showActionsMenu,
          backgroundColor: AppColors.accent,
          elevation: 0,
          highlightElevation: 0,
          child: Icon(Icons.add_rounded, size: 32, color: AppColors.primaryBackground),
        ),
      ),
    );
  }

  void _showActionsMenu() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Menu de Acciones",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ResponsibilityActionsMenu(
          onAddResponsibility: () => _showAddResponsibilityDialog(),
          onPlanIncome: () => _showIncomeDistributorDialog(),
        );
      },
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: context.appTheme.secondaryCardBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: context.appTheme.borderSubtle)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filtrar Categorías',
                          style: TextStyle(
                            color: context.appTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                             setState(() {
                               _selectedCategories = ['Todos'];
                             });
                             Navigator.pop(context);
                          },
                          child: const Text('Limpiar', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  ),
                  
                  // Grid
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: ResponsibilityService.availableCategories.map((category) {
                          final isSelected = _selectedCategories.contains(category);
                          return FilterChip(
                            label: Text(_capitalize(category)),
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : context.appTheme.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            selected: isSelected,
                            selectedColor: Colors.blueAccent.withOpacity(0.3),
                            backgroundColor: context.appTheme.darkBackground,
                            checkmarkColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isSelected ? Colors.blueAccent : context.appTheme.borderSubtle,
                              ),
                            ),
                            onSelected: (bool selected) {
                              setStateSB(() { // Update dialog UI
                                if (_selectedCategories.contains('Todos')) {
                                  _selectedCategories.clear();
                                }
                                
                                if (selected) {
                                  _selectedCategories.add(category);
                                } else {
                                  _selectedCategories.remove(category);
                                }
                                
                                if (_selectedCategories.isEmpty) {
                                  _selectedCategories.add('Todos');
                                }
                              });
                              // Update parent UI immediately for responsiveness
                              setState(() {}); 
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  // Button
                  Padding(
                     padding: const EdgeInsets.all(20),
                     child: SizedBox(
                       width: double.infinity,
                       child: ElevatedButton(
                         style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.blueAccent,
                           padding: const EdgeInsets.symmetric(vertical: 16),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                         ),
                         onPressed: () => Navigator.pop(context),
                         child: const Text('Hecho', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                       ),
                     ),
                  ),
                ],
              ),
            );
          }
        );
      },
    );
  }

  bool _showAllObligations = false;
  
  Widget _buildResponsibilitySliver(List<String> categories) {
    List<Responsibility> responsibilities;
    
    if (categories.contains('Todos')) {
      responsibilities = ResponsibilityService.getAllResponsibilities();
    } else {
      final all = ResponsibilityService.getAllResponsibilities();
      responsibilities = all.where((r) => categories.contains(r.safeCategory)).toList();
    }

    if (responsibilities.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.appTheme.darkBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: context.appTheme.textHint,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay responsabilidades',
                style: TextStyle(
                  color: context.appTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Lógica de "Ver más"
    final int displayLimit = 5;
    final bool hasMore = responsibilities.length > displayLimit;
    final displayItems = (_showAllObligations || !hasMore) 
        ? responsibilities 
        : responsibilities.take(displayLimit).toList();

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Si estamos al final y hay más items por mostrar, renderizar el botón "Ver más"
          if (!_showAllObligations && hasMore && index == displayItems.length) {
            return _buildSeeMoreButton(responsibilities.length - displayLimit);
          }
          
          final responsibility = displayItems[index];
          return ResponsibilityListItem(
            responsibility: responsibility,
            month: _selectedMonth,
            year: _selectedYear,
            day: null,
            onTap: () => _handleResponsibilityTap(responsibility),
            onEdit: () => _showAddResponsibilityDialog(responsibility: responsibility),
            onDelete: () => _confirmDeleteResponsibility(responsibility),
            onTogglePaid: () => _handlePayResponsibility(responsibility),
            onPayMonth: () async {
              await ResponsibilityService.payFullMonth(
                  responsibility.safeId, 
                  _selectedMonth, 
                  _selectedYear
              );
              setState(() {});
            },
          );
        },
        childCount: (!_showAllObligations && hasMore) ? displayItems.length + 1 : displayItems.length,
      ),
    );
  }

  Widget _buildSeeMoreButton(int remaining) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _showAllObligations = true;
            });
          },
          icon: const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.blueAccent),
          label: Text(
            'Ver más ($remaining)',
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            backgroundColor: Colors.blueAccent.withOpacity(0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blueAccent.withOpacity(0.2)),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddResponsibilityDialog({Responsibility? responsibility}) {
    showDialog(
      context: context,
      builder: (context) => AddResponsibilityDialog(responsibility: responsibility),
    ).then((_) => setState(() {}));
  }

  void _confirmDeleteResponsibility(Responsibility responsibility) async {
    // PROTECCIÓN: No permitir borrar tarjeta si la cuenta existe
    if (responsibility.safeCategory == 'tarjeta') {
      final activeAccounts = await AccountService.getActiveAccounts();
      final accountExists = activeAccounts.any((a) => a['title'] == responsibility.safeName);
      
      if (accountExists && mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: context.appTheme.secondaryCardBackground,
            title: Text('Acción Bloqueada', style: TextStyle(color: context.appTheme.textPrimary)),
            content: Text(
              'No puedes eliminar esta obligación porque está vinculada a una Cuenta activa.\n\nPara eliminarla, debes borrar la cuenta de tarjeta desde "Gestión de Cuentas".',
              style: TextStyle(color: context.appTheme.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido', style: TextStyle(color: Colors.blueAccent)),
              ),
            ],
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.appTheme.secondaryCardBackground,
        title: Text('Eliminar Obligación', style: TextStyle(color: context.appTheme.textPrimary)),
        content: Text('¿Estás seguro de que deseas eliminar "${responsibility.safeName}"?', style: TextStyle(color: context.appTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ResponsibilityService.deleteResponsibility(responsibility.safeId);
              setState(() {});
              AlertHelper.success(context, '"${responsibility.safeName}" eliminada');
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _handleResponsibilityTap(Responsibility responsibility) {
    showResponsibilityOptions(
      context: context,
      responsibility: responsibility,
      selectedMonth: _selectedMonth,
      selectedYear: _selectedYear,
      onEdit: (r) => _showAddResponsibilityDialog(responsibility: r),
      onDelete: _confirmDeleteResponsibility,
      onPay: _handlePayResponsibility,
      onPayMonth: (resp) async {
        await ResponsibilityService.payFullMonth(
            resp.safeId, 
            _selectedMonth, 
            _selectedYear
        );
        setState(() {});
      },
    );
  }

  void _handlePayResponsibility(Responsibility responsibility) async {
    _showUnifiedPaymentDialog(responsibility);
  }

  void _showUnifiedPaymentDialog(Responsibility responsibility) async {
    // 1. Calcular cuota y balance sugeridos
    final double expected = responsibility.getAmountForDate(_selectedMonth, _selectedYear);
    final double paid = responsibility.getPaidAmountInCycle(_selectedMonth, _selectedYear);
    final double suggestedAmount = (expected - paid).clamp(0.0, double.infinity);
    
    // Si la cuota restante es 0, sugerir el monto total del mes (o balance si es tarjeta)
    double initialValue = suggestedAmount > 0 
        ? suggestedAmount 
        : (responsibility.safeCategory == 'tarjeta' 
            ? (responsibility.cardBalance ?? expected) 
            : expected);

    final TextEditingController amountController = TextEditingController(text: CurrencyHelper.format(initialValue, showSymbol: false));
    
    // 2. Obtener cuentas activas para el dropdown
    final List<Map<String, dynamic>> accounts = await AccountService.getActiveAccounts();
    String? selectedAccountName;
    if (accounts.isNotEmpty) {
      selectedAccountName = accounts.first['title'];
    }

    DateTime selectedDate = DateTime.now();
    bool isMinimumPayment = true; // true: Sugerido, false: Personalizado
    bool markAsPaidComplete = true; // Activo por defecto

    if (!mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Pagar Obligación",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: context.appTheme.secondaryCardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.getIcon(responsibility.safeIconCode), color: Colors.blueAccent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pagar ${responsibility.safeName}',
                        style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                content: SizedBox(
                  width: double.maxFinite,
                  child: StatefulBuilder(
                    builder: (context, setStateSB) {
                      // Función interna para mostrar DatePicker
                      Future<void> _pickPaymentDate() async {
                        final newDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.dark(
                                  primary: Colors.blueAccent,
                                  surface: context.appTheme.secondaryCardBackground,
                                  onPrimary: Colors.white,
                                  onSurface: context.appTheme.textPrimary,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (newDate != null) {
                          setStateSB(() {
                            selectedDate = newDate;
                          });
                        }
                      }

                      return SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Info Cuota Restante
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Pendiente para este mes',
                                    style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    CurrencyHelper.format(suggestedAmount),
                                    style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selector Tipo Pago
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(
                                      'Sugerido',
                                      style: TextStyle(
                                        color: isMinimumPayment ? context.appTheme.primaryBackground : context.appTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: isMinimumPayment,
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: context.appTheme.darkBackground,
                                    onSelected: (val) {
                                      setStateSB(() {
                                        isMinimumPayment = true;
                                        amountController.text = CurrencyHelper.format(initialValue, showSymbol: false);
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: Text(
                                      'Personalizado',
                                      style: TextStyle(
                                        color: !isMinimumPayment ? context.appTheme.primaryBackground : context.appTheme.textSecondary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    selected: !isMinimumPayment,
                                    selectedColor: Colors.blueAccent,
                                    backgroundColor: context.appTheme.darkBackground,
                                    onSelected: (val) {
                                      setStateSB(() {
                                        isMinimumPayment = false;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Input de Monto (solo editable si es personalizado)
                            Text(
                              'Monto del Pago',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              enabled: !isMinimumPayment,
                              style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                              inputFormatters: [
                                ThousandsSeparatorInputFormatter(),
                              ],
                              decoration: InputDecoration(
                                prefixIcon: Icon(Icons.attach_money, color: context.appTheme.textSecondary),
                                filled: true,
                                fillColor: isMinimumPayment ? context.appTheme.primaryBackground.withOpacity(0.5) : context.appTheme.darkBackground,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Cuenta de Origen Dropdown
                            Text(
                              'Cuenta de Pago',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: context.appTheme.darkBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.appTheme.borderSubtle),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: selectedAccountName,
                                  dropdownColor: context.appTheme.secondaryCardBackground,
                                  isExpanded: true,
                                  hint: Text('Seleccionar cuenta', style: TextStyle(color: context.appTheme.textHint, fontSize: 14)),
                                  icon: Icon(Icons.keyboard_arrow_down, color: context.appTheme.textSecondary),
                                  items: accounts.map<DropdownMenuItem<String>>((account) {
                                    return DropdownMenuItem<String>(
                                      value: account['title'],
                                      child: Row(
                                        children: [
                                          Icon(
                                            AppIcons.getIcon(account['icon']),
                                            size: 16,
                                            color: Color(account['iconColor'] ?? 0xFFFFFFFF),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(account['title'], style: TextStyle(color: context.appTheme.textPrimary, fontSize: 14)),
                                          const Spacer(),
                                          Text(
                                            CurrencyHelper.formatCompact(double.tryParse(account['balance'].toString()) ?? 0),
                                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (String? newValue) {
                                    setStateSB(() {
                                      selectedAccountName = newValue;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selector de Fecha
                            Text(
                              'Fecha del Pago',
                              style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: _pickPaymentDate,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  color: context.appTheme.darkBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.appTheme.borderSubtle),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 16),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('dd/MM/yyyy').format(selectedDate),
                                      style: TextStyle(color: context.appTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.edit_calendar_rounded, color: context.appTheme.textHint, size: 16),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Switch Marcar Completa
                            SwitchListTile(
                              title: Text(
                                'Marcar obligación completa',
                                style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              value: markAsPaidComplete,
                              activeColor: Colors.blueAccent,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setStateSB(() {
                                  markAsPaidComplete = val;
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('Cancelar', style: TextStyle(color: context.appTheme.textSecondary)),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () async {
                      if (amountController.text.isEmpty || selectedAccountName == null) return;
                      final payAmount = double.tryParse(CurrencyHelper.cleanAmountString(amountController.text)) ?? 0.0;
                      if (payAmount <= 0) return;

                      Navigator.pop(dialogContext);

                      try {
                        // 1. Process real transaction Expense (egreso)
                        final success = await TransactionService.processTransaction(
                          type: 'Expenses',
                          amount: payAmount,
                          accountName: selectedAccountName!,
                          isNewTransaction: true,
                        );

                        if (success) {
                          // 2. Add transaction to Hive
                          final box = Hive.isBoxOpen('data')
                              ? Hive.box<Add_data>('data')
                              : await Hive.openBox<Add_data>('data');
                          
                          // Obtener categoría de transacción correspondiente
                          final matchedCat = await CategoryService.findMatchingCategoryForObligation(responsibility.safeCategory);
                          final String categoryName = matchedCat != null ? (matchedCat['text'] as String) : responsibility.safeCategory;
                          final int iconCode = matchedCat != null ? (matchedCat['icon'] as int) : responsibility.safeIconCode;

                          final transaction = Add_data(
                            'Expenses',
                            payAmount.toString(),
                            selectedDate,
                            'Pago obligación: ${responsibility.safeName}',
                            categoryName,
                            selectedAccountName!,
                            iconCode,
                            '1', // installments
                            true, // isInterestFree
                            responsibility.safeId,
                            true, // isObligationPayment
                          );
                          await box.add(transaction);

                          // 3. Register payment in Responsibility box
                          await ResponsibilityService.registerPayment(
                            responsibility.safeId,
                            payAmount,
                            selectedDate,
                            markAsPaidComplete,
                          );

                          _loadResponsibilities();
                          setState(() {});
                          AlertHelper.success(context, 'Pago registrado correctamente');
                        } else {
                          AlertHelper.error(context, 'Error al procesar la transacción');
                        }
                      } catch (e) {
                        AlertHelper.error(context, 'Ocurrió un error: $e');
                      }
                    },
                    child: const Text('Confirmar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showIncomeDistributorDialog() {
    final monthlyTotal = ResponsibilityService.calculateMonthlyTotal();
    final TextEditingController incomeController = TextEditingController();
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Asistente de Ingresos",
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  decoration: BoxDecoration(
                    color: context.appTheme.secondaryCardBackground,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                    border: Border.all(color: context.appTheme.borderSubtle, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header estilo AddResponsibilityDialog
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [const Color(0xFF3B82F6).withOpacity(0.2), const Color(0xFF3B82F6).withOpacity(0.05)],
                            ),
                            border: Border(bottom: BorderSide(color: context.appTheme.borderSubtle, width: 1)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3B82F6),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withOpacity(0.4),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.psychology_alt_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Asistente de Ingresos',
                                      style: TextStyle(color: context.appTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Optimiza tus ahorros y gastos',
                                      style: TextStyle(color: context.appTheme.textSecondary, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Input Body
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInputLabel('Tu Ingreso Mensual'),
                              _buildInputField(
                                child: TextField(
                                  controller: incomeController,
                                  keyboardType: TextInputType.number,
                                  autofocus: true,
                                  style: TextStyle(color: context.appTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  inputFormatters: [
                                    ThousandsSeparatorInputFormatter(),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(color: context.appTheme.textHint),
                                    prefixIcon: const Icon(Icons.attach_money_rounded, color: Color(0xFF3B82F6), size: 24),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                ),
                                highlight: true,
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.receipt_long_rounded, color: const Color(0xFFEF4444).withOpacity(0.8), size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'OBLIGACIONES FIJAS',
                                            style: TextStyle(color: context.appTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                          ),
                                          Text(
                                            '\$${NumberFormat.decimalPattern('es').format(monthlyTotal)}',
                                            style: TextStyle(color: context.appTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w900),
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

                        // Action Buttons
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(color: context.appTheme.borderSubtle),
                                    ),
                                  ),
                                  child: Text('Cerrar', style: TextStyle(color: context.appTheme.textSecondary)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  onPressed: () {
                                    final text = incomeController.text.replaceAll(RegExp(r'[^0-9]'), '');
                                    final income = double.tryParse(text);
                                    if (income != null) {
                                      Navigator.pop(context);
                                      _showDistributionResults(income, monthlyTotal);
                                    }
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF3B82F6),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    elevation: 4,
                                    shadowColor: const Color(0xFF3B82F6).withOpacity(0.5),
                                  ),
                                  child: const Text('CALCULAR', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                                ),
                              ),
                            ],
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

  void _showDistributionResults(double income, double obligations) {
    final remaining = income - obligations;
    final savings = income * 0.20;
    final expenses = income * 0.60;
    final emergency = income * 0.20;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Resultados",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Dialog(
                backgroundColor: Colors.transparent,
                elevation: 0,
                insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 420),
                  decoration: BoxDecoration(
                    color: context.appTheme.secondaryCardBackground,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                    border: Border.all(color: context.appTheme.borderSubtle, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header Refinado
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: context.appTheme.borderSubtle, width: 1)),
                          ),
                          child: Center(
                            child: Text(
                              'Plan Sugerido',
                              style: TextStyle(
                                color: context.appTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                fontSize: 24,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                        ),
                        
                        // Resultados con Scroll
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                _buildDistributionItem('Obligaciones', obligations, income, const Color(0xFFEF4444), Icons.receipt_long_rounded, 'Mínimo vital'),
                                _buildDistributionItem('Crecimiento (20%)', savings, income, const Color(0xFF10B981), Icons.trending_up_rounded, 'Ahorro / Inversión'),
                                _buildDistributionItem('Estilo de Vida (60%)', expenses, income, const Color(0xFF3B82F6), Icons.shopping_bag_rounded, 'Gastos diarios'),
                                _buildDistributionItem('Reserva (20%)', emergency, income, const Color(0xFFF59E0B), Icons.shield_rounded, 'Fondo de emergencia'),
                                
                                const SizedBox(height: 16),
                                
                                // Tarjeta de Flujo Disponible Rediseñada
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: context.appTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: (remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'SALDO DISPONIBLE',
                                            style: TextStyle(
                                              color: context.appTheme.textSecondary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(100),
                                            ),
                                            child: Text(
                                              remaining >= 0 ? 'SALUDABLE' : 'ALTO RIESGO',
                                              style: TextStyle(
                                                color: remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                                fontSize: 9,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        '\$${NumberFormat.decimalPattern('es').format(remaining)}',
                                        style: TextStyle(
                                          color: context.appTheme.textPrimary,
                                          fontSize: 36,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -1,
                                          shadows: [
                                            Shadow(
                                              color: (remaining >= 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444)).withOpacity(0.3),
                                              blurRadius: 20,
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        remaining >= 0 
                                          ? '¡Excelente! Tienes flujo libre para invertir o disfrutar.' 
                                          : 'Cuidado: Tus obligaciones superan tus ingresos calculados.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: context.appTheme.textSecondary,
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
                        ),

                        // Action Button
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 56),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 8,
                              shadowColor: const Color(0xFF3B82F6).withOpacity(0.5),
                            ),
                            child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
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

  Widget _buildDistributionItem(String label, double amount, double total, Color color, IconData icon, String subtitle) {
    final percentage = total > 0 ? (amount / total).clamp(0.0, 1.0) : 0.0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.darkBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.appTheme.borderSubtle, width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(color: context.appTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: context.appTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyHelper.formatCompact(amount),
                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    '${(percentage * 100).toStringAsFixed(0)}%',
                    style: TextStyle(color: context.appTheme.textHint, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Mini-barra de progreso
          Stack(
            children: [
              Container(
                height: 6,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: context.appTheme.borderSubtle,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              FractionallySizedBox(
                widthFactor: percentage,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.7)],
                    ),
                    borderRadius: BorderRadius.circular(100),
                    boxShadow: [
                      BoxShadow(color: color.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: context.appTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildInputField({required Widget child, bool highlight = false}) {
    return Container(
      decoration: BoxDecoration(
        color: context.appTheme.darkBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? const Color(0xFF3B82F6).withOpacity(0.6) : context.appTheme.borderSubtle,
          width: 1.8,
        ),
        boxShadow: highlight ? [
          BoxShadow(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ] : [],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: const InputDecorationTheme(
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            filled: false,
          ),
        ),
        child: child,
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _StickyCategoryDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;

  _StickyCategoryDelegate({required this.child});

  @override
  double get minExtent => 110; // Reducido para ajustarse al contenido comprimido
  @override
  double get maxExtent => 110;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _StickyCategoryDelegate oldDelegate) {
    return oldDelegate.child != child;
  }
}
