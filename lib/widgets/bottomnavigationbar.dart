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
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      body: screens[_selectedIndex],
      bottomNavigationBar: ResponsiveNavigationBar(
        selectedIndex: _selectedIndex,
        onTabChange: changeTab,
        textStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        navigationBarButtons: <NavigationBarButton>[
          NavigationBarButton(
            text: 'Inicio',
            icon: Icons.home,
            backgroundGradient: const LinearGradient(
              colors: [
                // Mismo color en ambas posiciones para evitar degradado
                Color.fromRGBO(42, 49, 67, 1),
                Color.fromRGBO(42, 49, 67, 1),
              ],
            ),
          ),
          NavigationBarButton(
            text: 'Estadísticas',
            icon: Icons.show_chart,
            backgroundGradient: const LinearGradient(
              colors: [
                Color.fromRGBO(42, 49, 67, 1),
                Color.fromRGBO(42, 49, 67, 1),
              ],
            ),
          ),
          NavigationBarButton(
            text: 'Categorias',
            icon: Icons.account_balance,
            backgroundGradient: const LinearGradient(
              colors: [
                Color.fromRGBO(42, 49, 67, 1),
                Color.fromRGBO(42, 49, 67, 1),
              ],
            ),
          ),
          NavigationBarButton(
            text: 'Administrar',
            icon: Icons.manage_accounts,
            backgroundGradient: const LinearGradient(
              colors: [
                Color.fromRGBO(42, 49, 67, 1),
                Color.fromRGBO(42, 49, 67, 1),
              ],
            ),
          ),
        ],
        backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      ),
    );
  }
}
