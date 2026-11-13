import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/utils/currency_helper.dart'; // Import added
import 'package:finazaap/Screens/annual_projection_screen.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class ResponsibilityDashboardCard extends StatefulWidget {
  final List<dynamic> responsibilities;
  final int selectedMonth;
  final int selectedYear;
  final Function(int day, int month, int year) onDateSelected;

  const ResponsibilityDashboardCard({
    Key? key,
    required this.responsibilities,
    required this.selectedMonth,
    required this.selectedYear,
    required this.onDateSelected,
  }) : super(key: key);

  @override
  State<ResponsibilityDashboardCard> createState() => _ResponsibilityDashboardCardState();
}

class _ResponsibilityDashboardCardState extends State<ResponsibilityDashboardCard> {
  bool _isLocaleInitialized = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es').then((_) {
      if (mounted) {
        setState(() {
          _isLocaleInitialized = true;
        });
      }
    });
  }

  String _formatDate(int month, int year) {
    if (!_isLocaleInitialized) {
      return 'Cargando...';
    }
    final date = DateTime(year, month);
    return DateFormat.yMMMM('es').format(date);
  }

  void _showDateSelector(BuildContext context) {
    int localMonth = widget.selectedMonth;
    int localYear = widget.selectedYear;
    // localDay removed
    

    final List<String> monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Seleccionar Fecha",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: AlertDialog(
              backgroundColor: context.appTheme.secondaryCardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              contentPadding: EdgeInsets.zero,
              content: SizedBox(
                width: 340,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent),
                              const SizedBox(width: 12),
                              Text('Filtrar Fecha', style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                              const Spacer(),
                              // Botón "Hoy"
                              TextButton(
                                onPressed: () {
                                    final now = DateTime.now();
                                    setState(() {
                                      localMonth = now.month;
                                      localYear = now.year;
                                    });
                                },
                                child: const Text('Hoy', style: TextStyle(color: Colors.blueAccent)),
                              )
                            ],
                          ),
                        ),
                        
                        // Selector Año
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              _buildDirButton(Icons.chevron_left_rounded, () {
                                setState(() => localYear--);
                              }),
                              Expanded(
                                child: Center(
                                  child: Text(
                                    localYear.toString(),
                                    style: TextStyle(color: context.appTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              _buildDirButton(Icons.chevron_right_rounded, () {
                                setState(() => localYear++);
                              }),
                            ],
                          ),
                        ),
                        
                        // Selector Meses Grid
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4, // 4 columnas es más compacto
                              childAspectRatio: 1.8,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: 12,
                            itemBuilder: (context, index) {
                              final m = index + 1;
                              final isSel = localMonth == m;
                              return GestureDetector(
                                onTap: () {
                                  setState(() => localMonth = m);
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isSel ? Colors.blueAccent : context.appTheme.darkBackground,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isSel ? Colors.blueAccent : context.appTheme.borderSubtle),
                                  ),
                                  child: Center(
                                    child: Text(
                                      monthNames[index].substring(0, 3),
                                      style: TextStyle(
                                        color: isSel ? Colors.white : context.appTheme.textSecondary,
                                        fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Selector Día Eliminado
                        SizedBox(height: 0),


                        const SizedBox(height: 24),
                        
                        // Botones
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text('Cancelar', style: TextStyle(color: context.appTheme.textSecondary)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  onPressed: () {
                                    widget.onDateSelected(1, localMonth, localYear); // Fixed 1
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 50,
        height: 50,
        alignment: Alignment.center,
        child: Icon(icon, color: Colors.white70),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAmount = ResponsibilityService.calculateMonthlyTotal(
      month: widget.selectedMonth,
      year: widget.selectedYear,
    );
    final paidVsPending = ResponsibilityService.calculatePaidVsPending(
      month: widget.selectedMonth, 
      year: widget.selectedYear,
    );
    final paid = paidVsPending['paid'] ?? 0.0;
    final pending = paidVsPending['pending'] ?? 0.0;
    final progress = totalAmount > 0 ? (paid / totalAmount) : 0.0;
    final percentage = (progress * 100).round();

    final allResponsibilities = ResponsibilityService.getAllResponsibilities();
    final annualProjection = allResponsibilities
        .where((r) => r.safeCategory != 'tarjeta')
        .fold(0.0, (sum, r) => sum + r.getAnnualAmount());

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appTheme.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: context.appTheme.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILA SUPERIOR: Título, Valor y Selector de Fecha debajo
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Obligaciones del Mes',
                style: TextStyle(
                  color: context.appTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyHelper.format(totalAmount),
                style: TextStyle(
                  color: context.appTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Botón Selector de Fecha y Proyección Anual
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  InkWell(
                    onTap: () => _showDateSelector(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.appTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.appTheme.borderVisible),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month, size: 14, color: context.appTheme.textPrimary),
                          const SizedBox(width: 8),
                          Text(
                             _formatDate(widget.selectedMonth, widget.selectedYear),
                            style: TextStyle(
                              color: context.appTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AnnualProjectionScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.appTheme.darkBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.appTheme.borderVisible),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.trending_up_rounded, size: 14, color: context.appTheme.accent),
                          const SizedBox(width: 8),
                          Text(
                            'Proy. Anual: ${CurrencyHelper.format(annualProjection, decimalDigits: 0)}',
                            style: TextStyle(
                              color: context.appTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // BARRA DE PROGRESO HORIZONTAL (Reemplaza al círculo)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Progreso de pago',
                    style: TextStyle(
                      color: context.appTheme.textHint,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: percentage == 100 ? context.appTheme.success : context.appTheme.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: context.appTheme.darkBackground,
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOutCubic,
                        height: 10,
                        width: constraints.maxWidth * (progress > 1 ? 1 : progress),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              percentage == 100 ? context.appTheme.success : context.appTheme.accent,
                              percentage == 100 ? context.appTheme.success.withValues(alpha: 0.8) : context.appTheme.secondaryAccent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: (percentage == 100 ? context.appTheme.success : context.appTheme.accent).withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // FILA INFERIOR: Pagado y Pendiente (Similar a Egresos/Ingresos)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  margin: const EdgeInsets.only(right: 4.0),
                  decoration: BoxDecoration(
                    color: context.appTheme.primaryBackground,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: context.appTheme.success, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Pagado',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyHelper.formatCompact(paid),
                        style: TextStyle(
                          color: context.appTheme.success,
                          fontSize: 18,
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
                    color: context.appTheme.primaryBackground,
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.pending_rounded, color: context.appTheme.expense, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Pendiente',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyHelper.formatCompact(pending),
                        style: TextStyle(
                          color: context.appTheme.expense,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

}
