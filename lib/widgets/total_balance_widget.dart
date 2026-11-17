import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/themes/app_sizes.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class TotalBalanceWidget extends StatefulWidget {
  // ========= Valores dinámicos =========
  final ValueNotifier<double> availableBalanceNotifier; // Notificador de saldo disponible
  final ValueNotifier<Map<String, double>>? availableBalancesByCurrencyNotifier;
  final Map<String, double>? availableBalancesByCurrency;
  final Map<String, double>? accountingBalancesByCurrency;
  final Map<String, double>? expensesByCurrency;
  final Map<String, double>? incomeByCurrency;
  final double accountingBalance;  // Balance contable (puede ser negativo)
  final double totalExpenses;      // Total de egresos
  final double totalIncome;        // Total de ingresos

  // ========= Callbacks para botones =========
  final VoidCallback onManageAccounts;
  final VoidCallback? onShowAll;
  final VoidCallback? onShowExpenses;
  final VoidCallback? onShowIncome;

  // Añadir callback para notificar selección de fecha
  final Function(int month, int year)? onDateSelected;

  // Texto inicial del botón de fecha
  final String selectedMonthYear;

  const TotalBalanceWidget({
    Key? key,
    required this.availableBalanceNotifier,
    required this.accountingBalance,
    required this.totalExpenses,
    required this.totalIncome,
    required this.onManageAccounts,
    this.onShowAll,
    this.onShowExpenses,
    this.onShowIncome,
    this.availableBalancesByCurrencyNotifier,
    this.availableBalancesByCurrency,
    this.accountingBalancesByCurrency,
    this.expensesByCurrency,
    this.incomeByCurrency,
    this.onDateSelected,  // <-- Nueva propiedad
    this.selectedMonthYear = 'Diciembre 2025',
  }) : super(key: key);

  @override
  _TotalBalanceWidgetState createState() => _TotalBalanceWidgetState();
}

class _TotalBalanceWidgetState extends State<TotalBalanceWidget> {
  // Variables para controlar la selección de mes y año
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  String _selectedMonthYear = '';
  bool _isLocaleInitialized = false;

  @override
  void initState() {
    super.initState();
    _isLocaleInitialized = true;
    final now = DateTime.now();
    _selectedMonth = now.month;
    _selectedYear = now.year;
    _selectedMonthYear = _formatDate(now);
  }

  // Método para formatear fecha con seguridad
  String _formatDate(DateTime date) {
    if (!_isLocaleInitialized) {
      return widget.selectedMonthYear;
    }
    try {
      final formatted = DateFormat('MMM yyyy', 'es').format(date).replaceAll('.', '');
      if (formatted.isEmpty) return formatted;
      return formatted[0].toUpperCase() + formatted.substring(1);
    } catch (_) {
      return widget.selectedMonthYear;
    }
  }

  // Método mejorado para mostrar el selector de mes/año con diseño premium
  void _showMonthYearSelector() {
    // Variables para el selector
    int localMonth = _selectedMonth;
    int localYear = _selectedYear;
    
    // Constantes de diseño - Sistema de tokens profesional
    const double cornerRadius = 24.0;
    final t = this.context.appTheme;
    final Color accentColor = t.buttonBackground;
    final Color surfaceColor = t.secondaryCardBackground;
    final Color cardColor = t.darkBackground;
    
    // Lista de nombres de meses con formato capitalizado
    final List<String> monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    // Mostrar diálogo con animaciones optimizadas
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Selector de período",
      barrierColor: Colors.black.withOpacity(0.75),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return StatefulBuilder(
          builder: (context, setState) {
            // Animaciones compuestas para efecto profesional
            final curveAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutQuint,
              reverseCurve: Curves.easeInQuint,
            );
            
            // Múltiples animaciones coordinadas
            final scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(curveAnimation);
            final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Interval(0.1, 1.0))
            );
            final blurAnimation = Tween<double>(begin: 20, end: 0).animate(curveAnimation);
            
