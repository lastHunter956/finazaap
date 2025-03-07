import 'package:flutter/material.dart';
import 'package:finazaap/widgets/floating_action_menu.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FinazaApp'),
      ),
      body: Center(
        child: const Text('Contenido principal'),
      ),
      floatingActionButton: const FloatingActionMenu(),
    );
  }
}