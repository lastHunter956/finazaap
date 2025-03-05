import 'package:flutter/material.dart';
import 'package:radial_button/widget/circle_floating_button.dart';
import 'package:finazaap/screens/add.dart';
import 'package:finazaap/screens/add_expense.dart';

class FloatingActionMenu extends StatelessWidget {
  const FloatingActionMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CircleFloatingButton.floatingActionButton(
      items: [
        FloatingActionButton(
          backgroundColor: Colors.greenAccent,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const Add_Screen()),
            );
          },
          child: const Icon(Icons.arrow_upward),
        ),
        FloatingActionButton(
          backgroundColor: Colors.indigoAccent,
          onPressed: () {
            const SnackBar snackBar = SnackBar(
              content: Text("Sincronizando datos..."),
            );
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
          },
          child: const Icon(Icons.sync_alt),
        ),
        FloatingActionButton(
          backgroundColor: Colors.orangeAccent,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
            );
          },
          child: const Icon(Icons.arrow_downward_outlined),
        ),
      ],
      color:
          const Color.fromARGB(255, 82, 226, 255), // Color del botón principal
      icon: Icons.add, // Icono del botón principal
      duration: const Duration(milliseconds: 300), // Duración de la animación
      curveAnim: Curves.ease, // Curva de animación
      useOpacity: true, // Usar opacidad
    );
  }
}