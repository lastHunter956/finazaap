import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart';
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

    final ShapeBorder fabShape = isDiurno
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.92),
              width: 1.5,
            ),
          )
        : const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16.0)),
          );

    final Widget fab = Container(
      decoration: BoxDecoration(
        borderRadius: isDiurno ? BorderRadius.circular(18) : null,
        shape: isDiurno ? BoxShape.rectangle : BoxShape.circle,
        boxShadow: isDiurno
            ? [
                BoxShadow(
                  color: buttonColor.withValues(alpha: 0.32),
                  blurRadius: 16,
                  spreadRadius: -2,
                  offset: const Offset(0, 6),
                ),
                const BoxShadow(
                  color: Color(0x240B132B),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ]
            : [
                BoxShadow(
                  color: buttonColor.withValues(alpha: isLight ? 0.2 : 0.4),
                  blurRadius: 12,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: FloatingActionButton(
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
    );

    if (isDiurno) {
      return MoneoPressableScale(child: fab);
    }
    return fab;
  }
}