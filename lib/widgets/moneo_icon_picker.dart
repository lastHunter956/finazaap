import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:flutter/material.dart';

/// Botón disparador minimalista y compacto (`>= 48dp`) para el selector de íconos.
///
/// Sigue la estética de entradas y desplegables de Moneo para ubicarse
/// lado a lado con el selector de color.
class MoneoIconPickerTrigger extends StatelessWidget {
  final IconData selectedIcon;
  final Color accentColor;
  final bool isExpanded;
  final VoidCallback onTap;
  final String label;

  const MoneoIconPickerTrigger({
    required this.selectedIcon,
    required this.accentColor,
    required this.isExpanded,
    required this.onTap,
    this.label = 'Ícono',
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final readableAccent = AppColors.getReadableColor(accentColor, context);
    final borderColor = isExpanded ? readableAccent : theme.borderSubtle;
    final borderRadius = BorderRadius.circular(AppSizes.borderRadiusMedium);

    return Semantics(
      container: true,
      button: true,
      expanded: isExpanded,
      label: '$label, seleccionado',
      excludeSemantics: true,
      child: Tooltip(
        message: 'Elegir ícono',
        child: Material(
          color: theme.darkBackground,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(color: borderColor, width: AppSizes.borderWidthThin),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedIcon,
                      size: AppSizes.iconMedium,
                      color: readableAccent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 14,
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
                      color: isExpanded ? readableAccent : theme.textSecondary,
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

/// Panel desplegable inline con buscador offline en español, chips de categoría
/// temática y grilla responsiva de íconos Material de Moneo.
class MoneoIconPickerPanel extends StatefulWidget {
  final IconData selectedIcon;
  final Color accentColor;
  final ValueChanged<IconData> onIconSelected;

  const MoneoIconPickerPanel({
    required this.selectedIcon,
    required this.accentColor,
    required this.onIconSelected,
    super.key,
  });

  @override
  State<MoneoIconPickerPanel> createState() => _MoneoIconPickerPanelState();
}

class _MoneoIconPickerPanelState extends State<MoneoIconPickerPanel> {
  static const List<String> _chipLabels = [
    'Todos',
    'Finanzas',
    'Comida',
    'Transporte',
    'Hogar',
    'Compras',
    'Salud',
    'Ocio',
    'Trabajo',
  ];

  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedCategory = 'Todos';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.appTheme;
    final readableAccent = AppColors.getReadableColor(
      widget.accentColor,
      context,
    );
    final results = AppIcons.search(_query, category: _selectedCategory);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.darkBackground,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
        border: Border.all(
          color: theme.borderSubtle,
          width: AppSizes.borderWidthThin,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(theme, readableAccent),
          const SizedBox(height: 8),
          _buildCategoryChips(theme, readableAccent),
          const SizedBox(height: 8),
          if (results.isEmpty)
            _buildEmptyState(theme)
          else
            _buildIconGrid(results, theme, readableAccent),
        ],
      ),
    );
  }

  Widget _buildSearchField(AppTheme theme, Color readableAccent) {
    final borderRadius = BorderRadius.circular(AppSizes.borderRadiusSmall);
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _query = value),
      textInputAction: TextInputAction.search,
      style: TextStyle(color: theme.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Buscar ícono...',
        hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
        filled: true,
        fillColor: theme.cardBackground,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: theme.textSecondary,
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 44,
        ),
        suffixIcon: _query.isNotEmpty
            ? IconButton(
                tooltip: 'Limpiar búsqueda',
                onPressed: _clearSearch,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: theme.textSecondary,
                ),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 44,
          minHeight: 44,
        ),
        border: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: theme.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadius,
          borderSide: BorderSide(color: readableAccent, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(AppTheme theme, Color readableAccent) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _chipLabels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final chip = _chipLabels[index];
          final isSelected = _selectedCategory == chip;
          final tooltipText = chip == 'Trabajo' ? 'Trabajo y Otros' : chip;

          return Semantics(
            container: true,
            button: true,
            selected: isSelected,
            label: 'Categoría $chip',
            excludeSemantics: true,
            child: Tooltip(
              message: tooltipText,
              child: InkWell(
                onTap: () => setState(() => _selectedCategory = chip),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? readableAccent.withValues(alpha: 0.16)
                            : theme.cardBackground,
                        borderRadius: BorderRadius.circular(
                          AppSizes.borderRadiusLarge,
                        ),
                        border: Border.all(
                          color: isSelected
                              ? readableAccent
                              : theme.borderSubtle,
                          width: isSelected ? 1.4 : 1,
                        ),
                      ),
                      child: Text(
                        chip,
                        maxLines: 1,
                        style: TextStyle(
                          color: isSelected
                              ? theme.textPrimary
                              : theme.textSecondary,
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(AppTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 28,
            color: theme.textHint,
          ),
          const SizedBox(height: 8),
          Text(
            'Sin íconos coincidentes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconGrid(
    List<MoneoIconEntry> results,
    AppTheme theme,
    Color readableAccent,
  ) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 210),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: results.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 60,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final entry = results[index];
          final isSelected =
              entry.icon.codePoint == widget.selectedIcon.codePoint;
          final borderRadius = BorderRadius.circular(
            AppSizes.borderRadiusMedium,
          );

          return Semantics(
            container: true,
            button: true,
            selected: isSelected,
            label: entry.label,
            excludeSemantics: true,
            child: Tooltip(
              message: entry.label,
              child: Material(
                color: isSelected
                    ? readableAccent.withValues(alpha: 0.16)
                    : theme.cardBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: borderRadius,
                  side: BorderSide(
                    color: isSelected ? readableAccent : theme.borderSubtle,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => widget.onIconSelected(entry.icon),
                  borderRadius: borderRadius,
                  child: Center(
                    child: Icon(
                      entry.icon,
                      size: 22,
                      color: isSelected ? readableAccent : theme.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
