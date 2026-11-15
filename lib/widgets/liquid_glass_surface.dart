import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'package:finazaap/themes/app_theme_data.dart';

/// Métricas dinámicas de diseño compartidas para evitar solapamientos con
/// la barra de navegación inferior, FABs, teclado y escalado de texto.
class MoneoLayoutMetrics {
  MoneoLayoutMetrics._();

  static const double _diurnoBarMarginVertical = 18.0; // top 6 + bottom 12
  static const double _solidBarMarginVertical = 20.0; // top 10 + bottom 10
  static const double _baseTextFontSize = 12.5;
  static const double fabTopGapAboveNav = 16.0;
  static const double fabClearanceExtra = 108.0;

  /// Extra vertical requerido cuando el usuario aumenta el escalado de texto.
  static double _textScaleExtra(BuildContext context) {
    final scaled = MediaQuery.textScalerOf(context).scale(_baseTextFontSize);
    return math.max(0.0, (scaled - _baseTextFontSize) * 1.6);
  }

  /// Altura interactiva de la píldora de navegación sin incluir safe area ni márgenes.
  static double bottomNavPillHeight(BuildContext context) {
    final base = context.isDiurno ? 62.0 : 60.0;
    return base + _textScaleExtra(context);
  }

  /// Altura total que ocupa `CustomPillBottomNavBar` desde el borde inferior
  /// real de la pantalla (incluyendo márgenes e inset inferior del dispositivo).
  static double bottomNavBarHeight(BuildContext context) {
    final margins =
        context.isDiurno ? _diurnoBarMarginVertical : _solidBarMarginVertical;
    final deviceBottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return bottomNavPillHeight(context) + margins + deviceBottomInset;
  }

  /// Padding inferior recomendado para listas/scrollables dentro de pestañas
  /// principales para que el último ítem nunca quede tapado por la barra o el FAB.
  static EdgeInsets scrollBottomPadding(
    BuildContext context, {
    bool hasFab = true,
    double horizontal = 16.0,
    double top = 16.0,
  }) {
    final scope = MoneoNavBarScope.maybeOf(context);
    final extendOverlap =
        (scope != null && scope.extendBody) ? scope.navBarHeight : 0.0;
    final contentGap = hasFab ? fabClearanceExtra : 20.0;
    return EdgeInsets.fromLTRB(
      horizontal,
      top,
      horizontal,
      extendOverlap + contentGap + _textScaleExtra(context),
    );
  }

  /// Clearance inferior para el `ListView` o scroll del chat sobre el composer
  /// flotante, adaptándose al escalado de texto y área segura inferior.
  static double floatingComposerClearance(BuildContext context) {
    final deviceBottom = MediaQuery.viewPaddingOf(context).bottom;
    final scaledExtra = math.max(
      0.0,
      (MediaQuery.textScalerOf(context).scale(14.5) - 14.5) * 2.2,
    );
    return 88.0 + scaledExtra + math.min(deviceBottom, 16.0);
  }
}

/// Propagación explícita de las dimensiones reales de la barra de navegación
/// inferior hacia las pestañas raíz alojadas en `MainContainer`.
class MoneoNavBarScope extends InheritedWidget {
  final double navBarHeight;
  final bool extendBody;

  const MoneoNavBarScope({
    super.key,
    required this.navBarHeight,
    required this.extendBody,
    required super.child,
  });

  static MoneoNavBarScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MoneoNavBarScope>();
  }

  @override
  bool updateShouldNotify(MoneoNavBarScope oldWidget) {
    return navBarHeight != oldWidget.navBarHeight ||
        extendBody != oldWidget.extendBody;
  }
}

/// Utilidades de física real (`SpringSimulation`) reservadas para transiciones
/// discretas de continuidad en `Diurno` cuando la accesibilidad lo permite.
class MoneoSpringMotion {
  MoneoSpringMotion._();

  static const SpringDescription responsiveSnappy = SpringDescription(
    mass: 1.0,
    stiffness: 380.0,
    damping: 30.0,
  );

