import 'package:flutter/material.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/Screens/responsibilities_screen.dart';
import 'package:finazaap/screens/categories_screen.dart';
import 'package:finazaap/screens/settings_screen.dart';
import 'package:finazaap/widgets/custom_pill_bottom_nav_bar.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({Key? key}) : super(key: key);

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const Home(),
      const ResponsibilitiesScreen(), // Nueva pantalla de responsabilidades
      const CategoriesScreen(),
      const Statistics(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: const Color.fromRGBO(31, 38, 57, 1),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: CustomPillBottomNavBar(
        selectedIndex: _currentIndex,
        onItemSelected: _onTabTapped,
      ),
    );
  }
}
