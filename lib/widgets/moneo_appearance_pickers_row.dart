import 'package:flutter/material.dart';

import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/widgets/moneo_color_picker.dart';
import 'package:finazaap/widgets/moneo_icon_picker.dart';

/// Abre una ventana emergente centrada para elegir un color desde la rueda
/// cromática de 48 tonos o la paleta accesible, devolviendo el color confirmado.
Future<Color?> showMoneoColorPickerPopup({
  required BuildContext context,
  required Color initialColor,
  String title = 'Elegir color',
}) {
  Color current = initialColor;

  return showDialog<Color>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      final t = dialogCtx.appTheme;
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: StatefulBuilder(
          builder: (ctx, setDialogState) {
            final readableCurrent = AppColors.getReadableColor(current, ctx);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 380,
                maxHeight: MediaQuery.of(ctx).size.height * 0.86,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: t.cardBackground,
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadius2XLarge),
                  border: Border.all(color: t.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.24),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: current,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: t.borderVisible,
                                width: 1.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: AppSizes.font2XLarge,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Semantics(
                            button: true,
                            label: 'Cerrar selector de color',
                            child: IconButton(
                              tooltip: 'Cerrar',
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              icon: Icon(
                                Icons.close_rounded,
                                color: t.textSecondary,
                                size: 20,
                              ),
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, color: t.borderSubtle),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: MoneoColorPickerPanel(
                          selectedColor: current,
                          onColorSelected: (c) {
                            setDialogState(() => current = c);
                          },
                        ),
                      ),
                    ),
                    Divider(height: 1, color: t.borderSubtle),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogCtx).pop(),
                            style: TextButton.styleFrom(
                              foregroundColor: t.textSecondary,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                            ),
                            child: const Text('Cancelar'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () =>
                                Navigator.of(dialogCtx).pop(current),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: t.buttonBackground,
                              foregroundColor: t.buttonForeground,
                              elevation: 0,
                              minimumSize: const Size(48, 48),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppSizes.borderRadiusMedium,
                                ),
                                side: t.filledButtons
                                    ? BorderSide.none
                                    : BorderSide(color: readableCurrent),
                              ),
                            ),
                            child: const Text(
                              'Aplicar',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

/// Abre una ventana emergente centrada para elegir un ícono del catálogo
/// temático de Moneo, cerrándose automáticamente al seleccionar uno.
Future<IconData?> showMoneoIconPickerPopup({
  required BuildContext context,
  required IconData initialIcon,
  required Color accentColor,
  String title = 'Elegir ícono',
}) {
  return showDialog<IconData>(
    context: context,
    barrierDismissible: true,
    builder: (dialogCtx) {
      final t = dialogCtx.appTheme;
      final readableAccent = AppColors.getReadableColor(accentColor, dialogCtx);
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 400,
            maxHeight: MediaQuery.of(dialogCtx).size.height * 0.86,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: t.cardBackground,
              borderRadius: BorderRadius.circular(AppSizes.borderRadius2XLarge),
              border: Border.all(color: t.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: readableAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadiusSmall,
                          ),
                        ),
                        child: Icon(
                          initialIcon,
                          size: 18,
                          color: readableAccent,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: AppSizes.font2XLarge,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Cerrar selector de ícono',
                        child: IconButton(
                          tooltip: 'Cerrar',
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          icon: Icon(
                            Icons.close_rounded,
                            color: t.textSecondary,
                            size: 20,
                          ),
                          onPressed: () => Navigator.of(dialogCtx).pop(),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: t.borderSubtle),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: MoneoIconPickerPanel(
                      selectedIcon: initialIcon,
                      accentColor: accentColor,
                      onIconSelected: (icon) =>
                          Navigator.of(dialogCtx).pop(icon),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Fila compacta lado a lado para seleccionar color e ícono de forma
/// minimalista (`48dp`) abriendo su respectiva ventana emergente al pulsar.
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
  bool _isColorOpen = false;
  bool _isIconOpen = false;

  Future<void> _openColorPopup() async {
    setState(() => _isColorOpen = true);
    final picked = await showMoneoColorPickerPopup(
      context: context,
      initialColor: widget.selectedColor,
    );
    if (!mounted) return;
    setState(() => _isColorOpen = false);
    if (picked != null) {
      widget.onColorChanged(picked);
    }
  }

  Future<void> _openIconPopup() async {
    setState(() => _isIconOpen = true);
    final picked = await showMoneoIconPickerPopup(
      context: context,
      initialIcon: widget.selectedIcon,
      accentColor: widget.selectedColor,
    );
    if (!mounted) return;
    setState(() => _isIconOpen = false);
    if (picked != null) {
      widget.onIconChanged(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: MoneoColorPickerTrigger(
            selectedColor: widget.selectedColor,
            isExpanded: _isColorOpen,
            label: widget.colorLabel,
            onTap: _openColorPopup,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: MoneoIconPickerTrigger(
            selectedIcon: widget.selectedIcon,
            accentColor: widget.selectedColor,
            isExpanded: _isIconOpen,
            label: widget.iconLabel,
            onTap: _openIconPopup,
          ),
        ),
      ],
    );
  }
}
