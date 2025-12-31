import 'package:flutter/material.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/Screens/statistics.dart';
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
      const SearchPlaceholder(), // Nueva pantalla placeholder
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

// Widget placeholder temporal para la pantalla de búsqueda
class SearchPlaceholder extends StatelessWidget {
  const SearchPlaceholder({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color.fromRGBO(31, 38, 57, 1),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: Colors.white24),
            SizedBox(height: 16),
            Text(
              'Búsqueda',
              style: TextStyle(color: Colors.white54, fontSize: 18),
            ),
            Text(
              'Próximamente',
              style: TextStyle(color: Colors.white24, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
