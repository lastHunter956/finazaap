import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finazaap/themes/app_theme_data.dart';

/// Variantes estructurales de [MoneoHeaderBar] según jerarquía de navegación.
enum MoneoHeaderVariant {
  /// Pestañas raíz (`Inicio`, `Pagos`, `Categorías`, `Reportes`, `Ajustes`).
  /// Barra superior integrada a todo el ancho con jerarquía título + subtítulo.
  primaryTab,

  /// Pantallas de detalle con regreso (`Pendientes`, `Cuentas`, `Proyección Anual`, etc.).
  subScreen,

  /// Pantallas de captura o edición (`Nuevo Ingreso`, `Nuevo Egreso`, `Transferencia`).
  form,
}

/// Barra de encabezado compartida para todo el proyecto.
///
/// Contrato de uso:
/// 1. [MoneoHeaderBar.primaryTab]: Barra integrada superior (no tarjeta flotante
///    suelta) con material Liquid Glass funcional en `Diurno` y sólido en los
///    demás temas. Soporta [bottomChild] (por ejemplo un [MoneoSegmentedControl]).
/// 2. [MoneoHeaderBar.subScreen]: Encabezado compacto con botón atrás unificado,
///    título de 18px, badge o subtítulo opcional y acciones.
/// 3. [MoneoHeaderBar.form]: Encabezado ligero sobre el lienzo `primaryBackground`
///    para formularios de ingreso/egreso/transferencia sin cajas pesadas.
///
/// Para usar como `Scaffold.appBar`, utilice [asPreferredSize] o colóquelo como
/// primer hijo en un `Column` con `Expanded` debajo para permitir crecimiento
/// natural ante escalados de texto extremos.
class MoneoHeaderBar extends StatelessWidget {
  final MoneoHeaderVariant variant;
  final String title;
  final String? subtitle;
  final Color? statusDotColor;
  final Widget? badge;
  final bool showBackButton;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final Widget? bottomChild;

  const MoneoHeaderBar._({
    super.key,
    required this.variant,
    required this.title,
    this.subtitle,
    this.statusDotColor,
    this.badge,
    this.showBackButton = false,
    this.onBack,
    this.actions,
    this.bottomChild,
  });

  factory MoneoHeaderBar.primaryTab({
    Key? key,
    required String title,
    String? subtitle,
    Color? statusDotColor,
    List<Widget>? actions,
    Widget? bottomChild,
  }) {
    return MoneoHeaderBar._(
      key: key,
      variant: MoneoHeaderVariant.primaryTab,
      title: title,
      subtitle: subtitle,
      statusDotColor: statusDotColor,
      actions: actions,
      bottomChild: bottomChild,
    );
  }

  factory MoneoHeaderBar.subScreen({
    Key? key,
    required String title,
    String? subtitle,
    Widget? badge,
    bool showBackButton = true,
    VoidCallback? onBack,
    List<Widget>? actions,
    Widget? bottomChild,
  }) {
    return MoneoHeaderBar._(
      key: key,
      variant: MoneoHeaderVariant.subScreen,
      title: title,
      subtitle: subtitle,
      badge: badge,
      showBackButton: showBackButton,
      onBack: onBack,
      actions: actions,
      bottomChild: bottomChild,
    );
  }

  factory MoneoHeaderBar.form({
    Key? key,
    required String title,
    String? subtitle,
    VoidCallback? onBack,
    List<Widget>? actions,
  }) {
    return MoneoHeaderBar._(
      key: key,
      variant: MoneoHeaderVariant.form,
      title: title,
      subtitle: subtitle,
      showBackButton: true,
      onBack: onBack,
      actions: actions,
    );
  }

