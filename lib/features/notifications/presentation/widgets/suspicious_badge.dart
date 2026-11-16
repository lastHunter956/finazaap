import 'package:flutter/material.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';

/// Insignia visual para categorizar el nivel de confianza y riesgo de una transacción pendiente.
///
/// Estados admitidos:
/// - **Sospechosa / Alerta:** Fondo y borde [AppColors.error] (URLs, fraude o señales de alarma).
/// - **Revisión Requerida:** Fondo y borde [AppColors.warning] (baja confianza < 0.85 o ambigüedad).
/// - **Alta Confianza:** Fondo y borde [AppColors.success] (apta para lote).
class SuspiciousBadge extends StatelessWidget {
  final String classification;
  final double confidence;
  final bool requiresReview;
  final List<String> flags;
  final bool compact;

  const SuspiciousBadge({
    super.key,
    required this.classification,
    required this.confidence,
    this.requiresReview = false,
    this.flags = const [],
    this.compact = false,
  });

  factory SuspiciousBadge.fromItem(
    PendingTransactionItem item, {
    Key? key,
    bool compact = false,
  }) {
    return SuspiciousBadge(
      key: key,
      classification: item.classification,
      confidence: item.confidence,
      requiresReview: item.requiresReview,
      flags: item.flags,
      compact: compact,
    );
  }

  bool get isSuspicious =>
      classification == 'sospechosa' ||
      flags.contains('anti_fraud_link_detected');

  bool get isReviewRequired => requiresReview || confidence < 0.85;

  @override
  Widget build(BuildContext context) {
    final t =
        Theme.of(context).extension<AppTheme>() ??
        AppTheme.forMode(ThemeNotifier.activeMode);
    final Color badgeColor;
    final IconData icon;
    final String label;

    if (isSuspicious) {
      badgeColor = t.error;
      icon = Icons.warning_amber_rounded;
      label = 'Sospechosa';
    } else if (isReviewRequired) {
      badgeColor = t.warning;
      icon = Icons.help_outline_rounded;
      final percent = (confidence * 100).round();
      label = compact ? '$percent%' : 'Revisar ($percent%)';
    } else {
      badgeColor = t.success;
      icon = Icons.check_circle_outline_rounded;
      final percent = (confidence * 100).round();
      label = compact ? '$percent%' : 'Alta confianza ($percent%)';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: badgeColor,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
