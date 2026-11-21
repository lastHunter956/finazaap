import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:finazaap/utils/currency_helper.dart';

class TransactionListWidget extends StatelessWidget {
  final Box<Add_data>? box;
  final List<Add_data>? transactions;
  final int? maxVisibleCount;
  final List<String> day;

  const TransactionListWidget({
    super.key,
    this.box,
    this.transactions,
    this.maxVisibleCount,
    required this.day,
  }) : assert(box != null || transactions != null);

  @override
  Widget build(BuildContext context) {
    final List<Add_data> items =
        transactions ?? box!.values.toList(growable: false);
    final int visibleCount =
        maxVisibleCount != null && maxVisibleCount! < items.length
            ? (maxVisibleCount! < 0 ? 0 : maxVisibleCount!)
            : items.length;

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final history = items[index];
          return getList(context, history, index);
        },
        childCount: visibleCount,
      ),
    );
  }

  Widget getList(BuildContext context, Add_data history, int index) {
    final t = context.appTheme;
    return Dismissible(
      key: ObjectKey(history),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: t.expense,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline_rounded,
          color: t.foregroundOn(t.expense),
        ),
      ),
      onDismissed: (direction) {
        history.delete();
      },
      child: _buildTransactionItem(context, history),
    );
  }

  Widget _buildTransactionItem(BuildContext context, Add_data history) {
    final t = context.appTheme;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final bool isTransfer = history.safeType == 'Transfer';
    final bool isIncome = history.safeType == 'Income';

    final String categoryDescription;
    if (isTransfer) {
      categoryDescription = history.safeDetail.isNotEmpty
          ? 'Transferencia - ${history.safeDetail}'
          : 'Transferencia';
    } else {
      categoryDescription = history.safeDetail.isNotEmpty
          ? '${history.safeCategory} - ${history.safeDetail}'
          : history.safeCategory;
    }

    final Color iconAccent = isTransfer
        ? t.accent
        : (isIncome ? t.income : t.expense);
    final IconData itemIcon = isTransfer
        ? Icons.sync_alt_rounded
        : AppIcons.getIcon(history.safeIconCode);

    final String accountLabel =
        isTransfer ? (history.explain ?? '') : history.safeAccount;
    final int weekdayIndex =
        (history.safeDate.weekday - 1).clamp(0, day.length - 1);
    final String dateLabel =
        '${day[weekdayIndex]} ${history.safeDate.day}/${history.safeDate.month}/${history.safeDate.year}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.borderSubtle,
          width: 1,
        ),
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ícono squircle tonal limpio
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconAccent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                itemIcon,
                size: 21,
                color: iconAccent,
              ),
            ),

            const SizedBox(width: 12),

            // Contenido principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryDescription,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: t.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  if (accountLabel.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      accountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: t.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    dateLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: t.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Columna derecha con monto tabular y badges de tarjeta
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 132),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      CurrencyHelper.formatString(history.safeAmount),
                      maxLines: 1,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: isTransfer
                            ? t.textSecondary
                            : (isIncome ? t.income : t.expense),
                      ),
                    ),
                  ),
                  if (history.installments != null &&
                      history.installments != '1' &&
                      history.installments!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: t.accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${history.installments} cuotas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: t.accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (history.isInterestFree == true) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: t.income.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Sin interés',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: t.income,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
