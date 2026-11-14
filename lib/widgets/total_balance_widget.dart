import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/themes/app_theme_data.dart';

class TotalBalanceWidget extends StatefulWidget {
  // ========= Valores dinámicos =========
  final ValueNotifier<double> availableBalanceNotifier; // Notificador de saldo disponible
  final double accountingBalance;  // Balance contable (puede ser negativo)
  final double totalExpenses;      // Total de egresos
  final double totalIncome;        // Total de ingresos

  // ========= Callbacks para botones =========
  final VoidCallback onManageAccounts;
  final VoidCallback onShowAll;
  final VoidCallback onShowExpenses;
  final VoidCallback onShowIncome;

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
    required this.onShowAll,
    required this.onShowExpenses,
    required this.onShowIncome,
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
  
  // Añadir la variable selectedFilter que falta
  String selectedFilter = 'Todos';
  bool _isLocaleInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Inicializar los datos de localización antes de formatear fechas
    initializeDateFormatting('es').then((_) {
      setState(() {
        _isLocaleInitialized = true;
        
        // Inicializar con la fecha actual
        final now = DateTime.now();
        _selectedMonth = now.month;
        _selectedYear = now.year;
        _selectedMonthYear = _formatDate(now);
        
        // Notificar al padre sobre la selección inicial
        if (widget.onDateSelected != null) {
          widget.onDateSelected!(_selectedMonth, _selectedYear);
        }
      });
    });
  }

  // Método para formatear fecha con seguridad
  String _formatDate(DateTime date) {
    if (!_isLocaleInitialized) {
      // Retornar un valor predeterminado mientras se inicializa
      return widget.selectedMonthYear;
    }
    final formatted = DateFormat('MMM yyyy', 'es').format(date).replaceAll('.', '');
    if (formatted.isEmpty) return formatted;
    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  // Método mejorado para mostrar el selector de mes/año con diseño premium
  void _showMonthYearSelector() {
    // Variables para el selector
    int localMonth = _selectedMonth;
    int localYear = _selectedYear;
    
    // Constantes de diseño - Sistema de tokens profesional
    const double cornerRadius = 24.0;
    final t = this.context.appTheme;
    final Color accentColor = t.secondaryAccent;
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
            
            return ScaleTransition(
              scale: scaleAnimation,
              child: FadeTransition(
                opacity: fadeAnimation,
                child: Center(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurAnimation.value,
                      sigmaY: blurAnimation.value,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.87,
                        constraints: BoxConstraints(
                          maxWidth: 400,
                          maxHeight: MediaQuery.of(context).size.height * 0.85,
                        ),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(cornerRadius),
                          boxShadow: [
                            // Sombra principal profunda
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 25,
                              offset: const Offset(0, 12),
                              spreadRadius: -5,
                            ),
                            // Resplandor sutil del color acentuado
                            BoxShadow(
                              color: accentColor.withOpacity(0.18),
                              blurRadius: 30,
                              offset: const Offset(0, 3),
                              spreadRadius: -2,
                            ),
                          ],
                          // Borde refinado con gradiente sutil
                          border: GradientBoxBorder(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.15),
                                accentColor.withOpacity(0.2),
                                Colors.white.withOpacity(0.02),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.3, 0.7, 1.0],
                            ),
                            width: 1.5,
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
                                padding: const EdgeInsets.fromLTRB(24, 28, 24, 18),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      accentColor.withOpacity(0.22),
                                      accentColor.withOpacity(0.10),
                                      accentColor.withOpacity(0.05),
                                    ],
                                    stops: const [0.0, 0.6, 1.0],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    // Elementos decorativos
                                    Positioned(
                                      right: -15,
                                      top: -20,
                                      child: Container(
                                        width: 80,
                                        height: 80,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              accentColor.withOpacity(0.3),
                                              Colors.transparent,
                                            ],
                                            stops: const [0.1, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                    
                                    // Contenido de la cabecera
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Icono y título en línea
                                        Row(
                                          children: [
                                            
                                            SizedBox(width: 10),
                                            Text(
                                              'Seleccionar período',
                                              style: TextStyle(
                                                color: t.textPrimary,
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ],
                                        ),
                                        
                                        Padding(
                                          padding: const EdgeInsets.only(left: 10),
                                          child: Text(
                                            'Filtrar transacciones por mes y año',
                                            style: TextStyle(
                                              color: t.textSecondary,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Vista previa de selección
                                        Container(
                                          margin: EdgeInsets.only(top: 6),
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          decoration: BoxDecoration(
                                            color: cardColor.withOpacity(0.6),
                                            borderRadius: BorderRadius.circular(14),
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
                                              SizedBox(width: 8),
                                              Text(
                                                "${monthNames[localMonth-1]} ${localYear}",
                                                style: TextStyle(
                                                  color: t.textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Contenedor principal con scroll si es necesario
                              Flexible(
                                child: SingleChildScrollView(
                                  physics: BouncingScrollPhysics(),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        
                                        
                                        const SizedBox(height: 12),
                                        
                                        // Control para selección de año con efecto tarjeta
                                        Container(
                                          height: 60,
                                          decoration: BoxDecoration(
                                            color: cardColor,
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(
                                              color: t.borderSubtle,
                                              width: 1,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.15),
                                                blurRadius: 10,
                                                offset: const Offset(0, 5),
                                                spreadRadius: -3,
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              // Botón año anterior con efecto hover
                                              _buildDirectionalButton(
                                                icon: Icons.chevron_left_rounded,
                                                color: t.textPrimary,
                                                onTap: () {
                                                  setState(() {
                                                    localYear--;
                                                  });
                                                  HapticFeedback.lightImpact();
                                                },
                                              ),
                                              
                                              // Año seleccionado con efecto de glow
                                              Expanded(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        t.darkBackground,
                                                        t.darkBackground.withOpacity(0.8),
                                                      ],
                                                    ),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      localYear.toString(),
                                                      style: TextStyle(
                                                        color: t.textPrimary,
                                                        fontSize: 22,
                                                        fontWeight: FontWeight.bold,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              
                                              // Botón año siguiente
                                              _buildDirectionalButton(
                                                icon: Icons.chevron_right_rounded,
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
                                        
                                        const SizedBox(height: 28),
                                        
                                
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Grid de meses con diseño premium
                                        GridView.builder(
                                          shrinkWrap: true,
                                          physics: NeverScrollableScrollPhysics(),
                                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                            crossAxisCount: 3,
                                            childAspectRatio: 2.0,
                                            crossAxisSpacing: 12,
                                            mainAxisSpacing: 12,
                                          ),
                                          itemCount: 12,
                                          itemBuilder: (context, index) {
                                            final int monthNumber = index + 1;
                                            final bool isSelected = localMonth == monthNumber;
                                            
                                            return _buildMonthSelector(
                                              monthName: monthNames[index].substring(0, 3),
                                              isSelected: isSelected,
                                              accentColor: accentColor,
                                              cardColor: cardColor,
                                              textColor: t.textPrimary,
                                              borderColor: t.borderSubtle,
                                              buttonTextPrimaryColor: t.buttonForeground,
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
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                                      // Botón Cancelar
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
                                      
                                      const SizedBox(width: 12),
                                      
                                      // Botón Aplicar
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
                                            // Actualizar estado y notificar
                                            setState(() {
                                              _selectedMonth = localMonth;
                                              _selectedYear = localYear;
                                              final date = DateTime(_selectedYear, _selectedMonth);
                                              _selectedMonthYear = _formatDate(date);
                                              
                                              if (widget.onDateSelected != null) {
                                                widget.onDateSelected!(_selectedMonth, _selectedYear);
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
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Formateador de moneda
    // Formateador de moneda eliminado, usando CurrencyHelper

    // Porcentaje de ingresos vs. total (ingresos + egresos)
    final double total = widget.totalIncome + widget.totalExpenses;
    double ratio = total > 0 ? widget.totalIncome / total : 0;

    return ValueListenableBuilder<double>(
      valueListenable: widget.availableBalanceNotifier,
      builder: (context, availableBalance, child) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        final bool isDiurno = context.isDiurno;
        final Color ringStatusColor = widget.totalExpenses > widget.totalIncome
            ? context.appTheme.expense
            : context.appTheme.income;
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
            borderRadius: BorderRadius.circular(isDiurno ? 22 : 16),
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
            boxShadow: isDiurno
                ? const [
                    BoxShadow(
                      color: Color(0x120B132B),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                      spreadRadius: -4,
                    ),
                    BoxShadow(
                      color: Color(0x0A0062CC),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // FILA SUPERIOR: Disponible, Balance contable y gráfica
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Textos de Disponible y Balance contable
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disponible',
                        style: TextStyle(
                          color: context.appTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${CurrencyHelper.format(availableBalance)}',
                        style: TextStyle(
                          color: context.appTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Si el valor absoluto es mayor a 9,999, mostrar en dos líneas
                      if (widget.accountingBalance.abs() > 9999)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance Contable:',
                              style: TextStyle(
                                color: context.appTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${widget.accountingBalance < 0 ? "- " : ""}'
                              '${CurrencyHelper.format(widget.accountingBalance.abs())}',
                              style: TextStyle(
                                color: widget.accountingBalance >= 0
                                    ? context.appTheme.textPrimary
                                    : context.appTheme.expense,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      else
                        // Para valores pequeños mantener en una sola línea
                        Text(
                          'Balance Contable: '
                          '${widget.accountingBalance < 0 ? "- " : ""}'
                          '${CurrencyHelper.format(widget.accountingBalance.abs())}',
                          style: TextStyle(
                            color: context.appTheme.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                  // Gráfica: Anillo que muestra el % de ingresos/egresos con diseño mejorado
                  Stack(
                    alignment: Alignment.center, 
                    children: [
                      // El gráfico circular sin fondo y con mejor diseño - AUMENTADO DE TAMAÑO
                      SizedBox(
                        width: 100, // Mantenemos el mismo contenedor
                        height: 100,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Fondo circular transparente pero con el tamaño real del gráfico
                            Container(
                              width: 10, // Tamaño real del gráfico
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.transparent,
                              ),
                            ),
                            
                            // Indicador circular con tamaño real aumentado
                            SizedBox(
                              width: 90, // Tamaño real del gráfico circular
                              height: 90, // Tamaño real del gráfico circular
                              child: CircularProgressIndicator(
                                 value: widget.totalIncome > 0 
                                    ? (widget.totalIncome - widget.totalExpenses) / widget.totalIncome  // Porcentaje restante
                                    : 0,  // Si no hay ingresos, el valor es 0
                                strokeWidth: 8, // Mantenemos el mismo grosor
                                backgroundColor: context.appTheme.darkBackground,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  ringStatusColor,
                                ),
                              ),
                            ),
                            
                            // Textos centrados dentro del gráfico con mejor legibilidad - SIN FONDO
                            if (widget.totalIncome > 0)
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Porcentaje con mejor legibilidad - SIN FONDO
                                  Text(
                                    widget.totalIncome > 0
                                        ? '${(((widget.totalIncome - widget.totalExpenses) / widget.totalIncome) * 100).round()}%'
                                        : '0%', // Si no hay ingresos, mostrar 0%
                                    style: TextStyle(
                                      color: context.appTheme.textPrimary,
                                      fontSize: 15, // Mantenemos el tamaño de fuente
                                      fontWeight: FontWeight.bold,
                                      shadows: isDark
                                          ? const [
                                              Shadow(
                                                offset: Offset(0, 1),
                                                blurRadius: 2.0,
                                                color: Color.fromARGB(100, 0, 0, 0),
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  
                                  // Etiqueta "AHORRO" o "EXCEDIDO" - sin cambios en su diseño
                                  Container(
                                    margin: const EdgeInsets.only(top: 2),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: ringStatusColor.withValues(alpha: isDark ? 0.18 : 0.08),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: ringStatusColor.withValues(alpha: 0.55),
                                        width: 0.6,
                                      ),
                                    ),
                                    child: Text(
                                      widget.totalExpenses > widget.totalIncome 
                                          ? 'EXCEDIDO' 
                                          : widget.totalExpenses == 0 
                                              ? 'COMPLETO'  // Si no hay gastos, está completo
                                              : 'RESTANTE', // Si hay gastos pero no exceden, muestra "RESTANTE"
                                      style: TextStyle(
                                        color: isDark ? context.appTheme.textPrimary : ringStatusColor,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.1,
                                        shadows: isDark
                                            ? [
                                                Shadow(
                                                  offset: const Offset(0, 1),
                                                  blurRadius: 1.0,
                                                  color: Colors.black.withValues(alpha: 0.3),
                                                ),
                                              ]
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA DE BOTONES: Gestionar cuentas y Fecha (selector de mes/año)
              Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: ElevatedButton.icon(
                      onPressed: widget.onManageAccounts,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDiurno
                            ? context.appTheme.secondaryCardBackground
                            : context.appTheme.primaryBackground,
                        elevation: 0,
                        side: BorderSide(
                          color: context.appTheme.borderSubtle,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(isDiurno ? 12.0 : 8.0),
                        ),
                      ),
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 16,
                        color: isDiurno
                            ? context.appTheme.accent
                            : context.appTheme.textPrimary,
                      ),
                      label: Text(
                        'Gestionar cuentas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isDiurno ? FontWeight.w600 : FontWeight.normal,
                          color: context.appTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: _showMonthYearSelector,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDiurno
                            ? context.appTheme.secondaryCardBackground
                            : context.appTheme.primaryBackground,
                        elevation: 0,
                        side: BorderSide(
                          color: context.appTheme.borderSubtle,
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(isDiurno ? 12.0 : 8.0),
                        ),
                      ),
                      icon: Icon(
                        Icons.calendar_month,
                        size: 16,
                        color: isDiurno
                            ? context.appTheme.accent
                            : context.appTheme.textPrimary,
                      ),
                      label: Text(
                        _selectedMonthYear,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isDiurno ? FontWeight.w600 : FontWeight.normal,
                          color: context.appTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA: Total de egresos y Total de ingresos
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(right: 4.0),
                      decoration: BoxDecoration(
                        color: isDiurno
                            ? context.appTheme.secondaryCardBackground
                            : context.appTheme.primaryBackground,
                        borderRadius: BorderRadius.circular(isDiurno ? 14.0 : 8.0),
                        border: isDiurno
                            ? Border.all(color: context.appTheme.borderSubtle)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de egresos',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${CurrencyHelper.format(widget.totalExpenses)}',
                            style: TextStyle(
                              color: context.appTheme.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12.0),
                      margin: const EdgeInsets.only(left: 4.0),
                      decoration: BoxDecoration(
                        color: isDiurno
                            ? context.appTheme.secondaryCardBackground
                            : context.appTheme.primaryBackground,
                        borderRadius: BorderRadius.circular(isDiurno ? 14.0 : 8.0),
                        border: isDiurno
                            ? Border.all(color: context.appTheme.borderSubtle)
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total de ingresos',
                            style: TextStyle(
                              color: context.appTheme.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${CurrencyHelper.format(widget.totalIncome)}',
                            style: TextStyle(
                              color: context.appTheme.income,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // FILA DE PESTAÑAS: Todos, Gastos, Ingresos
              if (isDiurno)
                _buildDiurnoSegmentedFilters(context)
              else
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedFilter = 'Todos';
                        });
                        widget.onShowAll();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedFilter == 'Todos'
                            ? context.appTheme.primaryBackground
                            : context.appTheme.cardBackground,
                        elevation: 0,
                        side: BorderSide(
                          color: selectedFilter == 'Todos'
                              ? context.appTheme.accent
                              : context.appTheme.borderSubtle,
                          width: selectedFilter == 'Todos' ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        'Todos',
                        style: TextStyle(
                          color: selectedFilter == 'Todos'
                              ? context.appTheme.textPrimary
                              : context.appTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedFilter = 'Gastos';
                        });
                        widget.onShowExpenses();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedFilter == 'Gastos'
                            ? context.appTheme.primaryBackground
                            : context.appTheme.cardBackground,
                        elevation: 0,
                        side: BorderSide(
                          color: selectedFilter == 'Gastos'
                              ? context.appTheme.accent
                              : context.appTheme.borderSubtle,
                          width: selectedFilter == 'Gastos' ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        'Gastos',
                        style: TextStyle(
                          color: selectedFilter == 'Gastos'
                              ? context.appTheme.textPrimary
                              : context.appTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          selectedFilter = 'Ingresos';
                        });
                        widget.onShowIncome();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: selectedFilter == 'Ingresos'
                            ? context.appTheme.primaryBackground
                            : context.appTheme.cardBackground,
                        elevation: 0,
                        side: BorderSide(
                          color: selectedFilter == 'Ingresos'
                              ? context.appTheme.accent
                              : context.appTheme.borderSubtle,
                          width: selectedFilter == 'Ingresos' ? 1.5 : 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                      child: Text(
                        'Ingresos',
                        style: TextStyle(
                          color: selectedFilter == 'Ingresos'
                              ? context.appTheme.textPrimary
                              : context.appTheme.textSecondary,
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

  Widget _buildDiurnoSegmentedFilters(BuildContext context) {
    final segments = [
      ('Todos', widget.onShowAll),
      ('Gastos', widget.onShowExpenses),
      ('Ingresos', widget.onShowIncome),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: context.appTheme.darkBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.appTheme.borderSubtle, width: 1),
      ),
      child: Row(
        children: segments.map((entry) {
          final label = entry.$1;
          final callback = entry.$2;
          final isSelected = selectedFilter == label;
          return Expanded(
            child: MoneoPressableScale(
              pressedScale: 0.97,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    selectedFilter = label;
                  });
                  callback();
                },
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.appTheme.cardBackground
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: isSelected
                        ? Border.all(
                            color: Colors.white.withValues(alpha: 0.95),
                            width: 1,
                          )
                        : null,
                    boxShadow: isSelected
                        ? const [
                            BoxShadow(
                              color: Color(0x140B132B),
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isSelected
                          ? context.appTheme.textPrimary
                          : context.appTheme.textSecondary,
                      fontSize: 13.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Método para construir etiquetas de sección
Widget _buildSectionLabel(String label, IconData icon) {
  return Builder(
    builder: (context) {
      final labelColor = context.appTheme.textPrimary.withValues(alpha: 0.85);
      return Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: labelColor,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      );
    },
  );
}

// Método para construir botones direccionales
Widget _buildDirectionalButton({
  required IconData icon,
  required VoidCallback onTap,
  required Color color,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(
          icon,
          color: color,
          size: 30,
        ),
      ),
    ),
  );
}

// Método para construir selector de mes
Widget _buildMonthSelector({
  required String monthName,
  required bool isSelected,
  required Color accentColor,
  required Color cardColor,
  required Color textColor,
  required Color borderColor,
  required Color buttonTextPrimaryColor,
  required VoidCallback onTap,
}) {
  return AnimatedContainer(
    duration: Duration(milliseconds: 200),
    curve: Curves.easeOutQuad,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: accentColor.withOpacity(0.1),
        highlightColor: accentColor.withOpacity(0.05),
        child: Ink(
          decoration: BoxDecoration(
            gradient: isSelected ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withOpacity(0.95),
                accentColor.withOpacity(0.75),
              ],
            ) : null,
            color: isSelected ? null : cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                ? accentColor 
                : borderColor,
              width: isSelected ? 1.2 : 0.8,
            ),
            boxShadow: isSelected ? [
              BoxShadow(
                color: accentColor.withOpacity(0.25),
                blurRadius: 8,
                offset: Offset(0, 2),
                spreadRadius: -2,
              )
            ] : null,
          ),
          child: Center(
            child: Text(
              monthName,
              style: TextStyle(
                color: isSelected 
                  ? buttonTextPrimaryColor 
                  : textColor.withOpacity(0.8),
                fontSize: 14,
                fontWeight: isSelected 
                  ? FontWeight.w700
                  : FontWeight.w500,
                letterSpacing: isSelected ? 0.5 : 0.2,
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
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        height: 50,
        decoration: BoxDecoration(
          gradient: isPrimary ? LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor,
              accentColor.withOpacity(0.85),
            ],
          ) : null,
          color: isPrimary ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isOutlined ? Border.all(
            color: borderColor,
            width: 1,
          ) : null,
          boxShadow: isPrimary ? [
            BoxShadow(
              color: accentColor.withOpacity(0.3),
              blurRadius: 10,
              offset: Offset(0, 4),
              spreadRadius: -4,
            ),
          ] : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isPrimary)
              Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: buttonTextPrimaryColor,
              ),
              
            if (isPrimary)
              SizedBox(width: 8),
              
            Text(
              label,
              style: TextStyle(
                color: isPrimary 
                  ? buttonTextPrimaryColor 
                  : textColor,
                fontSize: isPrimary ? 15 : 14,
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}