import 'package:flutter/material.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/utils/currency_helper.dart'; // Import added
import 'package:finazaap/widgets/responsibility_dashboard_card.dart';
import 'package:finazaap/widgets/urgent_payments_section.dart';
import 'package:finazaap/widgets/responsibility_list_item.dart';
import 'package:finazaap/widgets/add_responsibility_dialog.dart';
import 'package:finazaap/widgets/responsibility_actions_menu.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

class ResponsibilitiesScreen extends StatefulWidget {
  const ResponsibilitiesScreen({Key? key}) : super(key: key);

  @override
  State<ResponsibilitiesScreen> createState() => _ResponsibilitiesScreenState();
}

class _ResponsibilitiesScreenState extends State<ResponsibilitiesScreen> {
  String _selectedCategory = 'Todos';
  final List<String> _categories = ['Todos', 'servicio', 'membresía', 'tarjeta', 'préstamo'];
  
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
      await ResponsibilityService.addSampleData();
      setState(() {});
    } catch (e) {
      debugPrint('Error initializing responsibilities: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1),
        elevation: 0,
        centerTitle: true,
        toolbarHeight: 75,
        title: const Padding(
          padding: EdgeInsets.all(10),
          child: Text(
            'Responsabilidades',
            style: TextStyle(
              color: Colors.white,
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
          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Dashboard Card
              SliverToBoxAdapter(
                child: ResponsibilityDashboardCard(
                  month: _selectedMonth,
                  year: _selectedYear,
                  onDateSelected: (month, year) {
                    setState(() {
                      _selectedMonth = month;
                      _selectedYear = year;
                    });
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
                    color: const Color.fromRGBO(31, 38, 57, 1),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Obligaciones',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${box.length} total',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.5),
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
                            color: const Color.fromRGBO(42, 49, 67, 1).withOpacity(.8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            itemCount: _categories.length,
                            itemBuilder: (context, index) {
                              final category = _categories[index];
                              final isSelected = _selectedCategory == category;
                              final count = category == 'Todos' 
                                  ? box.length 
                                  : box.values.where((r) => r != null && r.safeCategory == category).length;
                              
                              const accentColor = Color(0xFF3B82F6);
                              
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedCategory = category;
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
                                              color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              fontSize: isSelected ? 13 : 12.5,
                                            ),
                                          ),
                                          if (count > 0) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              count.toString(),
                                              style: TextStyle(
                                                color: isSelected ? Colors.white : Colors.white38,
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
                sliver: _buildResponsibilitySliver(_selectedCategory),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: "responsibilities_fab",
        onPressed: _showActionsMenu,
        backgroundColor: const Color(0xFF3B82F6),
        elevation: 6,
        child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
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

  Widget _buildResponsibilitySliver(String category) {
    List<Responsibility> responsibilities;
    
    if (category == 'Todos') {
      responsibilities = ResponsibilityService.getAllResponsibilities();
    } else {
      responsibilities = ResponsibilityService.getByCategory(category);
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
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay responsabilidades',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final responsibility = responsibilities[index];
          return ResponsibilityListItem(
            responsibility: responsibility,
            month: _selectedMonth,
            year: _selectedYear,
            onTap: () => _showAddResponsibilityDialog(responsibility: responsibility),
            onEdit: () => _showAddResponsibilityDialog(responsibility: responsibility),
            onDelete: () => _confirmDeleteResponsibility(responsibility),
            onTogglePaid: () => _handlePayResponsibility(responsibility),
          );
        },
        childCount: responsibilities.length,
      ),
    );
  }

  void _showAddResponsibilityDialog({Responsibility? responsibility}) {
    showDialog(
      context: context,
      builder: (context) => AddResponsibilityDialog(responsibility: responsibility),
    ).then((_) => setState(() {}));
  }

  void _confirmDeleteResponsibility(Responsibility responsibility) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF222939),
        title: const Text('Eliminar Obligación', style: TextStyle(color: Colors.white)),
        content: Text('¿Estás seguro de que deseas eliminar "${responsibility.safeName}"?', style: const TextStyle(color: Colors.white70)),
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

  void _handlePayResponsibility(Responsibility responsibility) async {
    // Si es tarjeta de crédito, tal vez queramos una lógica especial más adelante,
    // pero por ahora usamos el toggle estándar.
    await ResponsibilityService.togglePaidStatus(
      responsibility.safeId, 
      month: _selectedMonth, 
      year: _selectedYear
    );
    setState(() {});
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
                    color: const Color(0xFF222939),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF262D43), Color(0xFF1F2538)],
                    ),
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
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
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
                                    const Text(
                                      'Asistente de Ingresos',
                                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Optimiza tus ahorros y gastos',
                                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
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
                                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    hintText: '0.00',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.2)),
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
                                            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                          ),
                                          Text(
                                            '\$${NumberFormat.decimalPattern('es').format(monthlyTotal)}',
                                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
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
                                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                    ),
                                  ),
                                  child: Text('Cerrar', style: TextStyle(color: Colors.white.withOpacity(0.6))),
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
                    color: const Color(0xFF222939),
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.6),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                      ),
                    ],
                    border: Border.all(color: Colors.white.withOpacity(0.1), width: 1.5),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF262D43), Color(0xFF1F2538)],
                    ),
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
                            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.08), width: 1)),
                          ),
                          child: const Center(
                            child: Text(
                              'Plan Sugerido',
                              style: TextStyle(
                                color: Colors.white,
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
                                    color: Colors.black.withOpacity(0.3),
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
                                              color: Colors.white.withOpacity(0.4),
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
                                          color: Colors.white,
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
                                          color: Colors.white.withOpacity(0.5),
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
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
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
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
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
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10, fontWeight: FontWeight.bold),
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
                  color: Colors.white.withOpacity(0.05),
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
          color: Colors.white.withOpacity(0.4),
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
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? const Color(0xFF3B82F6).withOpacity(0.6) : Colors.white.withOpacity(0.1),
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
      child: child,
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
