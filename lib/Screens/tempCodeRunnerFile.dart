import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        backgroundColor: Color.fromRGBO(31, 38, 57, 1), // Establecer el color de fondo
        appBar: AppBar(
          backgroundColor: Color.fromRGBO(31, 38, 57, 1), // Establecer el color de la barra superior
          title: Text('Mi Aplicación', style: TextStyle(color: Colors.white)),
        ),
        body: Center(
          child: Text(
            'Hola, mundo!',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}