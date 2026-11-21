import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';

class CustomPillBottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomPillBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  State<CustomPillBottomNavBar> createState() => _CustomPillBottomNavBarState();
}

class _CustomPillBottomNavBarState extends State<CustomPillBottomNavBar>
    with SingleTickerProviderStateMixin {
  static const List<NavItem> _items = [
    NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Inicio',
    ),
    NavItem(
      icon: Icons.credit_card_outlined,
      activeIcon: Icons.credit_card_rounded,
      label: 'Pagos',
    ),
    NavItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'Categorías',
    ),
    NavItem(
      icon: Icons.insert_chart_outlined_rounded,
      activeIcon: Icons.insert_chart_rounded,
      label: 'Reportes',
    ),
    NavItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'Ajustes',
    ),
  ];

  late final AnimationController _selectionController;

  @override
  void initState() {
    super.initState();
    _selectionController = AnimationController.unbounded(
      vsync: this,
      value: _clampedIndex(widget.selectedIndex).toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant CustomPillBottomNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _animateSelectionTo(_clampedIndex(widget.selectedIndex).toDouble());
    }
  }

  @override
  void dispose() {
    _selectionController.dispose();
    super.dispose();
  }

  int _clampedIndex(int index) {
    return index.clamp(0, _items.length - 1);
  }

  void _animateSelectionTo(double target) {
    MoneoSpringMotion.animateTo(
      _selectionController,
      target,
      useSpring: MoneoSpringMotion.shouldUseSpring(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isDiurno = context.isDiurno;
    final t = context.appTheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final barHeight = MoneoLayoutMetrics.bottomNavPillHeight(context);
    final reducedEffects = LiquidGlassSurface.shouldReduceEffects(context);

    final unselectedColor = isDiurno
        ? t.textPrimary.withValues(alpha: 0.72)
        : t.textHint;
    final selectedIconColor = t.accent;
    final selectedLabelColor = isDiurno ? t.textPrimary : t.accent;

    final scaledExtraHeight = math.max(0.0, textScaler.scale(12.5) - 12.5);
    final itemVerticalInset = math.max(4.0, 6.0 - scaledExtraHeight * 0.15);

    return SafeArea(
      top: false,
      child: LiquidGlassSurface(
        height: barHeight,
        margin: EdgeInsets.only(
          bottom: isDiurno ? 12 : 10,
          left: isDiurno ? 14 : 10,
          right: isDiurno ? 14 : 10,
          top: isDiurno ? 6 : 10,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        borderRadius: BorderRadius.circular(35),
        blurSigma: 22.0,
        fallbackColor: t.cardBackground,
        fallbackBorderColor: t.borderSubtle,
        fallbackBoxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.3),
            blurRadius: isLight ? 18 : 15,
            offset: const Offset(0, 5),
          ),
        ],
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final maxHeight = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : barHeight - 2.0;
            final itemHeight = math.max(40.0, maxHeight - itemVerticalInset * 2);
            final selectedWidth = math.min(maxWidth * 0.34, 124.0);
            final unselectedWidth = math.max(
              0.0,
              (maxWidth - selectedWidth) / (_items.length - 1),
            );
            final maxIndex = (_items.length - 1).toDouble();

            return AnimatedBuilder(
              animation: _selectionController,
              builder: (context, _) {
                final double rawProgress = disableAnimations
                    ? _clampedIndex(widget.selectedIndex).toDouble()
                    : _selectionController.value;
                final double progress =
                    rawProgress.clamp(0.0, maxIndex).toDouble();
                final double maxPillLeft =
                    math.max(0.0, maxWidth - selectedWidth);
                final double pillLeft =
                    (progress * unselectedWidth).clamp(0.0, maxPillLeft).toDouble();

                final double pillTop = (maxHeight - itemHeight) / 2;

                return Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Positioned(
                      left: pillLeft,
                      top: pillTop,
                      width: selectedWidth,
                      height: itemHeight,
                      child: DecoratedBox(
                        key: const Key('nav_active_pill_indicator'),
                        decoration: BoxDecoration(
                          color: isDiurno
                              ? null
                              : t.accent.withValues(alpha: 0.14),
                          gradient: isDiurno
                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.96),
                                    const Color(0xFFEAF2FF),
                                  ],
                                )
                              : null,
                          borderRadius: BorderRadius.circular(24),
                          border: isDiurno
                              ? Border.all(
                                  color: reducedEffects
                                      ? t.borderSubtle
                                      : Colors.white.withValues(alpha: 0.95),
                                  width: 1.2,
                                )
                              : Border.all(
                                  color: t.accent.withValues(alpha: 0.30),
                                  width: 1.0,
                                ),
                          boxShadow: isDiurno
                              ? const [
                                  BoxShadow(
                                    color: Color(0x1F0062CC),
                                    blurRadius: 12,
                                    offset: Offset(0, 3),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: maxWidth,
                      height: maxHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(_items.length, (index) {
                        final item = _items[index];
                        final isSelected = widget.selectedIndex == index;
                        final weight =
                            (1.0 - (progress - index).abs()).clamp(0.0, 1.0);
                        final itemWidth = unselectedWidth +
                            (selectedWidth - unselectedWidth) * weight;

                        final iconSize = maxWidth < 290 ? 22.0 : 24.0;
                        final gapWidth = maxWidth < 290 ? 5.0 : 6.0;

                        final Widget baseIcon = Icon(
                          isSelected ? item.activeIcon : item.icon,
                          color: isSelected
                              ? selectedIconColor
                              : unselectedColor,
                          size: iconSize,
                        );

                        final Widget icon = index == 4
                            ? ListenableBuilder(
                                listenable: NotificationPipelineService
                                    .instance.pendingNotifier,
                                builder: (context, _) {
                                  final count = NotificationPipelineService
                                      .instance.pendingNotifier.count;
                                  if (count <= 0) return baseIcon;
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      baseIcon,
                                      Positioned(
                                        right: -2,
                                        top: -2,
                                        child: Container(
                                          key: const Key(
                                            'nav_settings_pending_dot',
                                          ),
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: t.accent,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              )
                            : baseIcon;

                        final Widget navItemContent = GestureDetector(
                          onTap: () => widget.onItemSelected(index),
                          behavior: HitTestBehavior.opaque,
                          child: Semantics(
                            button: true,
                            selected: isSelected,
                            label: item.label,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSelected ? 4.0 : 0.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  icon,
                                  if (isSelected) ...[
                                    SizedBox(width: gapWidth),
                                    Flexible(
                                      child: Text(
                                        item.label,
                                        style: TextStyle(
                                          color: selectedLabelColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );

                        return SizedBox(
                          width: itemWidth,
                          height: itemHeight,
                          child: MoneoPressableScale(
                            pressedScale: 0.94,
                            child: navItemContent,
                          ),
                        );
                      }),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
