import 'package:flutter/material.dart';
import 'package:responsive_navigation_bar/responsive_navigation_bar.dart';
import 'package:radial_button/widget/circle_floating_button.dart';
import 'package:finazaap/Screens/add.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/Screens/account_management.dart';
import 'package:finazaap/Screens/AccountsScreen.dart';

class Bottom extends StatefulWidget {
  const Bottom({Key? key}) : super(key: key);

  @override
  State<Bottom> createState() => _BottomState();
}

class _BottomState extends State<Bottom> {
  int _selectedIndex = 0;

  final List<Widget> screens = [
    const Home(),
    const Statistics(),
    AccountsScreen(),
    AccountManagement(),
  ];

  void changeTab(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(31, 38, 57, 1),
      body: screens[_selectedIndex],
      bottomNavigationBar: ResponsiveNavigationBar(
        selectedIndex: _selectedIndex,
        onTabChange: changeTab,
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        navigationBarButtons: const <NavigationBarButton>[
          NavigationBarButton(
            text: 'Inicio',
            icon: Icons.home,
            backgroundGradient: LinearGradient(
              colors: [
                Colors.yellow,
                Colors.green,
                Colors.blue,
              ],
            ),
          ),
          NavigationBarButton(
            text: 'Estadísticas',
            icon: Icons.show_chart,
            backgroundGradient: LinearGradient(
              colors: [Colors.cyan, Colors.teal],
            ),
          ),
          NavigationBarButton(
            text: 'Categorias',
            icon: Icons.account_balance,
            backgroundGradient: LinearGradient(
              colors: [Colors.green, Colors.yellow],
            ),
          ),
          NavigationBarButton(
            text: 'Administrar',
            icon: Icons.manage_accounts,
            backgroundGradient: LinearGradient(
              colors: [Colors.purple, Colors.red],
            ),
          ),
        ],
        backgroundColor:
            Color.fromRGBO(31, 38, 57, 1), // Color de fondo original
      ),
    );
  }
}
