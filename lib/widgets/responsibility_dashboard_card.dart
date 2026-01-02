import 'package:flutter/material.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:finazaap/utils/currency_helper.dart'; // Import added
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:gradient_borders/gradient_borders.dart';

class ResponsibilityDashboardCard extends StatefulWidget {
  final int month;
  final int year;
  final Function(int month, int year) onDateSelected;

  const ResponsibilityDashboardCard({
    Key? key,
    required this.month,
    required this.year,
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

  void _showMonthYearSelector() {
    int localMonth = widget.month;
    int localYear = widget.year;
    
    const double cornerRadius = 24.0;
    final Color accentColor = const Color(0xFF4A80F0);
    final Color surfaceColor = const Color(0xFF222939);
    final Color cardColor = const Color(0xFF1A1F2B);
    
    final List<String> monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Selector de período",
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            final curveAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuint,
              reverseCurve: Curves.easeInQuint,
            );
            
            final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(curveAnimation);
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0.1, 1.0))
            );
            final blurAnimation = Tween<double>(begin: 20, end: 0).animate(curveAnimation);
            
            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Center(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurAnimation.value,
                      sigmaY: blurAnimation.value,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.87,
                        constraints: const BoxConstraints(
                          maxWidth: 400,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(cornerRadius),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                              spreadRadius: -5,
                            ),
                          ],
                          border: GradientBoxBorder(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.15),
                                accentColor.withOpacity(0.2),
                                Colors.white.withOpacity(0.02),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                            width: 1.5,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(cornerRadius),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Cabecera
                              Container(
                                padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withOpacity(0.22),
                                      accentColor.withOpacity(0.10),
                                      accentColor.withOpacity(0.05),
                                    ],
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Seleccionar período',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Ver obligaciones de otro mes',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: cardColor.withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.white.withOpacity(0.07)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.calendar_today_rounded, size: 16, color: accentColor),
                                          const SizedBox(width: 8),
                                          Text(
                                            "${monthNames[localMonth-1]} $localYear",
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Selector de Año
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildDirButton(Icons.chevron_left_rounded, () {
                                        setState(() => localYear--);
                                        HapticFeedback.lightImpact();
                                      }),
                                      Expanded(
                                        child: Center(
                                          child: Text(
                                            localYear.toString(),
                                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      _buildDirButton(Icons.chevron_right_rounded, () {
                                        setState(() => localYear++);
                                        HapticFeedback.lightImpact();
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Grid de Meses
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                child: GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 2.2,
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
                                        HapticFeedback.selectionClick();
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSel ? accentColor : cardColor,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: isSel ? accentColor : Colors.white.withOpacity(0.08)),
                                        ),
                                        child: Center(
                                          child: Text(
                                            monthNames[index].substring(0, 3),
                                            style: TextStyle(
                                              color: isSel ? Colors.white : Colors.white70,
                                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                              
                              // Botones
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text('Cancelar', style: TextStyle(color: Colors.white.withOpacity(0.6))),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: accentColor,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        onPressed: () {
                                          widget.onDateSelected(localMonth, localYear);
                                          Navigator.pop(context);
                                          HapticFeedback.mediumImpact();
                                        },
                                        child: const Text('Aplicar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
              ),
            );
          },
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
    final monthlyTotal = ResponsibilityService.calculateMonthlyTotal();
    final paidVsPending = ResponsibilityService.calculatePaidVsPending(month: widget.month, year: widget.year);
    final paid = paidVsPending['paid'] ?? 0.0;
    final pending = paidVsPending['pending'] ?? 0.0;
    final progress = monthlyTotal > 0 ? (paid / monthlyTotal) : 0.0;
    final percentage = (progress * 100).round();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(42, 49, 67, 1),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 8),
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
                  color: Colors.grey.shade200,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                CurrencyHelper.format(monthlyTotal),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              // Botón Selector de Fecha movido debajo
              GestureDetector(
                onTap: _showMonthYearSelector,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2639),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month, size: 14, color: Colors.white),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(widget.month, widget.year),
                        style: const TextStyle(
                          color: Colors.white,
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
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      color: percentage == 100 ? const Color(0xFF50FA7B) : const Color(0xFF4A80F0),
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
                          color: Colors.black.withOpacity(0.2),
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
                              percentage == 100 ? const Color(0xFF50FA7B) : const Color(0xFF4A80F0),
                              percentage == 100 ? const Color(0xFF8BFEB9) : const Color(0xFF7CA8FF),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(5),
                          boxShadow: [
                            BoxShadow(
                              color: (percentage == 100 ? const Color(0xFF50FA7B) : const Color(0xFF4A80F0)).withOpacity(0.3),
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
                    color: const Color(0xFF1F2639),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF50FA7B), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Pagado',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyHelper.formatCompact(paid),
                        style: const TextStyle(
                          color: Color(0xFF50FA7B),
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
                    color: const Color(0xFF1F2639),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pending_rounded, color: Color(0xFFFF7D7D), size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'Pendiente',
                            style: TextStyle(
                              color: Colors.grey.shade300,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        CurrencyHelper.formatCompact(pending),
                        style: const TextStyle(
                          color: Color(0xFFFF7D7D),
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

  Widget _buildStatItem(String label, double amount, Color color, IconData icon) {
    // Ya no se usa directamente pero lo mantenemos por si acaso o lo borramos.
    // Lo borré en el bloque anterior para usar el diseño inline unificado.
    return Container();
  }
}
