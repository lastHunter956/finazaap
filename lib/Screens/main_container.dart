import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/Screens/home.dart';
import 'package:finazaap/Screens/statistics.dart';
import 'package:finazaap/Screens/responsibilities_screen.dart';
import 'package:finazaap/Screens/categories_screen.dart';
import 'package:finazaap/Screens/settings_screen.dart';
import 'package:finazaap/widgets/custom_pill_bottom_nav_bar.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/providers/pin_provider.dart';
import 'package:finazaap/Screens/pin_code_screen.dart';

class MainContainer extends StatefulWidget {
  final PinProvider? pinProvider;
  final Duration relockThreshold;

  const MainContainer({
    super.key,
    this.pinProvider,
    this.relockThreshold = const Duration(seconds: 30),
  });

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final Set<int> _loadedTabs = {0};
  late final PinProvider _pinProvider;
  DateTime? _pausedAt;
  bool _isLockScreenVisible = false;

  @override
  void initState() {
    super.initState();
    _pinProvider = widget.pinProvider ?? PinProvider();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      NotificationPipelineService.instance.syncOnResume();
      final pausedAt = _pausedAt;
      _pausedAt = null;
      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= widget.relockThreshold) {
        _enforcePinOnResume();
      }
    }
  }

  Future<void> _enforcePinOnResume() async {
    if (_isLockScreenVisible || !mounted) return;
    await _pinProvider.ensureInitialized();
    if (!mounted || !_pinProvider.isPinEnabled || _isLockScreenVisible) return;

    _isLockScreenVisible = true;
    try {
      if (_pinProvider.isBiometricEnabled) {
        final ok = await _pinProvider.authenticateWithBiometrics();
        if (ok) return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => PinCodeScreen(
            mode: PinMode.verify,
            pinProvider: _pinProvider,
            onSuccess: (ctx) {
              Navigator.of(ctx).pop();
            },
          ),
        ),
      );
    } finally {
      _isLockScreenVisible = false;
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      const Home(),
      _loadedTabs.contains(1)
          ? const ResponsibilitiesScreen()
          : const SizedBox.shrink(),
      _loadedTabs.contains(2)
          ? CategoriesScreen(activeIndex: _currentIndex)
          : const SizedBox.shrink(),
      _loadedTabs.contains(3) ? const Statistics() : const SizedBox.shrink(),
      _loadedTabs.contains(4)
          ? const SettingsScreen()
          : const SizedBox.shrink(),
    ];

    final isDiurno = context.isDiurno;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final tabTransitionDuration =
        disableAnimations ? Duration.zero : const Duration(milliseconds: 160);
    final navHeight = MoneoLayoutMetrics.bottomNavBarHeight(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final effectiveBottomClearance = math.max(0.0, navHeight - bottomInset);

    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      extendBody: isDiurno,
      body: Builder(
        builder: (bodyContext) {
          final mq = MediaQuery.of(bodyContext);
          final bodyMediaQuery = isDiurno
              ? mq.copyWith(
                  padding: mq.padding.copyWith(
                    bottom: math.max(mq.padding.bottom, effectiveBottomClearance),
                  ),
                  viewPadding: mq.viewPadding.copyWith(
                    bottom: math.max(
                      mq.viewPadding.bottom,
                      effectiveBottomClearance,
                    ),
                  ),
                )
              : mq;

          return MoneoNavBarScope(
            navBarHeight: navHeight,
            extendBody: isDiurno,
            child: MediaQuery(
              data: bodyMediaQuery,
              child: IndexedStack(
                index: _currentIndex,
                children: List<Widget>.generate(screens.length, (index) {
                  final isActive = _currentIndex == index;
                  return AnimatedOpacity(
                    opacity: isActive ? 1.0 : 0.0,
                    duration: tabTransitionDuration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedSlide(
                      offset: isActive ? Offset.zero : const Offset(0, 0.015),
                      duration: tabTransitionDuration,
                      curve: Curves.easeOutCubic,
                      child: screens[index],
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: RepaintBoundary(
        child: CustomPillBottomNavBar(
          selectedIndex: _currentIndex,
          onItemSelected: _onTabTapped,
        ),
      ),
    );
  }
}
