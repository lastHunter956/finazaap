import 'package:flutter/material.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/utlity.dart';
import 'package:finazaap/screens/edit_profile_screen.dart';
import 'package:finazaap/screens/selecctaccount.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/widgets/header_widget.dart';
import 'package:finazaap/widgets/total_balance_widget.dart';
import 'package:finazaap/widgets/transaction_list_widget.dart';
import 'package:finazaap/widgets/month_year_selector.dart'; // integrar el widget MonthYearSelector
import 'package:finazaap/widgets/floating_action_menu.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with SingleTickerProviderStateMixin {
  var history;
  final box = Hive.box<Add_data>('data');
  final List<String> day = [
    'lunes',
    "martes",
    "miércoles",
    "jueves",
    'viernes',
    'sábado',
    'domingo'
  ];

  String _userName = 'Jesús Martinez';

  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    loadUserName((name) {
      setState(() {
        _userName = name;
      });
    });

    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateProfile(String name, XFile? profileImage) {
    setState(() {
      _userName = name;
    });
    saveUserName(name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromRGBO(31, 38, 57, 1), // Fondo de la aplicación
      body: SafeArea(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, value, child) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 110,
                    width: 350,
                    child: HeaderWidget(
                      userName: _userName,
                      updateProfile: _updateProfile,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 10,
                      right: 30,
                      top: BorderSide.strokeAlignCenter,
                      bottom: 10,
                    ),
                    child: TotalBalanceWidget(
                      controller: _controller,
                      total: total().toDouble(),
                      income: income().toDouble(),
                      expenses: expenses().toDouble(),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              width: 50,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 1),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Historial de transacciones',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'Ver todo',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      history = box.values.toList()[index];
                      return getList(history, index);
                    },
                    childCount: box.length,
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ////////
      floatingActionButton: const FloatingActionMenu(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
              history
                  .iconCode, // Asegúrate de que history.iconCode contenga el código del icono
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
