import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

/// Nombres base de las 12 familias cromáticas de [kMoneoWheelColors].
const List<String> _kHueFamilyNames = [
  'Rojo',
  'Coral',
  'Naranja',
  'Ámbar',
  'Lima',
  'Esmeralda',
  'Turquesa',
  'Cian',
  'Azul cielo',
  'Índigo',
  'Violeta',
  'Rosa',
];

/// Niveles de tono/intensidad por cada familia cromática (4 anillos).
const List<String> _kRingToneNames = [
  'suave',
  'vibrante',
  'medio',
  'profundo',
];

/// Rueda cromática accesible de 48 colores calibrados (12 familias × 4 tonos).
///
/// Ordenada por anillos concéntricos (`4 × 12 = 48`):
/// - Anillo 0 (`0..11`): tonos suaves
/// - Anillo 1 (`12..23`): tonos vibrantes
/// - Anillo 2 (`24..35`): tonos medios
/// - Anillo 3 (`36..47`): tonos profundos
///
/// Excluye blancos y negros puros para mantener visibilidad y contraste
/// en los 4 temas (`Default`, `Diurno`, `Día`, `Nocturno`) mediante
/// [AppColors.getReadableColor].
const List<Color> kMoneoWheelColors = [
  // Anillo 0: Suave (12 familias)
  Color(0xFFFF8A93), // Rojo suave
  Color(0xFFFF9E80), // Coral suave
  Color(0xFFFFBE6B), // Naranja suave
  Color(0xFFFFDF78), // Ámbar suave
  Color(0xFFC5E876), // Lima suave
  Color(0xFF7AE5A6), // Esmeralda suave
  Color(0xFF7CF2D2), // Turquesa suave
  Color(0xFF84E6FA), // Cian suave
  Color(0xFF82C4FF), // Azul cielo suave
  Color(0xFF9AA3FF), // Índigo suave
  Color(0xFFC996FA), // Violeta suave
  Color(0xFFFF94C2), // Rosa suave

  // Anillo 1: Vibrante (12 familias)
  Color(0xFFFF4D5A), // Rojo vibrante
  Color(0xFFFF6D42), // Coral vibrante
  Color(0xFFFF9F1C), // Naranja vibrante
  Color(0xFFFFCA28), // Ámbar vibrante
  Color(0xFF9EE619), // Lima vibrante
  Color(0xFF2ECC71), // Esmeralda vibrante
  Color(0xFF1DE9B6), // Turquesa vibrante
  Color(0xFF26D6F5), // Cian vibrante
  Color(0xFF38A1FF), // Azul cielo vibrante
  Color(0xFF6370FF), // Índigo vibrante
  Color(0xFFA855F7), // Violeta vibrante
  Color(0xFFF4539A), // Rosa vibrante

  // Anillo 2: Medio (12 familias)
  Color(0xFFE53935), // Rojo medio
  Color(0xFFF4511E), // Coral medio
  Color(0xFFE07A00), // Naranja medio
  Color(0xFFE0A800), // Ámbar medio
  Color(0xFF7CB342), // Lima medio
  Color(0xFF1F9D55), // Esmeralda medio
  Color(0xFF00A884), // Turquesa medio
  Color(0xFF0097B2), // Cian medio
  Color(0xFF1976D2), // Azul cielo medio
  Color(0xFF4338CA), // Índigo medio
  Color(0xFF7E22CE), // Violeta medio
  Color(0xFFD81B60), // Rosa medio

  // Anillo 3: Profundo (12 familias)
  Color(0xFFB71C1C), // Rojo profundo
  Color(0xFFBF360C), // Coral profundo
  Color(0xFFA85200), // Naranja profundo
  Color(0xFF9C6F00), // Ámbar profundo
  Color(0xFF4B7F1D), // Lima profundo
  Color(0xFF146C3B), // Esmeralda profundo
  Color(0xFF00695C), // Turquesa profundo
  Color(0xFF00607A), // Cian profundo
  Color(0xFF0D47A1), // Azul cielo profundo
  Color(0xFF2E238A), // Índigo profundo
  Color(0xFF53138E), // Violeta profundo
  Color(0xFF8E0E42), // Rosa profundo
];

/// 8 colores favoritos rápidos equilibrados en matiz para selección inmediata.
const List<Color> kMoneoQuickColors = [
  Color(0xFFFF4D5A), // Rojo vibrante
  Color(0xFFFF9F1C), // Naranja vibrante
  Color(0xFFFFCA28), // Ámbar vibrante
  Color(0xFF2ECC71), // Esmeralda vibrante
  Color(0xFF26D6F5), // Cian vibrante
  Color(0xFF38A1FF), // Azul cielo vibrante
  Color(0xFFA855F7), // Violeta vibrante
  Color(0xFFF4539A), // Rosa vibrante
];