  /// Indica si se debe aplicar movimiento tipo spring (exclusivo de `Diurno` y
  /// respetando la preferencia de reducir movimiento del sistema).
  static bool shouldUseSpring(BuildContext context) {
    return context.isDiurno && !MediaQuery.disableAnimationsOf(context);
  }

  /// Conduce [controller] hacia [target] mediante `SpringSimulation` real o de
  /// forma inmediata cuando las animaciones están desactivadas.
  static TickerFuture? animateTo(
    AnimationController controller,
    double target, {
    required bool useSpring,
    double velocity = 0.0,
  }) {
    if (!useSpring) {
      controller.value = target;
      return null;
    }
    final simulation = SpringSimulation(
      responsiveSnappy,
      controller.value,
      target,
      velocity,
    );
    return controller.animateWith(simulation);
  }
}

/// Respuesta táctil discreta (micro-compresión con `SpringSimulation`) que no
/// interfiere con la arena de gestos de botones o enlaces hijos.
class MoneoPressableScale extends StatefulWidget {
  final Widget child;
  final double pressedScale;

  const MoneoPressableScale({
    super.key,
    required this.child,
    this.pressedScale = 0.965,
  });

  @override
  State<MoneoPressableScale> createState() => _MoneoPressableScaleState();
}

class _MoneoPressableScaleState extends State<MoneoPressableScale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(vsync: this, value: 1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setPressed(bool pressed) {
    if (!mounted) return;
    final useSpring = MoneoSpringMotion.shouldUseSpring(context);
    if (!useSpring) {
      _controller.value = 1.0;
      return;
    }
    MoneoSpringMotion.animateTo(
      _controller,
      pressed ? widget.pressedScale : 1.0,
      useSpring: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!MoneoSpringMotion.shouldUseSpring(context)) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: ScaleTransition(
        scale: _controller,
        child: widget.child,
      ),
    );
  }
}

/// Superficie funcional inspirada en Apple HIG (Liquid Glass) exclusivamente
/// para el tema `Diurno`, priorizando la legibilidad sobre la transparencia y
/// con respaldo sólido automático ante preferencias de accesibilidad.
///
/// Solo debe envolver elementos funcionales (navegación, cabeceras funcionales
/// o composer); nunca mensajes, reportes, listas ni gráficas.
class LiquidGlassSurface extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double blurSigma;
  final double? height;
  final Color? fallbackColor;
  final Color? fallbackBorderColor;
  final double fallbackBorderWidth;
  final List<BoxShadow>? fallbackBoxShadow;

  const LiquidGlassSurface({
    super.key,
    required this.child,
    required this.borderRadius,
    this.padding,
    this.margin,
    this.blurSigma = 20.0,
    this.height,
    this.fallbackColor,
    this.fallbackBorderColor,
    this.fallbackBorderWidth = 1.0,
    this.fallbackBoxShadow,
  });

  static bool shouldReduceEffects(BuildContext context) {
    final mq = MediaQuery.maybeOf(context);
    if (mq == null) return false;
    return mq.accessibleNavigation || mq.highContrast || mq.disableAnimations;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    if (!context.isDiurno) {
      return Container(
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: fallbackColor ?? t.cardBackground,
          borderRadius: borderRadius,
          border: Border.all(
            color: fallbackBorderColor ?? t.borderSubtle,
            width: fallbackBorderWidth,
          ),
          boxShadow: fallbackBoxShadow,
        ),
        child: child,
      );
    }

    const shadows = [
      BoxShadow(
        color: Color(0x140B132B),
        blurRadius: 18,
        offset: Offset(0, 6),
        spreadRadius: -3,
      ),
    ];

    if (shouldReduceEffects(context)) {
      return Container(
        height: height,
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAFF),
          borderRadius: borderRadius,
          border: Border.all(
            color: t.borderVisible,
            width: 1.4,
          ),
          boxShadow: shadows,
        ),
        child: child,
      );
    }

    return Container(
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xEBFFFFFF), // Mayor densidad superior para legibilidad
                  Color(0xDDF4F8FF), // Tinte glacial sutil sin lavar el texto
                ],
              ),
              borderRadius: borderRadius,
              border: Border.all(
                color: const Color(0xB8C7D7EB),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
