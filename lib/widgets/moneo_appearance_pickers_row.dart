import 'package:flutter/material.dart';

import 'package:finazaap/widgets/moneo_color_picker.dart';
import 'package:finazaap/widgets/moneo_icon_picker.dart';

enum _AppearancePanel { color, icon }

/// Fila compacta lado a lado para seleccionar color e ícono de forma
/// minimalista (`48dp`) con despliegue inline exclusivo debajo de los botones.
class MoneoAppearancePickersRow extends StatefulWidget {
  final Color selectedColor;
  final IconData selectedIcon;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<IconData> onIconChanged;
  final String colorLabel;
  final String iconLabel;

  const MoneoAppearancePickersRow({
    super.key,
    required this.selectedColor,
    required this.selectedIcon,
    required this.onColorChanged,
    required this.onIconChanged,
    this.colorLabel = 'Color',
    this.iconLabel = 'Ícono',
  });

  @override
  State<MoneoAppearancePickersRow> createState() =>
      _MoneoAppearancePickersRowState();
}

class _MoneoAppearancePickersRowState extends State<MoneoAppearancePickersRow> {
  _AppearancePanel? _expandedPanel;

  void _togglePanel(_AppearancePanel target) {
    setState(() {
      _expandedPanel = _expandedPanel == target ? null : target;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: MoneoColorPickerTrigger(
                selectedColor: widget.selectedColor,
                isExpanded: _expandedPanel == _AppearancePanel.color,
                label: widget.colorLabel,
                onTap: () => _togglePanel(_AppearancePanel.color),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MoneoIconPickerTrigger(
                selectedIcon: widget.selectedIcon,
                accentColor: widget.selectedColor,
                isExpanded: _expandedPanel == _AppearancePanel.icon,
                label: widget.iconLabel,
                onTap: () => _togglePanel(_AppearancePanel.icon),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: switch (_expandedPanel) {
            _AppearancePanel.color => Padding(
                key: const ValueKey('moneo_appearance_color_panel'),
                padding: const EdgeInsets.only(top: 10),
                child: MoneoColorPickerPanel(
                  selectedColor: widget.selectedColor,
                  onColorSelected: widget.onColorChanged,
                ),
              ),
            _AppearancePanel.icon => Padding(
                key: const ValueKey('moneo_appearance_icon_panel'),
                padding: const EdgeInsets.only(top: 10),
                child: MoneoIconPickerPanel(
                  selectedIcon: widget.selectedIcon,
                  accentColor: widget.selectedColor,
                  onIconSelected: widget.onIconChanged,
                ),
              ),
            null => const SizedBox.shrink(),
          },
        ),
      ],
    );
  }
}
