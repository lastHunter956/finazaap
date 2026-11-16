import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class FloatingActionMenu extends StatelessWidget {
  const FloatingActionMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final buttonColor = t.buttonBackground;
    final foregroundColor = t.buttonForeground;
    final double fabRadius = isDiurno ? 18.0 : AppSizes.borderRadiusLarge;

    final ShapeBorder fabShape = isDiurno
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fabRadius),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.5,
            ),
          )
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(fabRadius),
          );

    final Widget fab = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(fabRadius),
        shape: BoxShape.rectangle,
        boxShadow: isLight
            ? [
                BoxShadow(
                  color: t.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Semantics(
        button: true,
        identifier: 'fab_add_operation',
        label: 'Nueva operación',
        child: FloatingActionButton(
          tooltip: 'Nueva operación',
          backgroundColor: buttonColor,
        foregroundColor: foregroundColor,
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const FloatingActionMenuScreen(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = 0.0;
                const end = 1.0;
                const curve = Curves.easeOutQuart;

                final fadeAnimation = Tween(begin: begin, end: end).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.5, curve: curve),
                  ),
                );

                final scaleAnimation = Tween(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.8, curve: curve),
                  ),
                );

                return FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                );
              },
            ),
          );
        },
        elevation: isDiurno ? 0 : 4,
        highlightElevation: isDiurno ? 2 : 8,
        shape: fabShape,
        child: Icon(
          Icons.add_rounded,
          color: foregroundColor,
          size: 32,
        ),
        ),
      ),
    );

    if (isDiurno) {
      return MoneoPressableScale(child: fab);
    }
    return fab;
  }
}