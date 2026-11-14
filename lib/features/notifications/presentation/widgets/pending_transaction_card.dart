import 'package:flutter/material.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/widgets/suspicious_badge.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/utils/currency_helper.dart';

/// Tarjeta de presentación de una transacción bancaria detectada y pendiente de revisión.
///
/// Componente accesible y adaptable que exhibe comercio, monto formateado,
/// clasificación sugerida, insignia de confianza y acciones de confirmación,
/// corrección y descarte.
class PendingTransactionCard extends StatelessWidget {
  final PendingTransactionItem item;
  final VoidCallback onConfirm;
  final VoidCallback onCorrect;
  final VoidCallback onDiscard;

  const PendingTransactionCard({
    super.key,
    required this.item,
    required this.onConfirm,
    required this.onCorrect,
    required this.onDiscard,
  });

  bool get isSuspicious => item.classification == 'sospechosa';

  @override
  Widget build(BuildContext context) {
    final merchantTitle = item.comercio ??
        (item.merchantKey != null && item.merchantKey!.isNotEmpty
            ? item.merchantKey!
            : (isSuspicious ? 'Alerta de Seguridad' : 'Comercio no detectado'));

    final amountText = CurrencyHelper.format(item.monto ?? 0.0);
    final borderColor = isSuspicious
        ? AppColors.error.withValues(alpha: 0.5)
        : AppColors.borderSubtle;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Comercio + Insignia
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    merchantTitle,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                SuspiciousBadge.fromItem(item),
              ],
            ),
            const SizedBox(height: 8),

            // Monto + Cuenta / Categoría
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  amountText,
                  style: TextStyle(
                    color: _resolveAmountColor(),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Flexible(
                  child: Text(
                    _buildAccountSubtitle(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Categoría y fecha
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _resolveCategoryIcon(),
                      size: 13,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.category ?? (isSuspicious ? 'Fraude' : 'Otros'),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Text(
                  _formatDate(item.fecha),
                  style: TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),

            // Alerta si es sospechosa
            if (isSuspicious) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.flags.contains('anti_fraud_link_detected')
                            ? 'Enlace web detectado. Por política conservadora de revisión, no se procesa automáticamente y requiere revisión manual.'
                            : 'Enlace sospechoso o texto de urgencia detectado. Se bloqueó la adición automática de saldos.',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 20),

            // Acciones: Descartar, Corregir, Confirmar
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onDiscard,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text('Descartar'),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: onCorrect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: BorderSide(color: AppColors.accent),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Corregir'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: isSuspicious ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: AppColors.primaryBackground,
                    disabledBackgroundColor:
                        AppColors.borderSubtle.withValues(alpha: 0.3),
                    disabledForegroundColor: AppColors.textHint,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Confirmar',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveAmountColor() {
    if (isSuspicious) return AppColors.error;
    if (item.classification == 'ingreso') return AppColors.income;
    if (item.classification == 'transferencia-propia') return AppColors.accent;
    return AppColors.textPrimary;
  }

  IconData _resolveCategoryIcon() {
    switch (item.classification) {
      case 'ingreso':
        return Icons.arrow_downward_rounded;
      case 'transferencia-propia':
        return Icons.swap_horiz_rounded;
      case 'sospechosa':
        return Icons.warning_amber_rounded;
      case 'gasto':
      default:
        return Icons.shopping_bag_outlined;
    }
  }

  String _buildAccountSubtitle() {
    if (item.classification == 'transferencia-propia') {
      final origin = item.accountName ?? 'Origen no asignado';
      final dest = item.destinationAccount ?? 'Destino no asignado';
      return '$origin → $dest';
    }
    return item.accountName ??
        (isSuspicious ? 'Sin cuenta' : 'Pendiente cuenta');
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    if (isToday) {
      return 'Hoy $hour:$minute';
    }
    return '${dt.day}/${dt.month} $hour:$minute';
  }
}
