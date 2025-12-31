import 'package:flutter/material.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart';

class TransactionListWidget extends StatelessWidget {
  final Box<Add_data> box;
  final List<String> day;

  const TransactionListWidget({
    Key? key,
    required this.box,
    required this.day,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          var history = box.values.toList()[index];
          return getList(history, index);
        },
        childCount: box.length,
      ),
    );
  }

  Widget getList(Add_data history, int index) {
    return Dismissible(
      key: UniqueKey(),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        history.delete();
      },
      child: _buildTransactionItem(history),
    );
  }

  // Widget para cada transacción
  Widget _buildTransactionItem(Add_data history) {
    // Detectar si es transferencia
    bool isTransfer = history.IN == 'Transfer';
    
    // Para categoría - descripción
    String categoryDescription;
    if (isTransfer) {
      // Para transferencias: mostrar "Transferencia - descripción"
      categoryDescription = "Transferencia - ${history.detail.isNotEmpty ? history.detail : ''}";
    } else {
      // Para transacciones normales: mostrar "categoría - descripción"
      categoryDescription = "${history.explain} - ${history.detail.isNotEmpty ? history.detail : ''}";
    }
    
    // Eliminar " - " al final si no hay descripción
    if (categoryDescription.endsWith(" - ")) {
      categoryDescription = categoryDescription.substring(0, categoryDescription.length - 3);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      color: const Color(0xFF2A2A3A),
      elevation: 2,
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
                    : (history.IN == 'Income' ? Colors.green : Colors.redAccent),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3), // Borde claro para contraste
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3), // Sombra oscura estándar
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(8),
              child: Icon(
                AppIcons.getIcon(history.iconCode),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  // Cuenta o ruta de transferencia
                  Text(
                    isTransfer 
                        ? history.explain  // "Cuenta origen > Cuenta destino"
                        : history.name,     // Nombre de la cuenta
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Fecha 
                  Text(
                    '${day[history.datetime.weekday - 1]}  ${history.datetime.day}/${history.datetime.month}/${history.datetime.year}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
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
                  NumberFormat.currency(locale: 'es', symbol: '\$')
                      .format(double.parse(history.amount)),
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                    color: isTransfer 
                        ? Colors.grey // TRANSFERENCIA = GRIS
                        : (history.IN == 'Income'
                            ? const Color.fromARGB(255, 167, 226, 169) // INGRESO = VERDE
                            : const Color.fromARGB(255, 230, 172, 168)), // GASTO = ROJO
                  ),
                ),
                
                // Detalles de tarjeta de crédito (si existen)
                if (history.installments != null && history.installments != '1' && history.installments!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.4), width: 0.5),
                    ),
                    child: Text(
                      '${history.installments} cuotas',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.lightBlueAccent,
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
                      color: Colors.greenAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.greenAccent.withOpacity(0.4), width: 0.5),
                    ),
                    child: const Text(
                      'Sin interés',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.greenAccent,
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