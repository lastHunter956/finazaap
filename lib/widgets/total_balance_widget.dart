import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Importar el paquete intl
import 'package:finazaap/screens/selecctaccount.dart'; // Importar MyHomePage
import 'dart:ui'; // Importar dart:ui para ImageFilter

class TotalBalanceWidget extends StatelessWidget {
  final AnimationController controller;
  final double total;
  final double income;
  final double expenses;

  const TotalBalanceWidget({
    Key? key,
    required this.controller,
    required this.total,
    required this.income,
    required this.expenses,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 110,
      left: 10,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Container(
            height: 200,
            width: 350,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: const Color.fromARGB(
                      79, 255, 255, 255), // Cambia el fondo a transparente
                  child: Column(
                    children: [
                      SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Balance total',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                                color: Colors.black, // Cambia el color a oscuro
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.more_horiz,
                                color: Colors.black, // Cambia el color a oscuro
                              ),
                              onPressed: () {
                                // Acción al presionar el botón
                                // enviar a la pestaña de selecctaccount.dart
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => MyHomePage()),
                                );
                                print('Botón flotante presionado');
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 7),
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: Row(
                          children: [
                            Text(
                              formatCurrency(total),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 25,
                                color: Colors.black, // Cambia el color a oscuro
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 25),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor:
                                      Color.fromARGB(116, 55, 55, 55),
                                  child: Icon(
                                    Icons.arrow_upward,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Ingresos',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color: Colors
                                        .black, // Cambia el color a oscuro
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor:
                                      Color.fromARGB(116, 55, 55, 55),
                                  child: Icon(
                                    Icons.arrow_downward,
                                    color: Colors.white,
                                    size: 19,
                                  ),
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Gastos',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 16,
                                    color: Colors
                                        .black, // Cambia el color a oscuro
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              formatCurrency(income),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: Colors.black, // Cambia el color a oscuro
                              ),
                            ),
                            Text(
                              formatCurrency(expenses),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                                color: const Color.fromARGB(255, 255, 153,
                                    153), // Cambia el color a oscuro
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String formatCurrency(double amount) {
    final NumberFormat formatter = NumberFormat.currency(
      locale: 'es_ES',
      symbol: '\$',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }
}