            final bool useBlur = !LiquidGlassSurface.shouldReduceEffects(context) &&
                blurAnimation.value > 0.1;
            final Widget dialogCard = Material(
              color: Colors.transparent,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.87,
                constraints: BoxConstraints(
                  maxWidth: AppSizes.dialogMaxWidth,
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(cornerRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(
                    color: t.borderSubtle,
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cornerRadius),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ===== CABECERA PREMIUM =====
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              accentColor.withValues(alpha: 0.22),
                              accentColor.withValues(alpha: 0.10),
                              accentColor.withValues(alpha: 0.05),
                            ],
                            stops: const [0.0, 0.6, 1.0],
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seleccionar período',
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Filtrar transacciones por mes y año',
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Vista previa de selección
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.borderRadiusMedium,
                                ),
                                border: Border.all(
                                  color: t.borderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: accentColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        "${monthNames[localMonth - 1]} $localYear",
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: t.textPrimary,
                                          fontWeight: FontWeight.w600,
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

                      // Contenedor principal con scroll si es necesario
                      Flexible(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Control para selección de año
                                Container(
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: cardColor,
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.borderRadiusLarge,
                                    ),
                                    border: Border.all(
                                      color: t.borderSubtle,
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      _buildDirectionalButton(
                                        icon: Icons.chevron_left_rounded,
                                        label: 'Año anterior',
                                        color: t.textPrimary,
                                        onTap: () {
                                          setState(() {
                                            localYear--;
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                      ),
                                      Expanded(
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              localYear.toString(),
                                              style: TextStyle(
                                                color: t.textPrimary,
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                                fontFeatures: const [
                                                  FontFeature.tabularFigures(),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      _buildDirectionalButton(
                                        icon: Icons.chevron_right_rounded,
                                        label: 'Año siguiente',
                                        color: t.textPrimary,
                                        onTap: () {
                                          setState(() {
                                            localYear++;
                                          });
                                          HapticFeedback.lightImpact();
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Grid de meses
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 1.65,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 10,
                                  ),
                                  itemCount: 12,
                                  itemBuilder: (context, index) {
                                    final int monthNumber = index + 1;
                                    final bool isSelected =
                                        localMonth == monthNumber;

                                    return _buildMonthSelector(
                                      monthName:
                                          monthNames[index].substring(0, 3),
                                      fullMonthName: monthNames[index],
                                      isSelected: isSelected,
                                      accentColor: accentColor,
                                      cardColor: cardColor,
                                      textColor: t.textPrimary,
                                      borderColor: t.borderSubtle,
                                      buttonTextPrimaryColor:
                                          t.buttonForeground,
                                      onTap: () {
                                        setState(() {
                                          localMonth = monthNumber;
                                        });
                                        HapticFeedback.selectionClick();
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ===== BOTONES DE ACCIÓN =====
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: cardColor,
                          border: Border(
                            top: BorderSide(color: t.borderSubtle, width: 1),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: _buildActionButton(
                                  label: 'Cancelar',
                                  isOutlined: true,
                                  textColor: t.textSecondary,
                                  borderColor: t.borderVisible,
                                  buttonTextPrimaryColor: t.buttonForeground,
                                  onTap: () {
                                    Navigator.pop(context);
                                    HapticFeedback.mediumImpact();
                                  },
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 6,
                                child: _buildActionButton(
                                  label: 'Aplicar filtro',
                                  isPrimary: true,
                                  accentColor: accentColor,
                                  textColor: t.textSecondary,
                                  borderColor: t.borderVisible,
                                  buttonTextPrimaryColor: t.buttonForeground,
                                  onTap: () {
                                    setState(() {
                                      _selectedMonth = localMonth;
                                      _selectedYear = localYear;
                                      final date = DateTime(
                                        _selectedYear,
                                        _selectedMonth,
                                      );
                                      _selectedMonthYear = _formatDate(date);

                                      if (widget.onDateSelected != null) {
                                        widget.onDateSelected!(
                                          _selectedMonth,
                                          _selectedYear,
                                        );
                                      }
                                    });
                                    Navigator.pop(context);
                                    HapticFeedback.mediumImpact();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );

            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Center(
                  child: useBlur
                      ? BackdropFilter(
                          filter: ImageFilter.blur(
                            sigmaX: blurAnimation.value,
                            sigmaY: blurAnimation.value,
                          ),
                          child: dialogCard,
                        )
                      : dialogCard,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMultiCurrencyAmountColumn(
    Map<String, double>? byCurrency,
    double fallbackAmount,
    TextStyle style, {
    bool useSignPrefix = false,
    double? fontSizeOverride,
    bool scaleDownToFit = true,
  }) {
    final effectiveStyle = fontSizeOverride != null
        ? style.copyWith(fontSize: fontSizeOverride)
        : style;

    Widget buildAmountText(String text) {
      final textWidget = Text(
        text,
        maxLines: 1,
        style: effectiveStyle,
      );
      if (!scaleDownToFit) return textWidget;
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: textWidget,
      );
    }

    if (byCurrency != null && byCurrency.isNotEmpty) {
      final totals = MultiCurrencyTotals(initial: byCurrency);
      if (totals.isMultiCurrency) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: totals.currencies.map((code) {
            final value = totals.totalFor(code);
            final formatted = CurrencyHelper.formatFor(
              useSignPrefix ? value.abs() : value,
              code,
            );
            final text = useSignPrefix && value < 0
                ? '- $formatted $code'
                : '$formatted $code';
            return buildAmountText(text);
          }).toList(growable: false),
        );
      }

      final singleCode = totals.currencies.first;
      final singleVal = totals.totalFor(singleCode);
      final formatted = CurrencyHelper.formatFor(
        useSignPrefix ? singleVal.abs() : singleVal,
        singleCode,
      );
      final text = useSignPrefix && singleVal < 0 ? '- $formatted' : formatted;
      return buildAmountText(text);
    }

    final formatted = CurrencyHelper.format(
      useSignPrefix ? fallbackAmount.abs() : fallbackAmount,
    );
    final text = useSignPrefix && fallbackAmount < 0 ? '- $formatted' : formatted;
    return buildAmountText(text);
  }

  @override
  Widget build(BuildContext context) {
    final Listenable balanceListenable =
        widget.availableBalancesByCurrencyNotifier ??
            widget.availableBalanceNotifier;

    return AnimatedBuilder(
      animation: balanceListenable,
      builder: (context, child) {
        final double availableBalance = widget.availableBalanceNotifier.value;
        final Map<String, double>? availableByCurrency =
            widget.availableBalancesByCurrencyNotifier?.value ??
                widget.availableBalancesByCurrency;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isLight = !isDark;
        final bool isDiurno = context.isDiurno;
        final bool isMultiCurrencyAvailable =
            availableByCurrency != null && availableByCurrency.length > 1;

        final bool isExceeded = widget.totalExpenses > widget.totalIncome;
        final Color ringStatusColor = isExceeded
            ? context.appTheme.expense
            : context.appTheme.income;
        final double ringValue = isExceeded
            ? 1.0
            : (widget.totalIncome > 0
                ? ((widget.totalIncome - widget.totalExpenses) /
                        widget.totalIncome)
                    .clamp(0.0, 1.0)
                : 0.0);
        final String ringPercentText = isExceeded
            ? (widget.totalIncome > 0
                ? '+${(((widget.totalExpenses - widget.totalIncome) / widget.totalIncome) * 100).round()}%'
                : '100%')
            : (widget.totalIncome > 0
                ? '${(((widget.totalIncome - widget.totalExpenses) / widget.totalIncome) * 100).round()}%'
                : '0%');
        final String ringBadgeText = isExceeded
            ? 'EXCEDIDO'
            : (widget.totalExpenses == 0 ? 'COMPLETO' : 'RESTANTE');

        return Container(
          decoration: BoxDecoration(
            color: isDiurno ? null : context.appTheme.cardBackground,
            gradient: isDiurno
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFF6F9FE),
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(
              isDiurno
                  ? AppSizes.borderRadiusXLarge
                  : AppSizes.borderRadiusLarge,
            ),
            border: isDiurno
                ? GradientBoxBorder(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white,
                        context.appTheme.borderSubtle,
                      ],
                    ),
                    width: 1.3,
                  )
                : Border.all(
                    color: context.appTheme.borderSubtle,
                    width: 1,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.06 : 0.12),
                blurRadius: isDiurno ? 14 : 6,
                offset: Offset(0, isDiurno ? 4 : 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(AppSizes.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FILA SUPERIOR: Disponible, Balance contable y gráfica
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Textos de Disponible y Balance contable
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Disponible',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: AppSizes.fontLarge,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _buildMultiCurrencyAmountColumn(
                          availableByCurrency,
                          availableBalance,
                          TextStyle(
                            color: context.appTheme.textPrimary,
                            fontSize: isMultiCurrencyAvailable ? 20 : 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing:
                                isMultiCurrencyAvailable ? -0.2 : -0.5,
                            height: 1.1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (widget.accountingBalancesByCurrency != null &&
                            widget.accountingBalancesByCurrency!.length > 1)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance Contable:',
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: AppSizes.fontMedium,
                                ),
                              ),
                              const SizedBox(height: 2),
                              _buildMultiCurrencyAmountColumn(
                                widget.accountingBalancesByCurrency,
                                widget.accountingBalance,
                                TextStyle(
                                  color: context.appTheme.textPrimary,
                                  fontSize: AppSizes.fontLarge,
                                  fontWeight: FontWeight.bold,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                                useSignPrefix: true,
                              ),
                            ],
                          )
                        else if (widget.accountingBalance.abs() > 9999)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Balance Contable:',
                                style: TextStyle(
                                  color: context.appTheme.textSecondary,
                                  fontSize: AppSizes.fontMedium,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '${widget.accountingBalance < 0 ? "- " : ""}'
                                  '${CurrencyHelper.format(widget.accountingBalance.abs())}',
                                  style: TextStyle(
                                    color: widget.accountingBalance >= 0
                                        ? context.appTheme.textPrimary
                                        : context.appTheme.expense,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Text(
                            'Balance Contable: '
                            '${widget.accountingBalance < 0 ? "- " : ""}'
                            '${CurrencyHelper.format(widget.accountingBalance.abs())}',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: AppSizes.fontMedium,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Gráfica: Anillo que muestra el % de ingresos/egresos
                  Semantics(
                    label: (widget.totalIncome > 0 || widget.totalExpenses > 0)
                        ? 'Resumen del período: $ringPercentText $ringBadgeText'
                        : 'Resumen del período sin movimientos',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            height: 90,
                            child: CircularProgressIndicator(
                              value: ringValue,
                              strokeWidth: 8,
                              backgroundColor: context.appTheme.darkBackground,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                ringStatusColor,
                              ),
                            ),
                          ),
                          if (widget.totalIncome > 0 ||
                              widget.totalExpenses > 0)
                            SizedBox(
                              width: 68,
                              height: 68,
                              child: Center(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        ringPercentText,
                                        style: TextStyle(
                                          color: context.appTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: ringStatusColor.withValues(
                                            alpha: isDark ? 0.18 : 0.08,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                          border: Border.all(
                                            color: ringStatusColor.withValues(
                                              alpha: 0.55,
                                            ),
                                            width: 0.6,
                                          ),
                                        ),
                                        child: Text(
                                          ringBadgeText,
                                          style: TextStyle(
                                            color: isDark
                                                ? context.appTheme.textPrimary
                                                : ringStatusColor,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.1,
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
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA DE BOTONES: Gestionar cuentas y Selector de mes/año
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: Semantics(
                      button: true,
                      label: 'Gestionar cuentas',
                      child: Tooltip(
                        message: 'Gestionar cuentas',
                        child: ElevatedButton(
                          onPressed: widget.onManageAccounts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDiurno
                                ? context.appTheme.secondaryCardBackground
                                : context.appTheme.primaryBackground,
                            elevation: 0,
                            minimumSize: const Size(0, 48),
                            side: BorderSide(
                              color: context.appTheme.borderSubtle,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isDiurno
                                    ? AppSizes.borderRadiusMedium
                                    : AppSizes.borderRadiusSmall,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: isDiurno
                                    ? context.appTheme.accent
                                    : context.appTheme.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Gestionar cuentas',
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: AppSizes.fontMedium,
                                      fontWeight: isDiurno
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: context.appTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: Semantics(
                      button: true,
                      label: 'Seleccionar período: $_selectedMonthYear',
                      child: Tooltip(
                        message: 'Seleccionar período',
                        child: ElevatedButton(
                          onPressed: _showMonthYearSelector,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDiurno
                                ? context.appTheme.secondaryCardBackground
                                : context.appTheme.primaryBackground,
                            elevation: 0,
                            minimumSize: const Size(0, 48),
                            side: BorderSide(
                              color: context.appTheme.borderSubtle,
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                isDiurno
                                    ? AppSizes.borderRadiusMedium
                                    : AppSizes.borderRadiusSmall,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.calendar_month,
                                size: 16,
                                color: isDiurno
                                    ? context.appTheme.accent
                                    : context.appTheme.textPrimary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _selectedMonthYear,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: AppSizes.fontMedium,
                                      fontWeight: isDiurno
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: context.appTheme.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // FILA: Total de egresos y Total de ingresos
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.paddingMedium),
                      margin: const EdgeInsets.only(right: 4.0),
                      decoration: BoxDecoration(
                        color: isDiurno
                            ? context.appTheme.secondaryCardBackground
                            : context.appTheme.primaryBackground,
                        borderRadius: BorderRadius.circular(
                          isDiurno
                              ? AppSizes.borderRadiusMedium
                              : AppSizes.borderRadiusSmall,
                        ),
                        border: Border.all(color: context.appTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de egresos',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: AppSizes.fontMedium,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildMultiCurrencyAmountColumn(
                            widget.expensesByCurrency,
                            widget.totalExpenses,
                            TextStyle(
                              color: context.appTheme.textPrimary,
                              fontSize: (widget.expensesByCurrency != null &&
                                      widget.expensesByCurrency!.length > 1)
                                  ? 14
                                  : 16,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(AppSizes.paddingMedium),
                      margin: const EdgeInsets.only(left: 4.0),
                      decoration: BoxDecoration(
                        color: isDiurno
                            ? context.appTheme.secondaryCardBackground
                            : context.appTheme.primaryBackground,
                        borderRadius: BorderRadius.circular(
                          isDiurno
                              ? AppSizes.borderRadiusMedium
                              : AppSizes.borderRadiusSmall,
                        ),
                        border: Border.all(color: context.appTheme.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de ingresos',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: AppSizes.fontMedium,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _buildMultiCurrencyAmountColumn(
                            widget.incomeByCurrency,
                            widget.totalIncome,
                            TextStyle(
                              color: context.appTheme.income,
                              fontSize: (widget.incomeByCurrency != null &&
                                      widget.incomeByCurrency!.length > 1)
                                  ? 14
                                  : 16,
                              fontWeight: FontWeight.bold,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Método para construir botones direccionales
Widget _buildDirectionalButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  required Color color,
}) {
  return Semantics(
    button: true,
    label: label,
    child: Tooltip(
      message: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
          child: Ink(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
        ),
      ),
    ),
  );
}

// Método para construir selector de mes
Widget _buildMonthSelector({
  required String monthName,
  required String fullMonthName,
  required bool isSelected,
  required Color accentColor,
  required Color cardColor,
  required Color textColor,
  required Color borderColor,
  required Color buttonTextPrimaryColor,
  required VoidCallback onTap,
}) {
  return Semantics(
    button: true,
    selected: isSelected,
    label: fullMonthName,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
        splashColor: accentColor.withValues(alpha: 0.1),
        highlightColor: accentColor.withValues(alpha: 0.05),
        child: Ink(
          decoration: BoxDecoration(
            color: isSelected ? accentColor : cardColor,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            border: Border.all(
              color: isSelected ? accentColor : borderColor,
              width: isSelected ? 1.2 : 0.8,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  monthName,
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected
                        ? buttonTextPrimaryColor
                        : textColor.withValues(alpha: 0.85),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: isSelected ? 0.4 : 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

// Método para construir botones de acción
Widget _buildActionButton({
  required String label,
  required VoidCallback onTap,
  bool isPrimary = false,
  bool isOutlined = false,
  Color accentColor = Colors.white,
  required Color textColor,
  required Color borderColor,
  required Color buttonTextPrimaryColor,
}) {
  return Semantics(
    button: true,
    label: label,
    excludeSemantics: true,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: isPrimary ? accentColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMedium),
            border: isOutlined
                ? Border.all(
                    color: borderColor,
                    width: 1,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isPrimary) ...[
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: buttonTextPrimaryColor,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: isPrimary ? buttonTextPrimaryColor : textColor,
                        fontSize: isPrimary ? 15 : 14,
                        fontWeight:
                            isPrimary ? FontWeight.w600 : FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
