import 'package:flutter/material.dart';
import 'package:radial_button/widget/circle_floating_button.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart'; // Importar la nueva pantalla

class FloatingActionMenu extends StatelessWidget {
  const FloatingActionMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      backgroundColor: const Color.fromARGB(255, 82, 226, 255),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const FloatingActionMenuScreen()),
        );
      },
      child: const Icon(Icons.add),
    );
  }
}