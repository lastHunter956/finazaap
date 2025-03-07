import 'package:flutter/material.dart';
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
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                color: const Color.fromARGB(200, 255, 255, 255),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  IconData(
                    history.iconCode,
                    fontFamily: 'MaterialIcons',
                  ),
                  size: 25,
                  color: const Color.fromRGBO(31, 38, 57, 1),
                ),
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
          ],
        ),
      ),
    );
  }
}