  /// Calcula una altura segura adaptada a `MediaQuery.textScalerOf(context)`
  /// cuando la cabecera se monta dentro de `Scaffold.appBar`.
  static double preferredHeightFor(
    BuildContext context, {
    required MoneoHeaderVariant variant,
    bool hasSubtitle = false,
    bool hasBottomChild = false,
    bool hasBadge = false,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final titleFont = switch (variant) {
      MoneoHeaderVariant.primaryTab => 26.0,
      MoneoHeaderVariant.subScreen => 19.0,
      MoneoHeaderVariant.form => 18.0,
    };
    final titleHeight = textScaler.scale(titleFont) * 1.25;
    final minRowHeight = switch (variant) {
      MoneoHeaderVariant.primaryTab => hasBadge ? 48.0 : 42.0,
      MoneoHeaderVariant.subScreen => hasBadge ? 48.0 : 39.0,
      MoneoHeaderVariant.form => 38.0,
    };
    final subtitleHeight =
        hasSubtitle ? (3.0 + textScaler.scale(12.5) * 1.45) : 0.0;
    final verticalChrome = switch (variant) {
      MoneoHeaderVariant.primaryTab => 26.0,
      MoneoHeaderVariant.subScreen => 22.0,
      MoneoHeaderVariant.form => 18.0,
    };
    final bottomExtra = hasBottomChild
        ? (12.0 + math.max(40.0, textScaler.scale(14.0) + 26.0) + 4.0)
        : 0.0;
    return math.max(minRowHeight, titleHeight) +
        subtitleHeight +
        verticalChrome +
        bottomExtra;
  }

  /// Envuelve esta barra como `PreferredSizeWidget` listo para `Scaffold.appBar`.
  PreferredSizeWidget asPreferredSize(BuildContext context) {
    final height = preferredHeightFor(
      context,
      variant: variant,
      hasSubtitle: subtitle != null && subtitle!.trim().isNotEmpty,
      hasBottomChild: bottomChild != null,
      hasBadge: badge != null,
    );
    return PreferredSize(
      preferredSize: Size.fromHeight(height),
      child: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;

    final double horizontalPad = variant == MoneoHeaderVariant.primaryTab ? 20 : 14;
    final double verticalTop = variant == MoneoHeaderVariant.primaryTab ? 14 : 10;
    final double verticalBottom = switch (variant) {
      MoneoHeaderVariant.primaryTab => bottomChild != null ? 10 : 8,
      MoneoHeaderVariant.subScreen => 10,
      MoneoHeaderVariant.form => 8,
    };

    return ColoredBox(
      color: t.primaryBackground,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPad,
            verticalTop,
            horizontalPad,
            verticalBottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopRow(context, t),
              if (bottomChild != null) ...[
                const SizedBox(height: 12),
                bottomChild!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(BuildContext context, AppTheme t) {
    final hasSubtitle = subtitle != null && subtitle!.trim().isNotEmpty;

    if (variant == MoneoHeaderVariant.form) {
      return Row(
        children: [
          _HeaderBackButton(onPressed: onBack ?? () => Navigator.maybePop(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                if (hasSubtitle) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty)
            Row(mainAxisSize: MainAxisSize.min, children: actions!)
          else
            const SizedBox(width: 40),
        ],
      );
    }

    final titleStyle = switch (variant) {
      MoneoHeaderVariant.primaryTab => TextStyle(
          color: t.textPrimary,
          fontSize: 26,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.15,
        ),
      MoneoHeaderVariant.subScreen => TextStyle(
          color: t.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.25,
          height: 1.15,
        ),
      MoneoHeaderVariant.form => TextStyle(
          color: t.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton) ...[
          _HeaderBackButton(onPressed: onBack ?? () => Navigator.maybePop(context)),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: titleStyle,
                    ),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    badge!,
                  ],
                ],
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (statusDotColor != null) ...[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: statusDotColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (actions != null && actions!.isNotEmpty) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: actions!,
          ),
        ],
      ],
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _HeaderBackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;
    return MoneoPressableScale(
      child: Material(
        color: isDiurno ? Colors.white.withValues(alpha: 0.9) : t.cardBackground,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(13),
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isDiurno ? const Color(0xC7D7EBFF) : t.borderSubtle,
                width: 1,
              ),
              boxShadow: isDiurno
                  ? const [
                      BoxShadow(
                        color: Color(0x120B132B),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: t.textPrimary,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opción individual para [MoneoSegmentedControl].
class MoneoSegmentOption<T> {
  final T value;
  final String label;

  const MoneoSegmentOption({
    required this.value,
    required this.label,
  });
}

/// Selector segmentado compartido que utiliza continuidad por [SpringSimulation]
/// únicamente en `Diurno` (respetando reducir movimiento) y renderizado sólido
/// nítido en `Día`, `Nocturno` y `Default`.
class MoneoSegmentedControl<T> extends StatelessWidget {
  final List<MoneoSegmentOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onChanged;

  const MoneoSegmentedControl({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;
    final useSpring = MoneoSpringMotion.shouldUseSpring(context);
    final selectedIndex = options.indexWhere((o) => o.value == selectedValue);
    final safeIndex = selectedIndex < 0 ? 0 : selectedIndex;
    final textHeight =
        math.max(34.0, MediaQuery.textScalerOf(context).scale(14.0) + 20.0);

    return Container(
      height: textHeight + 6,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDiurno
            ? t.darkBackground.withValues(alpha: 0.72)
            : t.darkBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.borderSubtle, width: 1),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = options.length;
          if (count == 0) return const SizedBox.shrink();
          final segmentWidth = constraints.maxWidth / count;

          return Stack(
            children: [
              _SpringSegmentPill(
                index: safeIndex,
                segmentWidth: segmentWidth,
                height: constraints.maxHeight,
                useSpring: useSpring,
                isDiurno: isDiurno,
                t: t,
              ),
              Row(
                children: options.map((opt) {
                  final isSelected = opt.value == selectedValue;
                  final Color labelColor = isDiurno
                      ? (isSelected ? t.textPrimary : t.textSecondary)
                      : (isSelected ? t.buttonForeground : t.textSecondary);

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onChanged(opt.value),
                      behavior: HitTestBehavior.opaque,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            opt.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: labelColor,
                              fontSize: 13,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SpringSegmentPill extends StatefulWidget {
  final int index;
  final double segmentWidth;
  final double height;
  final bool useSpring;
  final bool isDiurno;
  final AppTheme t;

  const _SpringSegmentPill({
    required this.index,
    required this.segmentWidth,
    required this.height,
    required this.useSpring,
    required this.isDiurno,
    required this.t,
  });

  @override
  State<_SpringSegmentPill> createState() => _SpringSegmentPillState();
}

class _SpringSegmentPillState extends State<_SpringSegmentPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController.unbounded(
      vsync: this,
      value: widget.index.toDouble(),
    );
  }

  @override
  void didUpdateWidget(covariant _SpringSegmentPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      MoneoSpringMotion.animateTo(
        _controller,
        widget.index.toDouble(),
        useSpring: widget.useSpring,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_controller.value * widget.segmentWidth, 0),
          child: child,
        );
      },
      child: SizedBox(
        width: widget.segmentWidth,
        height: widget.height,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDiurno ? widget.t.cardBackground : widget.t.buttonBackground,
            borderRadius: BorderRadius.circular(11),
            border: widget.isDiurno
                ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1)
                : null,
            boxShadow: widget.isDiurno
                ? const [
                    BoxShadow(
                      color: Color(0x140B132B),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
        ),
      ),
    );
  }
}