String _describeWheelColor(int index) {
  final ring = (index ~/ 12).clamp(0, _kRingToneNames.length - 1);
  final sector = index % 12;
  return '${_kHueFamilyNames[sector]} ${_kRingToneNames[ring]}';
}

String _describeColor(Color color) {
  final argb = color.toARGB32();
  for (var i = 0; i < kMoneoWheelColors.length; i++) {
    if (kMoneoWheelColors[i].toARGB32() == argb) {
      return _describeWheelColor(i);
    }
  }
  return 'Color personalizado';
}

/// Trigger compacto de una línea para abrir o cerrar [MoneoColorPickerPanel].
class MoneoColorPickerTrigger extends StatelessWidget {
  final Color selectedColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final String label;

  const MoneoColorPickerTrigger({
    super.key,
    required this.selectedColor,
    required this.isExpanded,
    required this.onTap,
    this.label = 'Color',
  });

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final readableColor = AppColors.getReadableColor(selectedColor, context);
    final borderColor = isExpanded ? readableColor : t.borderSubtle;

    return Semantics(
      container: true,
      button: true,
      expanded: isExpanded,
      label: '$label, seleccionado',
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: 'Elegir color',
        child: Material(
          color: t.darkBackground,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(
                    AppSizes.borderRadiusMedium,
                  ),
                  border: Border.all(
                    color: borderColor,
                    width: AppSizes.borderWidthThin,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: t.borderVisible.withValues(alpha: 0.75),
                          width: AppSizes.borderWidthThin,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: t.textPrimary,
                          fontSize: AppSizes.fontLarge,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      size: AppSizes.iconMedium,
                      color: t.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ColorPickerViewMode { wheel, palette }

/// Panel inline desplegable con rueda cromática de 48 segmentos,
/// paleta táctil accesible y 8 favoritos rápidos.
class MoneoColorPickerPanel extends StatefulWidget {
  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  const MoneoColorPickerPanel({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  /// Convierte una coordenada local dentro del área de la rueda al índice
  /// `[0..47]` de [kMoneoWheelColors], o `null` si queda fuera de los 4 anillos.
  static int? hitTestWheelColorIndex(Offset localPosition, Size size) {
    if (size.width <= 0 || size.height <= 0) return null;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 4.0;
    if (outerRadius <= 8.0) return null;

    final innerRadius = outerRadius * 0.24;
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    if (distance < innerRadius || distance > outerRadius) {
      return null;
    }

    final ringStep = (outerRadius - innerRadius) / 4.0;
    final ringIndex = ((distance - innerRadius) / ringStep).floor().clamp(0, 3);

    var angle = math.atan2(dy, dx) + (math.pi / 2);
    if (angle < 0) {
      angle += 2 * math.pi;
    }
    const sweep = (2 * math.pi) / 12.0;
    final sectorIndex = (angle / sweep).floor().clamp(0, 11);

    return ringIndex * 12 + sectorIndex;
  }

  @override
  State<MoneoColorPickerPanel> createState() => _MoneoColorPickerPanelState();
}

class _MoneoColorPickerPanelState extends State<MoneoColorPickerPanel> {
  _ColorPickerViewMode _mode = _ColorPickerViewMode.wheel;
  int? _lastPanIndex;

  int get _selectedWheelIndex {
    final argb = widget.selectedColor.toARGB32();
    for (var i = 0; i < kMoneoWheelColors.length; i++) {
      if (kMoneoWheelColors[i].toARGB32() == argb) {
        return i;
      }
    }
    return -1;
  }

  void _selectFromWheelPosition(
    Offset localPosition,
    Size size, {
    required bool isPan,
  }) {
    final index = MoneoColorPickerPanel.hitTestWheelColorIndex(
      localPosition,
      size,
    );
    if (index == null) return;
    if (isPan && _lastPanIndex == index) return;
    _lastPanIndex = index;
    widget.onColorSelected(kMoneoWheelColors[index]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final readableColor = AppColors.getReadableColor(
      widget.selectedColor,
      context,
    );
    final selectedName = _describeColor(widget.selectedColor);

    return Container(
      padding: const EdgeInsets.all(AppSizes.paddingMedium),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
        border: Border.all(
          color: t.borderSubtle,
          width: AppSizes.borderWidthThin,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MoneoSegmentedControl<_ColorPickerViewMode>(
            options: const [
              MoneoSegmentOption(
                value: _ColorPickerViewMode.wheel,
                label: 'Rueda',
              ),
              MoneoSegmentOption(
                value: _ColorPickerViewMode.palette,
                label: 'Paleta',
              ),
            ],
            selectedValue: _mode,
            onChanged: (nextMode) {
              if (_mode != nextMode) {
                setState(() => _mode = nextMode);
              }
            },
          ),
          const SizedBox(height: AppSizes.paddingMedium),
          if (_mode == _ColorPickerViewMode.wheel)
            _buildWheelView(t)
          else
            _buildPaletteView(t),
          const SizedBox(height: AppSizes.paddingMedium),
          Divider(height: 1, color: t.borderSubtle),
          const SizedBox(height: AppSizes.paddingSmall),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Favoritos rápidos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: t.textSecondary,
                    fontSize: AppSizes.fontMedium,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.paddingSmall),
              Flexible(
                child: Tooltip(
                  message: 'Vista previa legible: $selectedName',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.darkBackground,
                      borderRadius: BorderRadius.circular(
                        AppSizes.borderRadiusSmall,
                      ),
                      border: Border.all(
                        color: readableColor.withValues(alpha: 0.45),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: readableColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Legible',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: readableColor,
                              fontSize: AppSizes.fontSmall,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.paddingSmall),
          _buildQuickFavoritesRow(t),
        ],
      ),
    );
  }

  Widget _buildWheelView(AppTheme t) {
    final selectedIndex = _selectedWheelIndex;
    return LayoutBuilder(
      builder: (context, constraints) {
        final diameter = math.max(0.0, math.min(constraints.maxWidth, 212.0));
        final wheelSize = Size(diameter, diameter);

        return Center(
          child: Semantics(
            label: 'Rueda cromática de 48 colores',
            hint: 'Toca un sector o cambia a Paleta para lista accesible',
            child: GestureDetector(
              key: const Key('moneo_color_wheel'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => _selectFromWheelPosition(
                details.localPosition,
                wheelSize,
                isPan: false,
              ),
              onPanStart: (details) {
                _lastPanIndex = null;
                _selectFromWheelPosition(
                  details.localPosition,
                  wheelSize,
                  isPan: true,
                );
              },
              onPanUpdate: (details) => _selectFromWheelPosition(
                details.localPosition,
                wheelSize,
                isPan: true,
              ),
              onPanEnd: (_) => _lastPanIndex = null,
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: CustomPaint(
                  painter: _ColorWheelPainter(
                    selectedColor: widget.selectedColor,
                    selectedIndex: selectedIndex,
                    separatorColor: t.cardBackground,
                    centerBorderColor: t.borderVisible,
                    haloOuterColor: t.textPrimary,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaletteView(AppTheme t) {
    final selectedArgb = widget.selectedColor.toARGB32();
    return Center(
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        alignment: WrapAlignment.center,
        children: List.generate(kMoneoWheelColors.length, (index) {
          final color = kMoneoWheelColors[index];
          final isSelected = color.toARGB32() == selectedArgb;
          final label = _describeWheelColor(index);

          return _ColorSwatchButton(
            key: Key('moneo_palette_color_$index'),
            color: color,
            isSelected: isSelected,
            label: label,
            targetSize: 38,
            circleSize: 30,
            theme: t,
            onTap: () => widget.onColorSelected(color),
          );
        }),
      ),
    );
  }

  Widget _buildQuickFavoritesRow(AppTheme t) {
    final selectedArgb = widget.selectedColor.toARGB32();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 220) {
          return Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: List.generate(kMoneoQuickColors.length, (index) {
              final color = kMoneoQuickColors[index];
              final isSelected = color.toARGB32() == selectedArgb;
              return _ColorSwatchButton(
                key: Key('moneo_quick_color_$index'),
                color: color,
                isSelected: isSelected,
                label: 'Favorito rápido: ${_describeColor(color)}',
                targetSize: 36,
                circleSize: 28,
                theme: t,
                onTap: () => widget.onColorSelected(color),
              );
            }),
          );
        }

        return Row(
          children: List.generate(kMoneoQuickColors.length, (index) {
            final color = kMoneoQuickColors[index];
            final isSelected = color.toARGB32() == selectedArgb;
            return Expanded(
              child: Center(
                child: _ColorSwatchButton(
                  key: Key('moneo_quick_color_$index'),
                  color: color,
                  isSelected: isSelected,
                  label: 'Favorito rápido: ${_describeColor(color)}',
                  targetSize: 36,
                  circleSize: 26,
                  theme: t,
                  onTap: () => widget.onColorSelected(color),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ColorSwatchButton extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final String label;
  final double targetSize;
  final double circleSize;
  final AppTheme theme;
  final VoidCallback onTap;

  const _ColorSwatchButton({
    super.key,
    required this.color,
    required this.isSelected,
    required this.label,
    required this.targetSize,
    required this.circleSize,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final checkColor = color.computeLuminance() > 0.45
        ? const Color(0xFF1A1F2B)
        : Colors.white;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Tooltip(
        message: label,
        child: SizedBox(
          width: targetSize,
          height: targetSize,
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              child: Center(
                child: Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? theme.textPrimary
                          : theme.borderVisible.withValues(alpha: 0.45),
                      width: isSelected ? 2.2 : 1.0,
                    ),
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_rounded,
                          size: circleSize * 0.55,
                          color: checkColor,
                        )
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  final Color selectedColor;
  final int selectedIndex;
  final Color separatorColor;
  final Color centerBorderColor;
  final Color haloOuterColor;

  const _ColorWheelPainter({
    required this.selectedColor,
    required this.selectedIndex,
    required this.separatorColor,
    required this.centerBorderColor,
    required this.haloOuterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) / 2 - 4.0;
    if (outerRadius <= 8.0) return;

    final innerRadius = outerRadius * 0.24;
    final ringStep = (outerRadius - innerRadius) / 4.0;
    const sweep = (2 * math.pi) / 12.0;

    final fillPaint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = separatorColor
      ..strokeWidth = 1.2;

    for (var ring = 0; ring < 4; ring++) {
      final rIn = innerRadius + ring * ringStep;
      final rOut = rIn + ringStep;
      final outerRect = Rect.fromCircle(center: center, radius: rOut);
      final innerRect = Rect.fromCircle(center: center, radius: rIn);

      for (var sector = 0; sector < 12; sector++) {
        final index = ring * 12 + sector;
        final startAngle = -math.pi / 2 + sector * sweep;
        final path = _buildSegmentPath(
          outerRect: outerRect,
          innerRect: innerRect,
          startAngle: startAngle,
          sweepAngle: sweep,
        );

        fillPaint.color = kMoneoWheelColors[index];
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);
      }
    }

    // Vista previa del color activo en el núcleo central de la rueda.
    final previewRadius = innerRadius * 0.78;
    canvas.drawCircle(
      center,
      previewRadius,
      Paint()
        ..style = PaintingStyle.fill
        ..color = selectedColor,
    );
    canvas.drawCircle(
      center,
      previewRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = centerBorderColor.withValues(alpha: 0.7)
        ..strokeWidth = 1.2,
    );

    // Resaltar el segmento activo con aro exterior y punto central accesible.
    if (selectedIndex >= 0 && selectedIndex < kMoneoWheelColors.length) {
      final ring = selectedIndex ~/ 12;
      final sector = selectedIndex % 12;
      final rIn = innerRadius + ring * ringStep;
      final rOut = rIn + ringStep;
      final startAngle = -math.pi / 2 + sector * sweep;
      final selectedPath = _buildSegmentPath(
        outerRect: Rect.fromCircle(center: center, radius: rOut),
        innerRect: Rect.fromCircle(center: center, radius: rIn),
        startAngle: startAngle,
        sweepAngle: sweep,
      );

      canvas.drawPath(
        selectedPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = haloOuterColor
          ..strokeWidth = 2.6,
      );
      canvas.drawPath(
        selectedPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.white
          ..strokeWidth = 1.2,
      );

      final midRadius = (rIn + rOut) / 2;
      final midAngle = startAngle + sweep / 2;
      final dotCenter = Offset(
        center.dx + midRadius * math.cos(midAngle),
        center.dy + midRadius * math.sin(midAngle),
      );
      final dotColor = kMoneoWheelColors[selectedIndex].computeLuminance() > 0.45
          ? const Color(0xFF1A1F2B)
          : Colors.white;
      canvas.drawCircle(
        dotCenter,
        3.2,
        Paint()
          ..style = PaintingStyle.fill
          ..color = dotColor,
      );
    }
  }

  Path _buildSegmentPath({
    required Rect outerRect,
    required Rect innerRect,
    required double startAngle,
    required double sweepAngle,
  }) {
    return Path()
      ..arcTo(outerRect, startAngle, sweepAngle, true)
      ..arcTo(innerRect, startAngle + sweepAngle, -sweepAngle, false)
      ..close();
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.selectedColor.toARGB32() != selectedColor.toARGB32() ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.separatorColor != separatorColor ||
        oldDelegate.centerBorderColor != centerBorderColor ||
        oldDelegate.haloOuterColor != haloOuterColor;
  }
}
