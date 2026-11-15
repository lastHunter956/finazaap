import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:finazaap/widgets/account_dialogs.dart'; // Import for helper widgets
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/themes/theme.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

class CategoriesScreen extends StatefulWidget {
  final int activeIndex;
  const CategoriesScreen({Key? key, this.activeIndex = 0}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _incomeCategories = [];
  List<Map<String, dynamic>> _expenseCategories = [];
  bool _isLoading = true;

  // Predefined Icons for selection
  final List<IconData> _availableIcons = AppIcons.allIcons;

  // Predefined Colors for selection
  final List<Color> _availableColors = [
    Colors.redAccent, Colors.pinkAccent, Colors.purpleAccent, Colors.deepPurpleAccent,
    Colors.indigoAccent, Colors.blueAccent, Colors.lightBlueAccent, Colors.cyanAccent,
    Colors.tealAccent, Colors.greenAccent, Colors.lightGreenAccent, Colors.limeAccent,
    Colors.yellowAccent, Colors.amberAccent, Colors.orangeAccent, Colors.deepOrangeAccent,
    Colors.blueGrey, Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCategories();
  }

  @override
  void didUpdateWidget(covariant CategoriesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeIndex == 2 && oldWidget.activeIndex != 2) {
      _loadCategories();
    }
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final income = await CategoryService.getCategoriesWithMetadata('Income');
      final expense = await CategoryService.getCategoriesWithMetadata('Expenses');
      
      if (mounted) {
        setState(() {
          _incomeCategories = income;
          _expenseCategories = expense;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // --- SHOW OPTIONS DIALOG (PREVIEW) ---
  void _showCategoryOptions(String type, Map<String, dynamic> category) {
    final String name = category['text'];
    final IconData icon = AppIcons.getIcon(category['icon'] ?? Icons.category.codePoint);
    final Color color = Color(category['color'] ?? Colors.blueAccent.value);

    // Colores consistentes
    final Color cardColor = context.appTheme.secondaryCardBackground;
    final Color accentColor = color;
    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color readableAccentColor = AppColors.getReadableColor(accentColor, context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Opciones",
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => Container(),
      transitionBuilder: (context, animation, _, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                 backgroundColor: Colors.transparent,
                 insetPadding: const EdgeInsets.all(20),
                 child: Container(
                   width: double.infinity,
                   constraints: const BoxConstraints(maxWidth: 400),
                   decoration: BoxDecoration(
                     color: isLight ? cardColor : null,
                     gradient: isLight
                         ? null
                         : LinearGradient(
                             begin: Alignment.topLeft,
                             end: Alignment.bottomRight,
                             colors: [
                               cardColor,
                               Color.lerp(cardColor, accentColor.withOpacity(0.12), 0.25) ?? cardColor,
                             ],
                           ),
                     borderRadius: BorderRadius.circular(28),
                     boxShadow: [
                       BoxShadow(
                         color: Colors.black.withOpacity(isLight ? 0.08 : 0.35),
                         blurRadius: 25,
                         spreadRadius: -5,
                         offset: const Offset(0, 10),
                       ),
                       BoxShadow(
                         color: readableAccentColor.withOpacity(isLight ? 0.15 : 0.25),
                         blurRadius: 20,
                         spreadRadius: -10,
                         offset: const Offset(0, 5),
                       ),
                     ],
                     border: isLight
                         ? Border.all(color: readableAccentColor.withOpacity(0.7), width: 1.8)
                         : GradientBoxBorder(
                             gradient: LinearGradient(
                               begin: Alignment.topLeft,
                               end: Alignment.bottomRight,
                               colors: [
                                 Colors.white.withOpacity(0.13),
                                 accentColor.withOpacity(0.1),
                                 Colors.white.withOpacity(0.05),
                                 Colors.transparent,
                               ],
                               stops: const [0.0, 0.3, 0.7, 1.0],
                             ),
                             width: 1.2,
                           ),
                   ),
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       // 1. Header (Account-style)
                       Container(
                         padding: const EdgeInsets.all(24),
                         decoration: BoxDecoration(
                           color: isLight ? readableAccentColor.withOpacity(0.08) : null,
                           gradient: isLight
                               ? null
                               : LinearGradient(
                                   begin: Alignment.topLeft,
                                   end: Alignment.bottomRight,
                                   colors: [
                                     accentColor.withOpacity(0.15),
                                     accentColor.withOpacity(0.05),
                                   ],
                                 ),
                           border: Border(
                             bottom: BorderSide(
                               color: isLight
                                   ? context.appTheme.borderSubtle
                                   : Colors.white.withOpacity(0.08),
                               width: 1,
                             ),
                           ),
                         ),
                         child: Row(
                           children: [
                             Container(
                               width: 56,
                               height: 56,
                                decoration: BoxDecoration(
                                  color: isLight ? readableAccentColor : null,
                                  gradient: isLight
                                      ? null
                                      : LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            accentColor.withOpacity(0.22),
                                            accentColor.withOpacity(0.13),
                                          ],
                                        ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(isLight ? 0.12 : 0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                      spreadRadius: -2,
                                    ),
                                  ],
                                  border: Border.all(
                                    color: isLight ? readableAccentColor : accentColor.withOpacity(0.35),
                                    width: 1.5,
                                  ),
                                ),
                               child: Icon(icon, color: Colors.white, size: 28),
                             ),
                             const SizedBox(width: 16),
                             Expanded(
                               child: Column(
                                 crossAxisAlignment: CrossAxisAlignment.start,
                                 children: [
                                   Text(
                                     name,
                                     style: TextStyle(
                                       color: context.appTheme.textPrimary,
                                       fontSize: 20,
                                       fontWeight: FontWeight.bold,
                                     ),
                                     maxLines: 2,
                                     overflow: TextOverflow.ellipsis,
                                   ),
                                   const SizedBox(height: 4),
                                   Row(
                                     children: [
                                       Container(
                                         width: 8,
                                         height: 8,
                                         decoration: BoxDecoration(
                                           color: type == 'Income' ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C),
                                           shape: BoxShape.circle,
                                           boxShadow: [
                                             BoxShadow(
                                               color: (type == 'Income' ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C)).withOpacity(0.4),
                                               blurRadius: 4,
                                               spreadRadius: 0,
                                             ),
                                           ],
                                         ),
                                       ),
                                       SizedBox(width: 8),
                                       Text(
                                         type == 'Income' ? 'Ingreso' : 'Gasto',
                                         style: TextStyle(
                                           color: context.appTheme.textSecondary,
                                           fontSize: 14,
                                         ),
                                       ),
                                     ],
                                   ),
                                 ],
                               ),
                             ),
                           ],
                         ),
                       ),
                       SizedBox(height: 20),
                       
                       // 2. Info Card (Balance-style)
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 24),
                         child: Container(
                           padding: EdgeInsets.all(18),
                           decoration: BoxDecoration(
                             color: context.appTheme.secondaryCardBackground,
                             borderRadius: BorderRadius.circular(18),
                             border: Border.all(
                               color: context.appTheme.borderSubtle,
                               width: 1,
                             ),
                           ),
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Row(
                                 children: [
                                   Container(
                                     padding: EdgeInsets.all(7),
                                     decoration: BoxDecoration(
                                       color: accentColor.withOpacity(0.15),
                                       borderRadius: BorderRadius.circular(8),
                                     ),
                                     child: Icon(
                                       type == 'Income' ? Icons.trending_up : Icons.trending_down,
                                       size: 14,
                                       color: accentColor,
                                     ),
                                   ),
                                   SizedBox(width: 8),
                                   Expanded(
                                     child: Text(
                                       type == 'Income' ? 'CATEGORÍA DE INGRESO' : 'CATEGORÍA DE GASTO',
                                       style: TextStyle(
                                         color: context.appTheme.textSecondary,
                                         fontSize: 11,
                                         letterSpacing: 0.8,
                                         fontWeight: FontWeight.w500,
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                               SizedBox(height: 12),
                               Row(
                                 children: [
                                   Icon(
                                     Icons.label_outline,
                                     color: context.appTheme.textHint,
                                     size: 18,
                                   ),
                                   SizedBox(width: 8),
                                   Expanded(
                                     child: Text(
                                       'Agrupa transacciones similares',
                                       style: TextStyle(
                                         color: context.appTheme.textSecondary,
                                         fontSize: 13,
                                       ),
                                     ),
                                   ),
                                 ],
                               ),
                             ],
                           ),
                         ),
                       ),
                       SizedBox(height: 20),
                       
                       // 3. Actions Section
                       Container(
                         decoration: BoxDecoration(
                           color: context.appTheme.darkBackground,
                           borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                         ),
                         child: Column(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             // Edit Button
                             _buildOptionButton(
                               icon: Icons.edit_outlined,
                               label: 'Editar Categoría',
                               description: 'Modificar nombre, color o ícono',
                               color: const Color(0xFF3498DB),
                               onTap: () {
                                 Navigator.pop(context);
                                 _showCategoryDialog(type: type, categoryToEdit: category);
                               },
                             ),
                             const SizedBox(height: 12),
                             // Delete Button
                             _buildOptionButton(
                               icon: Icons.delete_outline,
                               label: 'Eliminar Categoría',
                               description: 'Eliminar permanentemente esta categoría',
                               color: const Color(0xFFE74C3C),
                               onTap: () {
                                 Navigator.pop(context);
                                 _confirmDelete(type, name);
                               },
                               showBorder: false,
                             ),
                             
                             // Botón Cancelar
                             Container(
                               width: double.infinity,
                               padding: const EdgeInsets.all(16),
                               child: TextButton(
                                 style: TextButton.styleFrom(
                                   foregroundColor: isLight 
                                       ? context.appTheme.textPrimary 
                                       : context.appTheme.textSecondary,
                                   backgroundColor: isLight 
                                       ? context.appTheme.cardBackground 
                                       : context.appTheme.darkBackground,
                                   padding: EdgeInsets.symmetric(vertical: 15),
                                   shape: RoundedRectangleBorder(
                                     borderRadius: BorderRadius.circular(14),
                                     side: BorderSide(
                                       color: isLight 
                                           ? context.appTheme.borderVisible 
                                           : context.appTheme.borderSubtle,
                                       width: 1,
                                     ),
                                   ),
                                 ),
                                 onPressed: () => Navigator.of(context).pop(),
                                 child: Text(
                                   'Cancelar',
                                   style: TextStyle(
                                     fontWeight: FontWeight.w600,
                                     letterSpacing: 0.3,
                                     fontSize: 16,
                                   ),
                                 ),
                               ),
                             ),
                           ],
                         ),
                       ),
                     ],
                   ),
                 ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required String description,
    required Color color,
    required VoidCallback onTap,
    bool showBorder = true,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: showBorder
              ? Border(
                  bottom: BorderSide(
                    color: context.appTheme.borderSubtle,
                    width: 1,
                  ),
                )
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: context.appTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.appTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: context.appTheme.textHint,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  
  // --- ADD / EDIT DIALOG (UNIFIED STYLE) ---
  void _showCategoryDialog({required String type, Map<String, dynamic>? categoryToEdit}) {
    final bool isEditing = categoryToEdit != null;
    final TextEditingController _nameController = TextEditingController(text: isEditing ? categoryToEdit['text'] : '');
    
    IconData _selectedIcon = isEditing 
        ? AppIcons.getIcon(categoryToEdit['icon'] ?? Icons.category.codePoint) 
        : _availableIcons[0];
    Color _selectedColor = isEditing 
        ? Color(categoryToEdit['color'] ?? Colors.blueAccent.value) 
        : _availableColors[0];

    final bool isLight = Theme.of(context).brightness == Brightness.light;
    final Color cardColor = context.appTheme.secondaryCardBackground;
    final Color readableSelectedColor = AppColors.getReadableColor(_selectedColor, context);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Categoría",
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutQuart);
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: animation,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: StatefulBuilder(
                  builder: (context, setDialogState) {
                    return Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 560),
                      decoration: BoxDecoration(
                        color: isLight ? cardColor : null,
                        gradient: isLight
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  cardColor,
                                  Color.lerp(cardColor, _selectedColor.withOpacity(0.15), 0.3) ?? cardColor,
                                ],
                              ),
                        borderRadius: BorderRadius.circular(28),
                        border: isLight
                            ? Border.all(color: readableSelectedColor.withOpacity(0.6), width: 1.8)
                            : GradientBoxBorder(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.15),
                                    _selectedColor.withOpacity(0.3),
                                    Colors.white.withOpacity(0.05),
                                  ],
                                ),
                                width: 1.2,
                              ),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(isLight ? 0.08 : 0.5), blurRadius: 20, spreadRadius: -5),
                           BoxShadow(color: readableSelectedColor.withOpacity(isLight ? 0.12 : 0.2), blurRadius: 15, spreadRadius: -2),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min, // Hace que el diálogo se ajuste al contenido
                        children: [
                          // Cabecera estilizada (Estilo Cuenta - Row Layout)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: isLight ? readableSelectedColor.withOpacity(0.08) : null,
                              gradient: isLight
                                  ? null
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        _selectedColor.withOpacity(0.18),
                                        _selectedColor.withOpacity(0.05),
                                      ],
                                    ),
                              border: Border(
                                bottom: BorderSide(
                                  color: isLight
                                      ? context.appTheme.borderSubtle
                                      : Colors.white.withOpacity(0.08),
                                  width: 1,
                                ),
                              ),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                            ),
                            child: Row(
                              children: [
                                // Icono animado
                                Container(
                                  width: 58,
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: isLight ? readableSelectedColor : null,
                                    gradient: isLight
                                        ? null
                                        : LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              _selectedColor.withOpacity(0.22),
                                              _selectedColor.withOpacity(0.13),
                                            ],
                                          ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(isLight ? 0.12 : 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                        spreadRadius: -2,
                                      ),
                                    ],
                                    border: Border.all(
                                      color: isLight ? readableSelectedColor : _selectedColor.withOpacity(0.35),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Icon(
                                    _selectedIcon,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isEditing ? 'Editar Categoría' : 'Nueva Categoría',
                                        style: TextStyle(
                                          color: context.appTheme.textPrimary,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        isEditing ? 'Modifica los detalles' : 'Crea una nueva agrupación',
                                        style: TextStyle(
                                          color: context.appTheme.textSecondary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name Input (Standardized)
                                  buildInputLabel('Nombre de la categoría', context),
                                  buildInputField(
                                    context: context,
                                    child: TextField(
                                      controller: _nameController,
                                      style: TextStyle(color: context.appTheme.textPrimary, fontSize: 16),
                                      decoration: InputDecoration(
                                        hintText: 'Ej: Alimentación',
                                        hintStyle: TextStyle(color: context.appTheme.textHint),
                                        border: InputBorder.none,
                                        prefixIcon: Icon(Icons.edit_outlined, color: _selectedColor.withOpacity(0.7), size: 20),
                                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  

                                  
                                  // Color Selection
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                       buildInputLabel('Color', context),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8, right: 4),
                                        child: Text(
                                          'Desplázate para ver más >>',
                                          style: TextStyle(
                                            color: context.appTheme.textHint,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 55, // Height increased
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _availableColors.length,
                                      itemBuilder: (context, index) {
                                        final color = _availableColors[index];
                                        final isSelected = color.value == _selectedColor.value;
                                        return GestureDetector(
                                          onTap: () => setDialogState(() => _selectedColor = color),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            margin: const EdgeInsets.only(right: 14), // Increased margin
                                            width: isSelected ? 48 : 40, // Restored sizes
                                            height: isSelected ? 48 : 40,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                              border: isSelected ? Border.all(color: Colors.white, width: 2.5) : null,
                                              boxShadow: isSelected 
                                                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 10, spreadRadius: 1)] 
                                                : [],
                                            ),
                                            child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 24) : null,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  
                                  const SizedBox(height: 24), // Increased spacing
                                  
                                  // Icon Selection
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                       buildInputLabel('Icono', context),
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8, right: 4),
                                        child: Text(
                                          'Desplázate para ver más >>',
                                          style: TextStyle(
                                            color: context.appTheme.textHint,
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    height: 60, // Restored height
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: _availableIcons.length,
                                      itemBuilder: (context, index) {
                                        final icon = _availableIcons[index];
                                        final isSelected = icon == _selectedIcon;
                                        return GestureDetector(
                                          onTap: () => setDialogState(() => _selectedIcon = icon),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            margin: const EdgeInsets.only(right: 14), // Increased margin
                                            width: 52, // Slightly larger
                                            decoration: BoxDecoration(
                                              color: isSelected 
                                                  ? _selectedColor.withOpacity(0.2) 
                                                  : (isLight 
                                                      ? context.appTheme.darkBackground 
                                                      : Colors.white.withOpacity(0.05)),
                                              borderRadius: BorderRadius.circular(14), // Slightly rounder
                                              border: Border.all(
                                                color: isSelected 
                                                    ? _selectedColor 
                                                    : (isLight 
                                                        ? context.appTheme.borderSubtle 
                                                        : Colors.transparent),
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Icon(
                                              icon,
                                              color: isSelected 
                                                  ? _selectedColor 
                                                  : (isLight 
                                                      ? context.appTheme.textSecondary 
                                                      : Colors.white.withOpacity(0.5)),
                                              size: 26, // Larger icon
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  //const SizedBox(height: 20),


                                ],
                              ),
                            ),
                          ),

                          // Actions
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      foregroundColor: isLight 
                                          ? context.appTheme.textPrimary 
                                          : context.appTheme.textSecondary,
                                      backgroundColor: isLight 
                                          ? context.appTheme.darkBackground 
                                          : Colors.white.withOpacity(0.05),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        side: BorderSide(
                                          color: isLight 
                                              ? context.appTheme.borderSubtle 
                                              : Colors.transparent,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Cancelar'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final name = _nameController.text.trim();
                                      if (name.isNotEmpty) {
                                        if (isEditing) {
                                          await CategoryService.editCategoryWithMetadata(
                                            type, categoryToEdit['text'], name, _selectedIcon.codePoint, _selectedColor.value
                                          );
                                        } else {
                                          await CategoryService.addCategoryWithMetadata(
                                            type, name, _selectedIcon.codePoint, _selectedColor.value
                                          );
                                        }
                                        _loadCategories();
                                        Navigator.pop(context);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _selectedColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      elevation: 8,
                                      shadowColor: _selectedColor.withOpacity(0.5),
                                    ),
                                    child: const Text('Guardar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDelete(String type, String name) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Confirmar",
      barrierColor: Colors.black.withOpacity(0.7),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, __) => Container(),
      transitionBuilder: (context, anim, _, child) {
        return FadeTransition(
          opacity: anim,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: AlertDialog(
              backgroundColor: context.appTheme.secondaryCardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text('Eliminar Categoría', style: TextStyle(color: context.appTheme.textPrimary)),
              content: Text('¿Seguro que deseas eliminar "$name"?', style: TextStyle(color: context.appTheme.textSecondary)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancelar', style: TextStyle(color: context.appTheme.textSecondary)),
                ),
                TextButton(
                  onPressed: () async {
                    await CategoryService.deleteCategory(type, name);
                    _loadCategories();
                    if (mounted) Navigator.pop(context);
                  },
                   child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabHeight = math.max(
      40.0,
      MediaQuery.textScalerOf(context).scale(14.0) + 22.0,
    );

    return Scaffold(
      backgroundColor: context.appTheme.primaryBackground,
      appBar: null,
      body: Column(
        children: [
          MoneoHeaderBar.primaryTab(
            title: 'Categorías',
            bottomChild: Container(
              decoration: BoxDecoration(
                color: context.isDiurno
                    ? context.appTheme.darkBackground.withValues(alpha: 0.72)
                    : context.appTheme.darkBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: context.appTheme.borderSubtle,
                  width: 1,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: context.isDiurno
                      ? context.appTheme.cardBackground
                      : context.appTheme.buttonBackground,
                  borderRadius: BorderRadius.circular(11),
                  border: context.isDiurno
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                          width: 1,
                        )
                      : null,
                  boxShadow: context.isDiurno
                      ? const [
                          BoxShadow(
                            color: Color(0x140B132B),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                indicatorPadding: const EdgeInsets.all(3),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: context.isDiurno
                    ? context.appTheme.textPrimary
                    : context.appTheme.buttonForeground,
                unselectedLabelColor: context.appTheme.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13.5,
                ),
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                tabs: [
                  Tab(height: tabHeight, text: 'Ingresos'),
                  Tab(height: tabHeight, text: 'Gastos'),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.appTheme.accent,
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCategoryList('Income', _incomeCategories),
                        _buildCategoryList('Expenses', _expenseCategories),
                      ],
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: MoneoPressableScale(
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: context.isDiurno
                ? Border.all(
                    color: Colors.white.withValues(alpha: 0.72),
                    width: 1.2,
                  )
                : null,
            boxShadow: [
              BoxShadow(
                color: context.appTheme.buttonBackground.withValues(
                  alpha: context.isDiurno ? 0.30 : 0.36,
                ),
                blurRadius: 12,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Semantics(
            button: true,
            label: 'Nueva categoría',
            child: FloatingActionButton(
              heroTag: "categories_fab",
              tooltip: 'Nueva categoría',
              onPressed: () {
                final type = _tabController.index == 0 ? 'Income' : 'Expenses';
                _showCategoryDialog(type: type);
              },
              backgroundColor: context.appTheme.buttonBackground,
              foregroundColor: context.appTheme.buttonForeground,
              elevation: 0,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.add_rounded,
                color: context.appTheme.buttonForeground,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryList(String type, List<Map<String, dynamic>> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 60, color: context.appTheme.textHint.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              'No hay categorías',
              style: TextStyle(color: context.appTheme.textHint),
            ),
          ],
        ),
      );
    }
    
    // Usamos ListView normal con Padding para las tarjetas
    return ListView.builder(
      padding: MoneoLayoutMetrics.scrollBottomPadding(context, hasFab: true),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        final String name = category['text'];
        final IconData icon = AppIcons.getIcon(category['icon'] ?? Icons.category.codePoint);
        final Color color = Color(category['color'] ?? Colors.blue.value);

        final bool isLight = Theme.of(context).brightness == Brightness.light;
        final Color readableColor = AppColors.getReadableColor(color, context);

        // Estilo de Tarjeta Premium (Card Style)
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: isLight ? context.appTheme.cardBackground : null,
            gradient: isLight
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(context.appTheme.secondaryCardBackground, color, 0.12)!,
                      context.appTheme.secondaryCardBackground,
                    ],
                  ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isLight ? 0.08 : 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: readableColor.withOpacity(isLight ? 0.15 : 0.1),
                blurRadius: 12,
                offset: const Offset(0, 2),
                spreadRadius: -2,
              ),
            ],
            border: Border.all(
              color: readableColor.withOpacity(isLight ? 0.6 : 0.15),
              width: isLight ? 1.5 : 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _showCategoryOptions(type, category), // Abre el modal de opciones
              splashColor: color.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icono en contenedor degradado
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isLight ? readableColor : null,
                        gradient: isLight
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color.withOpacity(0.22),
                                  color.withOpacity(0.13),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(isLight ? 0.12 : 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                            spreadRadius: -2,
                          ),
                        ],
                        border: Border.all(
                          color: isLight ? readableColor : color.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 16),
                    
                    // Texto
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: context.appTheme.textPrimary, 
                          fontSize: 16, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    
                    // Flecha indicadora (Action)
                    Icon(Icons.more_vert, color: context.appTheme.textHint, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
