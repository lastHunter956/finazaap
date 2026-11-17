import 'package:flutter/material.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/widgets/suspicious_badge.dart';
import 'package:finazaap/themes/app_theme_data.dart';
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
    final theme = Theme.of(context).extension<AppTheme>() ??
        AppTheme.forMode(ThemeNotifier.activeMode);
    final merchantTitle = item.comercio ??
        (item.merchantKey != null && item.merchantKey!.isNotEmpty
            ? item.merchantKey!
            : (isSuspicious ? 'Alerta de Seguridad' : 'Comercio no detectado'));

    final amountText = CurrencyHelper.format(item.monto ?? 0.0);
    final typeColor = _resolveTypeColor(theme);
    final borderColor = isSuspicious
        ? theme.error.withValues(alpha: 0.45)
        : item.requiresReview
            ? theme.warning.withValues(alpha: 0.35)
            : Colors.transparent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: borderColor == Colors.transparent
            ? null
            : Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cabecera: Ícono circular + Comercio + Insignia
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _resolveCategoryIcon(),
                    size: 19,
                    color: typeColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        merchantTitle,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.category ?? (isSuspicious ? 'Fraude' : 'Otros')} · ${_formatDate(item.fecha)}',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 0,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 150),
                    child: SuspiciousBadge.fromItem(item),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Monto + Cuenta
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      amountText,
                      maxLines: 1,
                      style: TextStyle(
                        color: _resolveAmountColor(theme),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _buildAccountSubtitle(),
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Texto crudo de la notificación (compacto, nunca enlace clickable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.darkBackground.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.rawText,
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 11.5,
                  height: 1.35,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Alerta si es sospechosa
            if (isSuspicious) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: theme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.flags.contains('anti_fraud_link_detected')
                            ? 'Enlace web detectado. Por política conservadora de revisión, no se procesa automáticamente y requiere revisión manual.'
                            : 'Enlace sospechoso o texto de urgencia detectado. Se bloqueó la adición automática de saldos.',
                        style: TextStyle(
                          color: theme.error,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(height: 1, color: theme.borderSubtle),
            const SizedBox(height: 10),

            // Acciones balanceadas: Descartar, Corregir, Confirmar
            SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                    onPressed: onDiscard,
                    style: TextButton.styleFrom(
                      foregroundColor: theme.textSecondary,
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text('Descartar', style: TextStyle(fontSize: 13)),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: onCorrect,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.accent,
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          side: BorderSide(
                            color: theme.accent.withValues(alpha: 0.55),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Corregir',
                            style: TextStyle(fontSize: 13)),
                      ),
                      ElevatedButton(
                        onPressed: isSuspicious ? null : onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.buttonBackground,
                          foregroundColor: theme.buttonForeground,
                          disabledBackgroundColor:
                              theme.borderSubtle.withValues(alpha: 0.25),
                          disabledForegroundColor: theme.textHint,
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _resolveTypeColor(AppTheme theme) {
    if (isSuspicious) return theme.error;
    if (item.classification == 'ingreso') return theme.income;
    if (item.classification == 'transferencia-propia') return theme.accent;
    return theme.expense;
  }

  Color _resolveAmountColor(AppTheme theme) {
    if (isSuspicious) return theme.error;
    if (item.classification == 'ingreso') return theme.income;
    if (item.classification == 'transferencia-propia') return theme.accent;
    return theme.textPrimary;
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
