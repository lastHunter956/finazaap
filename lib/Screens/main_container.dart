import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/Screens/responsibilities_screen.dart';
import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/widgets/custom_pill_bottom_nav_bar.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';

class MainContainer extends StatefulWidget {
  const MainContainer({Key? key}) : super(key: key);

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      NotificationPipelineService.instance.syncOnResume();
    }
  }

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
      CategoriesScreen(activeIndex: _currentIndex),
      const Statistics(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
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
