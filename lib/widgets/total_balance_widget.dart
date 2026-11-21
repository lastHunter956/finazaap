import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
    this.onDateSelected,
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

  // Selector de Mes/Año en Bottom Sheet moderno (sin BackdropFilter)
  void _showMonthYearSelector() {
    int localMonth = _selectedMonth;
    int localYear = _selectedYear;

    const List<String> monthNames = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (sheetContext) {
        final t = sheetContext.appTheme;
        final Color accentColor = t.buttonBackground;
        final Color surfaceColor = t.secondaryCardBackground;
        final Color cardColor = t.cardBackground;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final double maxHeight =
                MediaQuery.of(modalContext).size.height * 0.85;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: AppSizes.dialogMaxWidth + 80,
                maxHeight: maxHeight,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppSizes.borderRadius2XLarge),
                  ),
                  border: Border(
                    top: BorderSide(color: t.borderSubtle, width: 1),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: 38,
                        height: 4,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: t.borderVisible,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Cabecera limpia
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  'Seleccionar período',
                                  style: TextStyle(
                                    color: t.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 150),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: t.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      '${monthNames[localMonth - 1]} $localYear',
                                      maxLines: 1,
                                      style: TextStyle(
                                        color: t.accent,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Filtrar transacciones por mes y año',
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Divider(height: 1, thickness: 1, color: t.borderSubtle),

                    // Cuerpo scrollable (Año + Grilla de 12 meses)
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Selector de año
                            Container(
                              height: 52,
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
                                      setModalState(() {
                                        localYear--;
                                      });
                                      HapticFeedback.selectionClick();
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
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.4,
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
                                      setModalState(() {
                                        localYear++;
                                      });
                                      HapticFeedback.selectionClick();
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Grilla de 12 meses con targets cómodos (>= 48dp)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisExtent: 48,
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
                                  buttonTextPrimaryColor: t.buttonForeground,
                                  onTap: () {
                                    setModalState(() {
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

                    // Botones de acción
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
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
                                  HapticFeedback.selectionClick();
                                  Navigator.pop(modalContext);
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
                                  HapticFeedback.selectionClick();
                                  if (mounted) {
                                    setState(() {
                                      _selectedMonth = localMonth;
                                      _selectedYear = localYear;
                                      final date = DateTime(
                                        _selectedYear,
                                        _selectedMonth,
                                      );
                                      _selectedMonthYear = _formatDate(date);
                                    });
                                  }
                                  widget.onDateSelected?.call(
                                    localMonth,
                                    localYear,
                                  );
                                  Navigator.pop(modalContext);
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

  Widget _buildAccountingBalanceSection(AppTheme t) {
    final bool isMultiAccounting = widget.accountingBalancesByCurrency != null &&
        widget.accountingBalancesByCurrency!.length > 1;

    if (isMultiAccounting) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance Contable',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          _buildMultiCurrencyAmountColumn(
            widget.accountingBalancesByCurrency,
            widget.accountingBalance,
            TextStyle(
              color: t.textPrimary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
            useSignPrefix: true,
          ),
        ],
      );
    }

    final String formattedAccounting =
        '${widget.accountingBalance < 0 ? "- " : ""}'
        '${CurrencyHelper.format(widget.accountingBalance.abs())}';

    return Wrap(
      spacing: 6,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Balance Contable',
          style: TextStyle(
            color: t.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          formattedAccounting,
          style: TextStyle(
            color: widget.accountingBalance >= 0 ? t.textPrimary : t.expense,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricColumn({
    required AppTheme t,
    required String label,
    required IconData icon,
    required Color semanticColor,
    required Map<String, double>? byCurrency,
    required double fallbackAmount,
  }) {
    final bool isMulti = byCurrency != null && byCurrency.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: semanticColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                icon,
                size: 13,
                color: semanticColor,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
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
        const SizedBox(height: 6),
        _buildMultiCurrencyAmountColumn(
          byCurrency,
          fallbackAmount,
          TextStyle(
            color: semanticColor,
            fontSize: isMulti ? 13.5 : 16,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Listenable balanceListenable =
        widget.availableBalancesByCurrencyNotifier ??
            widget.availableBalanceNotifier;

    return AnimatedBuilder(
      animation: balanceListenable,
      builder: (context, child) {
        final t = context.appTheme;
        final double availableBalance = widget.availableBalanceNotifier.value;
        final Map<String, double>? availableByCurrency =
            widget.availableBalancesByCurrencyNotifier?.value ??
                widget.availableBalancesByCurrency;
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isLight = !isDark;
        final bool isMultiCurrencyAvailable =
            availableByCurrency != null && availableByCurrency.length > 1;

        final bool hasMovements =
            widget.totalIncome > 0 || widget.totalExpenses > 0;
        final bool isExceeded = widget.totalExpenses > widget.totalIncome;
        final Color ringStatusColor = isExceeded ? t.expense : t.income;
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

        final Color metricsSurface = isLight
            ? t.secondaryCardBackground
            : t.darkBackground.withValues(alpha: 0.45);

        return Container(
          decoration: BoxDecoration(
            color: t.cardBackground,
            borderRadius: BorderRadius.circular(AppSizes.borderRadius2XLarge),
            border: Border.all(
              color: t.borderSubtle,
              width: 1,
            ),
            boxShadow: isLight
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(AppSizes.paddingXLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // CABECERA INTEGRADA: 'Disponible' a la izquierda + pill de período a la derecha
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Disponible',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Seleccionar período: $_selectedMonthYear',
                    child: Tooltip(
                      message: 'Seleccionar período',
                      child: Material(
                        color: metricsSurface,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            _showMonthYearSelector();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 40,
                              minWidth: 48,
                              maxWidth: 170,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: t.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.calendar_month_rounded,
                                    size: 15,
                                    color: t.accent,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _selectedMonthYear,
                                        maxLines: 1,
                                        style: TextStyle(
                                          color: t.textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 16,
                                    color: t.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // BLOQUE HERO: Saldo protagonista + Balance Contable + Arco animado
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMultiCurrencyAmountColumn(
                          availableByCurrency,
                          availableBalance,
                          TextStyle(
                            color: t.textPrimary,
                            fontSize: isMultiCurrencyAvailable ? 22 : 34,
                            fontWeight: FontWeight.bold,
                            letterSpacing:
                                isMultiCurrencyAvailable ? -0.3 : -0.8,
                            height: 1.08,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildAccountingBalanceSection(t),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Semantics(
                    label: hasMovements
                        ? 'Resumen del período: $ringPercentText $ringBadgeText'
                        : 'Resumen del período sin movimientos',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: ringValue),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedProgress, innerChild) {
                          return CustomPaint(
                            key: const Key('budget_progress_arc'),
                            size: const Size(96, 96),
                            painter: BudgetArcPainter(
                              progress: animatedProgress,
                              trackColor: t.darkBackground,
                              progressColor: ringStatusColor,
                              strokeWidth: 8.5,
                            ),
                            child: innerChild,
                          );
                        },
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: hasMovements
                                  ? Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          ringPercentText,
                                          style: TextStyle(
                                            color: t.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: const [
                                              FontFeature.tabularFigures(),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: ringStatusColor.withValues(
                                              alpha: isDark ? 0.18 : 0.10,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            ringBadgeText,
                                            style: TextStyle(
                                              color: isDark
                                                  ? t.textPrimary
                                                  : ringStatusColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.25,
                                            ),
                                          ),
                                        ),
                                      ],
                                    )
                                  : Text(
                                      '0%',
                                      style: TextStyle(
                                        color: t.textHint,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        fontFeatures: const [
                                          FontFeature.tabularFigures(),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // MÉTRICAS INGRESOS / EGRESOS EN SUPERFICIE TONAL ÚNICA CON DIVIDER SUTIL
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: metricsSurface,
                  borderRadius: BorderRadius.circular(
                    AppSizes.borderRadiusLarge,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildMetricColumn(
                          t: t,
                          label: 'Total de ingresos',
                          icon: Icons.arrow_downward_rounded,
                          semanticColor: t.income,
                          byCurrency: widget.incomeByCurrency,
                          fallbackAmount: widget.totalIncome,
                        ),
                      ),
                      VerticalDivider(
                        width: 24,
                        thickness: 1,
                        indent: 4,
                        endIndent: 4,
                        color: t.borderSubtle,
                      ),
                      Expanded(
                        child: _buildMetricColumn(
                          t: t,
                          label: 'Total de egresos',
                          icon: Icons.arrow_upward_rounded,
                          semanticColor: t.expense,
                          byCurrency: widget.expensesByCurrency,
                          fallbackAmount: widget.totalExpenses,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // BOTÓN LIMPIO Y ERGONÓMICO PARA GESTIONAR CUENTAS
              Semantics(
                button: true,
                label: 'Gestionar cuentas',
                child: Tooltip(
                  message: 'Gestionar cuentas',
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onManageAccounts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: metricsSurface,
                        foregroundColor: t.textPrimary,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size(double.infinity, 48),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: t.borderSubtle,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 18,
                            color: t.accent,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Gestionar cuentas',
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: t.textPrimary,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: t.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BudgetArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  const BudgetArcPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final Rect arcRect = Rect.fromCircle(center: center, radius: radius);

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    final double clampedProgress = progress.clamp(0.0, 1.0);
    if (clampedProgress > 0) {
      final Paint progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final double sweepAngle = 2 * math.pi * clampedProgress;
      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant BudgetArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusLarge),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
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
              width: isSelected ? 1.2 : 0.9,
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
                        : textColor.withValues(alpha: 0.88),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: isSelected ? 0.3 : 0.15,
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
                        Icons.check_rounded,
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
                        letterSpacing: 0.15,
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
