import 'package:flutter/material.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:intl/intl.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Importar hive_flutter

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
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(20), // Radio del borde circular
        child: Container(
          color: const Color.fromARGB(200, 255, 255, 255), // Fondo blanco
          padding: EdgeInsets.all(8), // Espaciado interno
          child: Icon(
            IconData(
              history.iconCode, // Asegúrate de que `history.iconCode` contenga el código del icono
              fontFamily: 'MaterialIcons',
            ),
            size: 25,
            color: const Color.fromRGBO(31, 38, 57, 1), // Color del icono
          ),
        ),
      ),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            history.name,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          Text(
            " • " + history.explain, // Mostrar el campo explain
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
        ],
      ),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${day[history.datetime.weekday - 1]}  ${history.datetime.year}-${history.datetime.day}-${history.datetime.month}',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: Colors.white,
            ),
          ),
          Text(
            NumberFormat.currency(locale: 'es', symbol: '\$')
                .format(double.parse(history.amount)),
            style: TextStyle(
              fontWeight: FontWeight.w400,
              fontSize: 17,
              color: history.IN == 'Income'
                  ? const Color.fromARGB(255, 167, 226, 169)
                  : const Color.fromARGB(255, 230, 172, 168),
            ),
          ),
        ],
      ),
    );
  }
}