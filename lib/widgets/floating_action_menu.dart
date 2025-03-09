import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finazaap/widgets/floating_action_menu_screen.dart';

class FloatingActionMenu extends StatelessWidget {
  const FloatingActionMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 82, 226, 255).withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
        shape: BoxShape.circle,
      ),
      child: FloatingActionButton(
        backgroundColor: const Color.fromARGB(255, 82, 226, 255),
        onPressed: () {
          HapticFeedback.mediumImpact();
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, animation, secondaryAnimation) => 
                const FloatingActionMenuScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
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
        elevation: 4,
        highlightElevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
        child: const Icon(
          Icons.add_rounded,
          color: Color.fromRGBO(31, 38, 57, 1),
          size: 32,
        ),
      ),
    );
  }
}