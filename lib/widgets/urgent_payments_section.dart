import 'package:flutter/material.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:finazaap/data/responsibility_service.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/show_responsibility_options.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/utils/currency_helper.dart';

class UrgentPaymentsSection extends StatelessWidget {
  final int month;
  final int year;
  final int? day; // Nuevo parámetro
  final Function(String) onTogglePaid;
  final Function(Responsibility, int, int) onTap;
  final Function(Responsibility) onEdit;
  final Function(Responsibility) onDelete;
  
  const UrgentPaymentsSection({
    Key? key,
    required this.onTogglePaid,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.month,
    required this.year,
    this.day,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Defensive filtering: Ensure we use the exact same logic that determines "Paid" 
    // to filter the list. If the UI sees it as paid (Green button), it should be hidden.
    // referenceDate logic reduced since day is always null or ignored
    DateTime? referenceDate; 
    // if (day != null) ... removed
    
    final urgentPayments = ResponsibilityService.getUrgentPayments(
        month: month, 
        year: year,
        referenceDate: referenceDate
    ).where((r) {
       // Filter out if paid TODAY (not just "in month", because we now care about day-specific paid status)
       // [REMOVIDO] Filtro diario/semanal
       // if (day != null && ...) { ... }
       return !r.isPaidInMonth(month, year);
    }).toList();

    if (urgentPayments.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFF59E0B),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Vencen esta semana',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...urgentPayments.map((r) => _buildUrgentItem(context, r)),
        ],
      ),
    );
  }

  Widget _buildUrgentItem(BuildContext context, Responsibility responsibility) {
    final daysLeft = responsibility.getDaysUntilDue();
    
    Color urgencyColor;
    IconData urgencyIcon;
    String urgencyText;

    if (daysLeft < 0) {
      urgencyColor = const Color(0xFFEF4444);
      urgencyIcon = Icons.error_outline_rounded;
      urgencyText = 'Vencido';
    } else if (daysLeft == 0) {
      urgencyColor = const Color(0xFFEF4444);
      urgencyIcon = Icons.priority_high_rounded;
      urgencyText = 'Vence hoy';
    } else if (daysLeft == 1) {
      urgencyColor = const Color(0xFFF59E0B);
      urgencyIcon = Icons.notification_important_rounded;
      urgencyText = 'Vence mañana';
    } else if (daysLeft <= 3) {
      urgencyColor = const Color(0xFFF59E0B);
      urgencyIcon = Icons.notification_important_rounded;
      urgencyText = 'Vence en $daysLeft días';
    } else {
      urgencyColor = const Color(0xFF3B82F6);
      urgencyIcon = Icons.calendar_today_rounded;
      urgencyText = 'Vence en $daysLeft días';
    }

    final isPaidInSelectedMonth = responsibility.isPaidInMonth(month, year);
    final accentColor = isPaidInSelectedMonth ? const Color(0xFF10B981) : urgencyColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color.fromRGBO(42, 49, 67, 1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showResponsibilityOptions(
            context: context,
            responsibility: responsibility,
            onEdit: (r) => onEdit(r),
            onDelete: (r) => onDelete(r),
            onPay: (r) {
              if (r.safeCategory == 'tarjeta') {
                // Para tarjetas: Redirigir a TransferScreen con monto mensual
                final monthlyAmount = r.getAmountForDate(month, year);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransferScreen(
                      initialAmount: monthlyAmount,
                      initialDestinationAccount: r.safeName,
                      initialDescription: 'Pago Cuota ${r.safeName}',
                    ),
                  ),
                );
              } else {
                onTogglePaid(r.safeId);
              }
            },
            selectedMonth: month,
            selectedYear: year,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentColor.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Indicador visual con círculo
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPaidInSelectedMonth ? Icons.check_rounded : urgencyIcon,
                    color: accentColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 14),
                
                // Contenido central flexible
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        responsibility.safeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Text(
                            isPaidInSelectedMonth ? 'PAGADO ✓' : urgencyText.toUpperCase(),
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            '•',
                            style: TextStyle(color: Colors.white.withOpacity(0.15), fontSize: 10),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              responsibility.safeCategory.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Monto y Botón de Acción
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Usar getAmountForDate que calcula dinámicamente para tarjetas
                      CurrencyHelper.format(
                        responsibility.getAmountForDate(month, year),
                        showSymbol: false,
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Botón de acción prominente
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          if (responsibility.safeCategory == 'tarjeta') {
                            // Para tarjetas: Redirigir a TransferScreen con monto mensual
                            final monthlyAmount = responsibility.getAmountForDate(month, year);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TransferScreen(
                                  initialAmount: monthlyAmount,
                                  initialDestinationAccount: responsibility.safeName,
                                  initialDescription: 'Pago Cuota ${responsibility.safeName}',
                                ),
                              ),
                            );
                          } else {
                            onTogglePaid(responsibility.safeId);
                          }
                        },
                        borderRadius: BorderRadius.circular(10),
                        splashColor: isPaidInSelectedMonth 
                            ? const Color(0xFF10B981).withOpacity(0.3)
                            : const Color(0xFF3B82F6).withOpacity(0.3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isPaidInSelectedMonth 
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : [const Color(0xFF3B82F6), const Color(0xFF2563EB)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: (isPaidInSelectedMonth 
                                    ? const Color(0xFF10B981) 
                                    : const Color(0xFF3B82F6)).withOpacity(0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPaidInSelectedMonth ? Icons.undo_rounded : Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isPaidInSelectedMonth ? 'DESHACER' : 'PAGAR',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
