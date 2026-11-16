import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/data/model/responsibility.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/show_responsibility_options.dart';
import 'package:finazaap/Screens/transfer.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/data/credit_card_calculator.dart';

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
  final double? precomputedPaidInMonth;
  final double? precomputedPending;

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
    this.precomputedPaidInMonth,
    this.precomputedPending,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    
    Widget _buildSubInfo(String text, {Color? color}) {
      return this._buildSubInfo(text, t.textHint, color: color);
    }

    Widget _buildStatusChip(bool isPaid, Color color) {
      return this._buildStatusChip(isPaid, color, t.borderVisible, t.textHint, t.textSecondary);
    }

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
      statusColor = context.appTheme.textHint;
    }
    
    // Cálculos dinámicos para el resumen de tarjetas
    double paidInMonth = 0;
    double quota = responsibility.getAmountForDate(month, year);
    double pending = 0;
    
    if (responsibility.safeCategory == 'tarjeta') {
      paidInMonth = precomputedPaidInMonth ??
          CreditCardCalculator.calculatePaidInMonth(
              responsibility.safeName, month, year);
      pending = precomputedPending ??
          ((quota - paidInMonth) > 0 ? (quota - paidInMonth) : 0.0);
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
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
                // Solo las tarjetas siguen el flujo de transferencia
                if (responsibility.safeCategory == 'tarjeta') {
                   onTogglePaid();
                } else {
                  // Servicios, préstamos, membresías, etc. usan toggle directo
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
                color: context.appTheme.cardBackground.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPaidInSelectedMonth ? statusColor.withOpacity(0.2) : statusColor.withOpacity(0.12),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    context.appTheme.cardBackground,
                    context.appTheme.primaryBackground,
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
                          style: TextStyle(
                            color: context.appTheme.textPrimary,
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
                              context: context,
                            ),
                            _buildMiniBadge(
                              text: _getFrequencyLabel(responsibility),
                              color: statusColor,
                              icon: Icons.calendar_today_rounded,
                              context: context,
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
                                  'Cuota Mes: ${CurrencyHelper.format(quota)}',
                                ),
                                if (responsibility.safeCategory == 'tarjeta') ...[
                                  _buildSubInfo(
                                    'Pagado: ${CurrencyHelper.format(paidInMonth)}',
                                  ),
                                    _buildSubInfo(
                                      'Pendiente: ${CurrencyHelper.format(pending)}',
                                      color: pending > 0
                                          ? t.warning
                                          : t.income,
                                    ),
                                ],
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
                            style: TextStyle(
                              color: context.appTheme.textPrimary,
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
                        style: TextStyle(
                          color: context.appTheme.textHint,
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

  Widget _buildMiniBadge({required String text, required Color color, IconData? icon, required BuildContext context}) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    Color themedColor = color;
    if (isLight) {
      if (color.value == const Color(0xFF3B82F6).value) {
        themedColor = const Color(0xFF1D4ED8); // Dark Blue
      } else if (color.value == const Color(0xFF8B5CF6).value) {
        themedColor = const Color(0xFF6D28D9); // Dark Purple
      } else if (color.value == const Color(0xFFEF4444).value) {
        themedColor = const Color(0xFFB91C1C); // Dark Red
      } else if (color.value == const Color(0xFFF59E0B).value) {
        themedColor = const Color(0xFFB45309); // Dark Orange/Amber
      } else if (color == Colors.grey || color == context.appTheme.textHint) {
        themedColor = const Color(0xFF475569); // Dark Slate
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: themedColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: themedColor.withOpacity(0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: themedColor),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: themedColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubInfo(String text, Color defaultColor, {Color? color}) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? defaultColor,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildStatusChip(
    bool isPaid,
    Color color,
    Color borderVisibleColor,
    Color textHintColor,
    Color textSecondaryColor,
  ) {
    // In light mode the chip needs solid, readable colors
    // isPaid:    filled with the status color, white text on top
    // isPending: outlined with border, status color text (no white-on-white)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? color.withOpacity(0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPaid ? color : borderVisibleColor,
          width: isPaid ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isPaid ? Icons.check_circle : Icons.pending_actions_rounded,
            size: 12,
            color: isPaid ? color : textHintColor,
          ),
          const SizedBox(width: 6),
          Text(
            isPaid ? 'PAGADO' : 'PENDIENTE',
            style: TextStyle(
              // Use the status color itself as text — visible on both dark and light
              color: isPaid ? color : textSecondaryColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
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
        backgroundColor: context.appTheme.cardBackground,
        title: Text('Eliminar responsabilidad', style: TextStyle(color: context.appTheme.textPrimary)),
        content: Text(
          '¿Estás seguro de eliminar "${responsibility.safeName}"?',
          style: TextStyle(color: context.appTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancelar', style: TextStyle(color: context.appTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Eliminar', style: TextStyle(color: context.appTheme.error)),
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
