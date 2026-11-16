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
    final int visibleCount = maxVisibleCount != null && maxVisibleCount! < items.length
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
    return Dismissible(
      key: ObjectKey(history),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        history.delete();
      },
      child: _buildTransactionItem(context, history),
    );
  }

  // Widget para cada transacción
  Widget _buildTransactionItem(BuildContext context, Add_data history) {
    // Detectar si es transferencia
    bool isTransfer = history.safeType == 'Transfer';
    
    // Para categoría - descripción
    String categoryDescription;
    if (isTransfer) {
      // Para transferencias: mostrar "Transferencia - descripción"
      categoryDescription = "Transferencia - ${history.safeDetail.isNotEmpty ? history.safeDetail : ''}";
    } else {
      // Para transacciones normales: mostrar "categoría - descripción"
      categoryDescription = "${history.safeCategory} - ${history.safeDetail.isNotEmpty ? history.safeDetail : ''}";
    }
    
    // Eliminar " - " al final si no hay descripción
    if (categoryDescription.endsWith(" - ")) {
      categoryDescription = categoryDescription.substring(0, categoryDescription.length - 3);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.appTheme.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: context.appTheme.borderSubtle,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icono de la transacción
            // Icono de la transacción con nuevo estilo
            Container(
              decoration: BoxDecoration(
                color: isTransfer
                    ? Colors.blueAccent
                    : (history.safeType == 'Income' ? Colors.green : Colors.redAccent),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3), // Borde claro para contraste
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3), // Sombra oscura estándar
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                AppIcons.getIcon(history.safeIconCode),
                size: 25,
                color: Colors.white,
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Contenido principal
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Título: Categoría - Descripción
                  Text(
                    categoryDescription,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: context.appTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Cuenta o ruta de transferencia
                  Text(
                    isTransfer 
                        ? (history.explain ?? '')  // "Cuenta origen > Cuenta destino"
                        : history.safeAccount,     // Nombre de la cuenta
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Fecha 
                  Text(
                    '${day[history.safeDate.weekday - 1]}  ${history.safeDate.day}/${history.safeDate.month}/${history.safeDate.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.w400,
                      color: context.appTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            

            
            const SizedBox(width: 8),

            // Columna derecha con Monto y detalles de tarjeta
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Monto con color según tipo
                Text(
                  CurrencyHelper.formatString(history.safeAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                    color: isTransfer 
                        ? context.appTheme.textSecondary
                        : (history.safeType == 'Income'
                            ? context.appTheme.income
                            : context.appTheme.expense),
                  ),
                ),
                
                // Detalles de tarjeta de crédito (si existen)
                if (history.installments != null && history.installments != '1' && history.installments!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.appTheme.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: context.appTheme.accent.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: Text(
                      '${history.installments} cuotas',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appTheme.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                
                if (history.isInterestFree == true) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.appTheme.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: context.appTheme.success.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: Text(
                      'Sin interés',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appTheme.success,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}