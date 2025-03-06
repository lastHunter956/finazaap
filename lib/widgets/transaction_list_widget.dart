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
      onDismissed: (direction) {
        history.delete();
      },
      child: get(index, history),
    );
  }

  ListTile get(int index, Add_data history) {
  // Usemos una manera MUY explícita de detectar transferencias
  bool isTransfer = false;
  if (history.IN != null) {
    String type = history.IN.toString().trim();
    isTransfer = type == 'Transfer';
    // Debug: print("Transacción #$index - Tipo: '$type', ¿Es transferencia? $isTransfer");
  }

  return ListTile(
    leading: ClipRRect(
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
    title: Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            isTransfer ? "Transferencia" : history.name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (!isTransfer)
          Expanded(
            child: Text(
              " • ${history.explain}",
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Para transferencias, mostrar la ruta (origen > destino)
        if (isTransfer) 
          Text(
            history.category,  // Aquí tendremos "Cuenta origen > Cuenta destino"
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        
        // Mostrar descripción/detalle si existe
        if (history.detail.isNotEmpty)
          Text(
            history.detail,
            style: const TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white60,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        
        const SizedBox(height: 4),
        
        // Fila para fecha y monto
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Fecha para todos los tipos
            Text(
              '${day[history.datetime.weekday - 1]}  ${history.datetime.year}-${history.datetime.day}-${history.datetime.month}',
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
            
            // Monto con color según tipo
            Text(
              NumberFormat.currency(locale: 'es', symbol: '\$')
                  .format(double.parse(history.amount)),
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 17,
                // Color según tipo
                color: isTransfer 
                    ? Colors.grey // TRANSFERENCIA = GRIS
                    : (history.IN == 'Income'
                        ? const Color.fromARGB(255, 167, 226, 169) // INGRESO = VERDE
                        : const Color.fromARGB(255, 230, 172, 168)), // GASTO = ROJO
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
}
