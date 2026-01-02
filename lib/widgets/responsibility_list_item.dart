import 'package:flutter/material.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/show_responsibility_options.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/utils/currency_helper.dart';

class ResponsibilityListItem extends StatelessWidget {
  final Responsibility responsibility;
  final int month;
  final int year;
  final int? day; // Día seleccionado
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTogglePaid;
  final VoidCallback? onPayMonth; // Nuevo callback opcional

  const ResponsibilityListItem({
    Key? key,
    required this.responsibility,
    required this.month,
    required this.year,
    this.day,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePaid,
    this.onPayMonth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final urgency = responsibility.getUrgencyLevel();
    // Si tenemos día específico seleccionado, verificamos si está pagado ESE día
    final isPaidInSelectedMonth = (day != null) 
        ? responsibility.isPaidOnDate(DateTime(year, month, day!)) 
        : responsibility.isPaidInMonth(month, year);
        
    final categoryColor = _getCategoryColor(responsibility.safeCategory);
    Color statusColor;

    if (isPaidInSelectedMonth) {
      statusColor = const Color(0xFF27AE60);
    } else if (urgency == 'urgent') {
      statusColor = const Color(0xFFE53935);
    } else if (urgency == 'upcoming') {
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusColor = Colors.white.withOpacity(0.4);
    }

    return Dismissible(
      key: Key(responsibility.safeId),
      background: _buildSwipeBackground(
        alignment: Alignment.centerLeft,
        color: const Color(0xFF27AE60),
        icon: Icons.check_circle_rounded,
        label: 'Marcar Pago',
      ),
      secondaryBackground: _buildSwipeBackground(
        alignment: Alignment.centerRight,
        color: const Color(0xFFE53935),
        icon: Icons.delete_forever_rounded,
        label: 'Eliminar',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onTogglePaid();
          return false;
        } else {
          return await _confirmDelete(context);
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          onDelete();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => showResponsibilityOptions(
              context: context,
              responsibility: responsibility,
              onEdit: (resp) {
                onEdit();
              },
              onDelete: (resp) {
                onDelete();
              },
              onPay: (resp) {
                if (responsibility.safeCategory == 'tarjeta') {
                   // Lógica de tarjeta (ya manejada por onTogglePaid en el padre)
                   onTogglePaid();
                } else {
                  onTogglePaid();
                }
              },
              selectedMonth: month,
              selectedYear: year,
            ),
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(42, 49, 67, 1).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaid ? statusColor.withOpacity(0.3) : statusColor.withOpacity(0.2),
                  width: 1.5,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color.fromRGBO(42, 49, 67, 1),
                    const Color.fromRGBO(31, 38, 57, 1),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Icon with specific glow based on category
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: categoryColor.withOpacity(0.3), width: 1),
                    ),
                    child: Center(
                      child: Icon(
                        IconData(responsibility.safeIconCode, fontFamily: 'MaterialIcons'),
                        color: categoryColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Middle Section: Name and Category/Due
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          responsibility.safeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _buildMiniBadge(
                              text: responsibility.safeCategory.toUpperCase(),
                              color: categoryColor,
                            ),
                            _buildMiniBadge(
                              text: _getFrequencyLabel(responsibility),
                              color: statusColor,
                              icon: Icons.calendar_today_rounded,
                            ),
                          ],
                        ),
                        // Información extra para tarjetas/préstamos con lógica dinámica
                        if (responsibility.safeCategory == 'tarjeta' || responsibility.safeCategory == 'préstamo')
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubInfo(
                                  'Deuda Total: ${CurrencyHelper.format(responsibility.dynamicCardBalance)}',
                                ),
                                const SizedBox(height: 2),
                                _buildSubInfo(
                                  'Cuota Mes: ${CurrencyHelper.format(responsibility.safeCategory == 'tarjeta' || responsibility.safeCategory == 'préstamo' ? responsibility.getDynamicQuota(month, year) : responsibility.safeAmount)}',
                                ),
                                if (responsibility.installments != null && responsibility.installments! > 1)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: _buildSubInfo('Plazo: ${responsibility.installments} cuotas'),
                                  ),
                              ],
                            ),
                          ),
                        // Mostrar Total Mensual para frecuencias cortas (diario/semanal)
                        if (['diario', 'semanal', 'quincenal'].contains(responsibility.safeFrequency))
                           Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: _buildSubInfo(
                              'Mensual: ${CurrencyHelper.format(responsibility.getMonthlyAmount())}',
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Right Section: Amount and Paid Status
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 90),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            CurrencyHelper.format(
                              // Para visualización principal, usamos el monto BASE (unitario) para frecuencias cortas
                              // Para tarjetas y mensuales, usamos el getAmountForDate
                              (['diario', 'semanal', 'quincenal'].contains(responsibility.safeFrequency))
                                  ? responsibility.safeAmount
                                  : responsibility.getAmountForDate(month, year),
                              showSymbol: false,
                            ),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        ['diario', 'semanal', 'quincenal'].contains(responsibility.safeFrequency)
                          ? '${CurrencyHelper.currencyCode} / ${_getShortFrequency(responsibility.safeFrequency)}'
                          : CurrencyHelper.currencyCode,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusChip(isPaidInSelectedMonth, statusColor),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniBadge({required String text, required Color color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubInfo(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.4),
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStatusChip(bool isPaid, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? color.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid ? color.withOpacity(0.5) : Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.pending_actions_rounded,
            size: 12,
            color: isPaid ? color : Colors.white24,
          ),
          const SizedBox(width: 6),
          Text(
            isPaid ? 'PAGADO' : 'PENDIENTE',
            style: TextStyle(
              color: isPaid ? color : Colors.white38,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  bool get isPaid => responsibility.isPaidInMonth(month, year);

  Widget _buildSwipeBackground({
    required Alignment alignment,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color.fromRGBO(42, 49, 67, 1),
        title: const Text('Eliminar responsabilidad', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Estás seguro de eliminar "${responsibility.safeName}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    ) ?? false;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'servicio':
        return const Color(0xFF3B82F6); // Blue
      case 'membresía':
        return const Color(0xFF8B5CF6); // Purple
      case 'tarjeta':
        return const Color(0xFFEF4444); // Red
      case 'préstamo':
        return const Color(0xFFF59E0B); // Orange
      default:
        return Colors.grey;
    }
  }

  String _getFrequencyLabel(Responsibility r) {
    final freq = r.safeFrequency;
    if (freq == 'diario') return 'DIARIO';
    if (freq == 'semanal') {
      const days = ['DOM', 'LUN', 'MAR', 'MIÉ', 'JUE', 'VIE', 'SÁB', 'DOM'];
      int idx = r.safeDueDay; // 1=Lunes..7=Domingo (pero a veces 0?)
      if (idx < 1 || idx > 7) idx = 1; 
      // Si idx=1 (Lunes), en array days[1] = 'LUN'. Correcto.
      // Si idx=7 (Domingo), days[7] = 'DOM'. Correcto.
      return 'CADA ${days[idx]}';
    }
    if (freq == 'quincenal') return 'QUINCENAL (${r.safeDueDay})';
    if (freq == 'mensual') return 'DÍA ${r.safeDueDay}';
    return freq.toUpperCase();
  }

  String _getShortFrequency(String freq) {
    switch (freq) {
      case 'diario': return 'día';
      case 'semanal': return 'sem';
      case 'quincenal': return 'qcn';
      case 'mensual': return 'mes';
      case 'bimestral': return '2m';
      case 'trimestral': return '3m';
      case 'anual': return 'año';
      default: return 'mes';
    }
  }
}
