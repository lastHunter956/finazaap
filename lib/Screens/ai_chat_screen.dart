import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:finazaap/data/category_service.dart';
import 'package:finazaap/data/model/add_date.dart';
import 'package:finazaap/data/transaction_service.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/services/device_capability_service.dart';
import 'package:finazaap/themes/app_colors.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/app_icons.dart';
import 'package:finazaap/utils/currency_helper.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();
  final TextEditingController _modelUrlController =
      TextEditingController(text: AiChatService.defaultModelUrl);
  final ScrollController _scrollController = ScrollController();
  final AiChatService _chatService = AiChatService();
  bool _isLoading = false;
  bool _isInputEmpty = true;
  Map<String, dynamic>? _financialState;

  final List<IconData> _availableIcons = AppIcons.allIcons;
  final List<Color> _availableColors = const [
    Colors.redAccent,
    Colors.pinkAccent,
    Colors.purpleAccent,
    Colors.deepPurpleAccent,
    Colors.indigoAccent,
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.cyanAccent,
    Colors.tealAccent,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.limeAccent,
    Colors.yellowAccent,
    Colors.amberAccent,
    Colors.orangeAccent,
    Colors.deepOrangeAccent,
    Colors.blueGrey,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _chatService.addListener(_onServiceUpdate);
    _messageController.addListener(_onInputChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chatService.initialize();
      if (!mounted) return;
      _goalsController.text = _chatService.userGoals;
      await _loadFinancialState();
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _chatService.removeListener(_onServiceUpdate);
    _messageController.removeListener(_onInputChanged);
    _messageController.dispose();
    _goalsController.dispose();
    _modelUrlController.dispose();
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (!mounted) return;
    setState(() {});
    _loadFinancialState();
    _scrollToBottom();
  }

  void _onInputChanged() {
    final isEmpty = _messageController.text.trim().isEmpty;
    if (mounted && isEmpty != _isInputEmpty) {
      setState(() {
        _isInputEmpty = isEmpty;
      });
    }
  }

  Future<void> _loadFinancialState() async {
    try {
      final state = await _chatService.getFinancialState();
      if (mounted) {
        setState(() {
          _financialState = state;
        });
      }
    } catch (_) {
      // Omitir errores menores de base de datos en UI
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  void _showFeedbackSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    final t = context.appTheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.outfit(
            color: isError ? t.error : t.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: t.cardBackground,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: isError ? t.error.withValues(alpha: 0.5) : t.borderSubtle,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();
    setState(() {
      _isLoading = true;
    });

    try {
      await _chatService.sendMessage(text);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveGoals() async {
    final text = _goalsController.text.trim();
    if (text.isEmpty) return;
    await _chatService.updateUserGoals(text);
    _showFeedbackSnackBar('Metas financieras actualizadas en memoria.');
  }

  Color _getCategoryColor(String category) {
    final t = context.appTheme;
    switch (category.toLowerCase()) {
      case 'comida':
      case 'alimentos':
      case 'restaurantes':
        return t.warning;
      case 'transporte':
      case 'gasolina':
      case 'viajes':
        return t.accent;
      case 'servicios':
      case 'luz':
      case 'agua':
      case 'internet':
        return t.income;
      case 'entretenimiento':
      case 'ocio':
      case 'cine':
      case 'suscripciones':
        return t.secondaryAccent;
      case 'compras':
      case 'ropa':
      case 'regalos':
        return t.expense;
      case 'salud':
      case 'medicina':
        return t.success;
      case 'educación':
      case 'libros':
        return t.accent;
      default:
        return t.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    return Scaffold(
      backgroundColor: t.primaryBackground,
      appBar: null,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildUnifiedHeader(context),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatTab(),
                  _buildProfileTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedHeader(BuildContext context) {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;
    final isGemma = !_chatService.useLocalSimulator;
    final scaledTabFont = MediaQuery.textScalerOf(context).scale(12.5);
    final tabContainerHeight =
        36.0 + math.max(0.0, scaledTabFont - 12.5) * 1.5;

    final Color statusColor;
    final String statusLabel;
    if (!isGemma) {
      statusColor = t.accent;
      statusLabel = 'Simulador local offline';
    } else if (_chatService.gemmaInitialized) {
      statusColor = t.success;
      statusLabel = 'Gemma IA activo';
    } else if (_chatService.gemmaInitializing || _chatService.isDownloading) {
      statusColor = t.warning;
      statusLabel = _chatService.isDownloading
          ? 'Descargando Gemma IA...'
          : 'Cargando motor Gemma...';
    } else if (_chatService.isCheckingDeviceSpecs) {
      statusColor = t.accent;
      statusLabel = 'Verificando dispositivo...';
    } else {
      statusColor = t.warning;
      statusLabel = 'Requiere configurar modelo';
    }

    return LiquidGlassSurface(
      margin: EdgeInsets.fromLTRB(
        isDiurno ? 12 : 10,
        isDiurno ? 8 : 6,
        isDiurno ? 12 : 10,
        4,
      ),
      padding: const EdgeInsets.fromLTRB(8, 8, 10, 10),
      borderRadius: BorderRadius.circular(isDiurno ? 24 : 18),
      blurSigma: 22.0,
      fallbackColor: t.cardBackground,
      fallbackBorderColor: t.borderSubtle,
      fallbackBoxShadow: [
        BoxShadow(
          color: Colors.black.withValues(
            alpha: Theme.of(context).brightness == Brightness.light ? 0.06 : 0.22,
          ),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              SizedBox(
                width: 36,
                height: 36,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: t.textPrimary,
                    size: 18,
                  ),
                  tooltip: 'Volver',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Asistente Financiero',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: t.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            statusLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              color: t.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.46,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: _buildEngineSegmentedControl(context, isGemma),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            height: tabContainerHeight,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDiurno
                  ? t.darkBackground.withValues(alpha: 0.72)
                  : t.darkBackground,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: t.borderSubtle, width: 1),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: isDiurno ? t.cardBackground : t.buttonBackground,
                borderRadius: BorderRadius.circular(15),
                border: isDiurno
                    ? Border.all(color: Colors.white.withValues(alpha: 0.9))
                    : null,
                boxShadow: isDiurno
                    ? const [
                        BoxShadow(
                          color: Color(0x140B132B),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: isDiurno ? t.textPrimary : t.buttonForeground,
              unselectedLabelColor: t.textSecondary,
              labelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              unselectedLabelStyle: GoogleFonts.outfit(
                fontWeight: FontWeight.w500,
                fontSize: 12.5,
              ),
              tabs: [
                Tab(
                  height: tabContainerHeight - 6,
                  child: const Text(
                    'Consultas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tab(
                  height: tabContainerHeight - 6,
                  child: const Text(
                    'Perfil Cognitivo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              dividerColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineSegmentedControl(BuildContext context, bool isGemma) {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: isDiurno
            ? t.darkBackground.withValues(alpha: 0.75)
            : t.darkBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEngineTab(
            label: 'Simulador',
            isSelected: !isGemma,
            onTap: () => _chatService.setSimulatorMode(true),
          ),
          _buildEngineTab(
            label: 'Gemma IA',
            isSelected: isGemma,
            onTap: () => _chatService.setSimulatorMode(false),
          ),
        ],
      ),
    );
  }

  Widget _buildEngineTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: !isSelected
              ? Colors.transparent
              : isDiurno
                  ? t.cardBackground
                  : t.buttonBackground,
          borderRadius: BorderRadius.circular(15),
          boxShadow: isSelected && isDiurno
              ? const [
                  BoxShadow(
                    color: Color(0x140B132B),
                    blurRadius: 6,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.outfit(
            color: !isSelected
                ? t.textSecondary
                : isDiurno
                    ? t.accent
                    : t.buttonForeground,
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final isGemma = !_chatService.useLocalSimulator;
    final showEngineBanner = isGemma && !_chatService.gemmaInitialized;
    final messages = _chatService.messages;
    final bottomClearance = MoneoLayoutMetrics.floatingComposerClearance(context);

    return Stack(
      children: [
        Positioned.fill(
          child: messages.isEmpty
              ? _buildEmptyChat(includeEngineBanner: showEngineBanner)
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(14, 12, 14, bottomClearance),
                  itemCount:
                      messages.length + (showEngineBanner ? 1 : 0) + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    var offsetIndex = index;
                    if (showEngineBanner) {
                      if (offsetIndex == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildEngineStatusBanner(),
                        );
                      }
                      offsetIndex -= 1;
                    }
                    if (_isLoading && offsetIndex == messages.length) {
                      return _buildTypingIndicator();
                    }
                    return RepaintBoundary(
                      child: _buildChatBubble(
                        messages[offsetIndex],
                        messageIndex: offsetIndex,
                      ),
                    );
                  },
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildInputBar(),
        ),
      ],
    );
  }

  Widget _buildEngineStatusBanner() {
    final t = context.appTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_chatService.gemmaInitializing || _chatService.isDownloading) ...[
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _chatService.isDownloading
                        ? 'Descargando modelo Gemma AI (${(_chatService.downloadProgress * 100).clamp(0, 100).toStringAsFixed(0)}%)...'
                        : 'Cargando motor de IA...',
                    style: GoogleFonts.outfit(
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (_chatService.isDownloading) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _chatService.downloadProgress > 0
                      ? _chatService.downloadProgress
                      : null,
                  minHeight: 5,
                  backgroundColor: t.darkBackground,
                  valueColor: AlwaysStoppedAnimation<Color>(t.accent),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Este proceso puede tomar varios minutos según tu conexión. El modelo se guarda para usos futuros.',
              style: GoogleFonts.outfit(color: t.textHint, fontSize: 10.5),
            ),
          ] else if (_chatService.isCheckingDeviceSpecs) ...[
            Row(
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: t.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Verificando compatibilidad del dispositivo...',
                    style: GoogleFonts.outfit(color: t.textPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
          ] else if (!kIsWeb &&
              _chatService.gemmaError != null &&
              _chatService.gemmaError!.contains('Modelo no descargado')) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: t.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _chatService.gemmaError!,
                    style: GoogleFonts.outfit(
                      color: t.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildModelUrlSetup(),
          ] else if (!kIsWeb &&
              _chatService.gemmaError != null &&
              (_chatService.gemmaError!.contains('URL') ||
                  _chatService.gemmaError!.contains('INCOMPATIBLE'))) ...[
            _buildModelUrlSetup(),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, color: t.error, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _chatService.gemmaError != null
                        ? 'Error al inicializar Gemma IA:\n${_chatService.gemmaError}'
                        : !kIsWeb
                            ? 'Configura la URL de descarga del modelo para continuar.'
                            : 'Error: No se encontró el modelo gemma.litertlm.',
                    style: GoogleFonts.outfit(color: t.error, fontSize: 12),
                  ),
                ),
              ],
            ),
            if (!kIsWeb) ...[
              const SizedBox(height: 10),
              _buildModelUrlSetup(),
            ],
          ],
        ],
      ),
    );
  }

  /// Widget para configurar la URL del modelo en Android/iOS.
  Widget _buildModelUrlSetup() {
    final t = context.appTheme;
    final urlController = _modelUrlController;
    final cap = _chatService.deviceCapability;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (cap != null && !cap.canRunModel) ...[
          _buildIncompatibilityBanner(cap),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Icon(Icons.download_rounded, color: t.accent, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cap != null && !cap.canRunModel
                    ? 'Prueba con un modelo más ligero'
                    : 'Configura la descarga del modelo Gemma AI',
                style: GoogleFonts.outfit(
                  color: t.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'El modelo por defecto (Gemma 4 E2B) se descarga una sola vez y se guarda en tu dispositivo. '
          'Puedes descargarlo directamente o cambiar la URL por otro archivo .litertlm:',
          style: GoogleFonts.outfit(color: t.textHint, fontSize: 10.5),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: urlController,
                style: GoogleFonts.outfit(color: t.textPrimary, fontSize: 11.5),
                decoration: InputDecoration(
                  hintText: 'https://ejemplo.com/gemma.litertlm',
                  hintStyle: GoogleFonts.outfit(color: t.textHint, fontSize: 11),
                  filled: true,
                  fillColor: t.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: t.accent, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty && url.startsWith('https://')) {
                  _chatService.setModelUrl(url);
                  _showFeedbackSnackBar('Iniciando descarga del modelo...');
                } else {
                  _showFeedbackSnackBar(
                    'Por favor ingresa una URL válida (https://...)',
                    isError: true,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: t.buttonBackground,
                foregroundColor: t.buttonForeground,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Descargar',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              urlController.text = AiChatService.defaultModelUrl;
            },
            icon: const Icon(Icons.restore_rounded, size: 14),
            label: Text(
              'Restaurar modelo por defecto',
              style: GoogleFonts.outfit(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 28),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: t.accent, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mientras tanto, el Simulador Financiero está completamente funcional '
                  'y puede responder todas tus consultas financieras sin necesidad del modelo de IA.',
                  style: GoogleFonts.outfit(
                    color: t.textSecondary,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncompatibilityBanner(DeviceCapabilityResult cap) {
    final t = context.appTheme;
    final bool onlyAvailRamLow = cap.hasEnoughStorage &&
        cap.hasEnoughRAM &&
        cap.hasCompatProcessor &&
        !cap.hasEnoughAvailableRAM;
    final String availRamValue = cap.availRAMGB != null
        ? '${cap.availRAMGB!.toStringAsFixed(1)} GB${cap.lowMemory ? ' (memoria baja)' : ''}'
        : (cap.lowMemory ? 'memoria baja' : 'desconocida');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: t.warning, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  onlyAvailRamLow
                      ? 'RAM disponible insuficiente en este momento'
                      : 'Tu dispositivo no tiene los recursos suficientes',
                  style: GoogleFonts.outfit(
                    color: t.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _specRow(
            'Almacenamiento libre',
            '${cap.freeStorageGB.toStringAsFixed(1)} GB',
            cap.hasEnoughStorage,
            '≥ 3.5 GB',
          ),
          _specRow(
            'RAM total',
            cap.totalRAMGB != null
                ? '${cap.totalRAMGB!.toStringAsFixed(1)} GB'
                : 'desconocida',
            cap.hasEnoughRAM,
            '≥ 4 GB',
          ),
          _specRow(
            'RAM disponible',
            availRamValue,
            cap.hasEnoughAvailableRAM,
            '≥ 2.0 GB',
          ),
          _specRow(
            'Procesador',
            cap.isArm64 ? 'ARM64' : 'No ARM64',
            cap.hasCompatProcessor,
            'ARM64',
          ),
          const SizedBox(height: 6),
          Text(
            onlyAvailRamLow
                ? 'Cierra aplicaciones en segundo plano para liberar RAM y reintenta, o usa la URL de un modelo más ligero.'
                : 'Aun así, puedes intentarlo ingresando la URL de un modelo más ligero abajo.',
            style: GoogleFonts.outfit(color: t.textHint, fontSize: 10),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _chatService.isCheckingDeviceSpecs
                  ? null
                  : () => _chatService.recheckDeviceCapability(),
              icon: const Icon(Icons.refresh_rounded, size: 15),
              label: Text(
                'Reintentar verificación',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(String label, String value, bool ok, String req) {
    final t = context.appTheme;
    final color = ok ? t.success : t.error;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '$label: $value  (mín. $req)',
              style: GoogleFonts.outfit(color: color, fontSize: 10.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat({required bool includeEngineBanner}) {
    final t = context.appTheme;
    final sampleAmount = CurrencyHelper.format(700);
    final bottomClearance = MoneoLayoutMetrics.floatingComposerClearance(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 340;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            compact ? 10 : 16,
            16,
            bottomClearance,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (includeEngineBanner) ...[
                _buildEngineStatusBanner(),
                const SizedBox(height: 14),
              ],
              _buildEmptyChatDashboard(),
              SizedBox(height: compact ? 14 : 20),
              Text(
                'Preguntas Recomendadas',
                style: GoogleFonts.outfit(
                  color: t.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildQuerySuggestion(
                title: '¿Debería comprar algo?',
                subtitle: 'ej: ¿Puedo comprar algo de $sampleAmount sin afectar mis metas?',
                icon: Icons.shopping_bag_outlined,
                text: '¿Debería comprar algo por $sampleAmount?',
              ),
              _buildQuerySuggestion(
                title: 'Presupuesto y Ahorros',
                subtitle: 'Analiza tus gastos, metas y tasa de ahorro del mes',
                icon: Icons.analytics_outlined,
                text: '¿Cómo va mi presupuesto y ahorro mensual?',
              ),
              _buildQuerySuggestion(
                title: 'Mis Cuentas y Saldos',
                subtitle: 'Consulta el dinero acumulado en todas tus cuentas',
                icon: Icons.account_balance_wallet_outlined,
                text: '¿Cuáles son mis cuentas y saldos?',
              ),
            ],
          ),
        );
      },
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    final t = context.appTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: t.secondaryCardBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: t.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: GoogleFonts.outfit(
                color: t.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChatDashboard() {
    final t = context.appTheme;
    final balance = CurrencyHelper.format(_asDouble(_financialState?['availableBalance']));
    final income = CurrencyHelper.format(_asDouble(_financialState?['monthlyIncome']));
    final expenses = CurrencyHelper.format(_asDouble(_financialState?['monthlyExpenses']));

    final ratioStatus = _chatService.ratioStatus;
    final (Color healthColor, IconData healthIcon, String healthText) =
        switch (ratioStatus) {
      'excellent' => (
          t.success,
          Icons.check_circle_outline_rounded,
          'Salud Financiera Excelente. Buen margen para ahorrar e invertir.',
        ),
      'moderate' => (
          t.warning,
          Icons.info_outline_rounded,
          'Ahorro moderado. Se sugiere vigilar los gastos hormiga.',
        ),
      'deficit' => (
          t.error,
          Icons.warning_amber_rounded,
          'Déficit Financiero. Estás gastando más de lo que ingresas.',
        ),
      _ => (
          t.accent,
          Icons.insights_rounded,
          'Ingresa transacciones para evaluar tu salud financiera.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: t.accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Resumen Financiero para IA',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: t.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final screenWidth = MediaQuery.sizeOf(context).width;
              final scaledFont = MediaQuery.textScalerOf(context).scale(14);
              final isNarrowOrScaled = screenWidth < 360 ||
                  scaledFont > 16.8 ||
                  constraints.maxWidth < 280;
              final isVeryLargeScale =
                  scaledFont > 21.0 || constraints.maxWidth < 220;

              final availableCard = _buildStatCard(
                'Disponible',
                balance,
                Icons.account_balance_wallet_rounded,
                t.accent,
              );
              final incomeCard = _buildStatCard(
                'Ingresos Mes',
                income,
                Icons.trending_up_rounded,
                t.income,
              );
              final expenseCard = _buildStatCard(
                'Gastos Mes',
                expenses,
                Icons.trending_down_rounded,
                t.expense,
              );

              if (!isNarrowOrScaled) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: availableCard),
                      const SizedBox(width: 8),
                      Expanded(child: incomeCard),
                      const SizedBox(width: 8),
                      Expanded(child: expenseCard),
                    ],
                  ),
                );
              }

              final fullWidth = constraints.maxWidth;
              final halfWidth =
                  isVeryLargeScale ? fullWidth : (fullWidth - 8) / 2;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(width: fullWidth, child: availableCard),
                  SizedBox(width: halfWidth, child: incomeCard),
                  SizedBox(width: halfWidth, child: expenseCard),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: healthColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: healthColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(healthIcon, color: healthColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    healthText,
                    style: GoogleFonts.outfit(
                      color: t.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuerySuggestion({
    required String title,
    required String subtitle,
    required IconData icon,
    required String text,
  }) {
    final t = context.appTheme;
    return MoneoPressableScale(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: t.cardBackground,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              _messageController.text = text;
              _onInputChanged();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: t.accent, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: t.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: t.textSecondary,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: t.textHint,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message, {int? messageIndex}) {
    final t = context.appTheme;
    final isUser = message.role == 'user';
    final hasSuggestions = !isUser &&
        message.categorySuggestions != null &&
        message.categorySuggestions!.isNotEmpty;
    final hasTxSuggestions = !isUser &&
        message.transactionSuggestions != null &&
        message.transactionSuggestions!.isNotEmpty;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = isUser
        ? math.min(screenWidth * 0.80, 520.0)
        : math.min(screenWidth * 0.84, 560.0);
    final timeStr = DateFormat('HH:mm').format(message.timestamp);
    final minContentWidth = MediaQuery.textScalerOf(context).scale(40.0);

    final Color userTextColor = t.buttonForeground;
    final Color aiBodyTextColor = t.textPrimary;
    final BorderRadius bubbleRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isUser ? 18 : 6),
      bottomRight: Radius.circular(isUser ? 6 : 18),
    );

    final Widget messageBody = (isUser ||
            !RegExp(r'[*_`#\[\]\n-]').hasMatch(message.content))
        ? Text(
            message.content,
            style: GoogleFonts.outfit(
              color: isUser ? userTextColor : aiBodyTextColor,
              fontSize: 14.5,
              height: isUser ? 1.46 : 1.52,
            ),
          )
        : MarkdownBody(
            data: message.content,
            fitContent: true,
            shrinkWrap: true,
            styleSheet: _buildMarkdownStyle(
              isUser: isUser,
              userTextColor: userTextColor,
              aiBodyTextColor: aiBodyTextColor,
              t: t,
            ),
          );

    final bubbleWidget = Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: isUser ? 11 : 12,
          ),
          decoration: BoxDecoration(
            color: isUser ? t.buttonBackground : t.cardBackground,
            borderRadius: bubbleRadius,
            border: isUser
                ? null
                : Border.all(color: t.borderSubtle, width: 1.0),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(minWidth: minContentWidth),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: messageBody,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                timeStr,
                style: GoogleFonts.outfit(
                  color: isUser
                      ? userTextColor.withValues(alpha: 0.78)
                      : t.textHint,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (hasSuggestions || hasTxSuggestions) {
      final msgIdx = messageIndex ?? _chatService.messages.indexOf(message);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          bubbleWidget,
          if (hasSuggestions)
            _buildCategorySuggestionsList(message, msgIdx),
          if (hasTxSuggestions)
            _buildTransactionSuggestionsList(message, msgIdx),
        ],
      );
    }
    return bubbleWidget;
  }

  MarkdownStyleSheet _buildMarkdownStyle({
    required bool isUser,
    required Color userTextColor,
    required Color aiBodyTextColor,
    required AppTheme t,
  }) {
    final baseColor = isUser ? userTextColor : aiBodyTextColor;
    final strongColor = isUser ? userTextColor : t.accent;
    final codeBg = isUser
        ? t.buttonForeground.withValues(alpha: 0.14)
        : t.darkBackground;

    return MarkdownStyleSheet(
      p: GoogleFonts.outfit(
        color: baseColor,
        fontSize: 14.5,
        height: 1.52,
      ),
      strong: GoogleFonts.outfit(
        color: strongColor,
        fontWeight: FontWeight.bold,
        fontSize: 14.5,
      ),
      listBullet: GoogleFonts.outfit(
        color: strongColor,
        fontSize: 14.5,
      ),
      h1: GoogleFonts.outfit(
        color: strongColor,
        fontWeight: FontWeight.bold,
        fontSize: 17.5,
        height: 1.38,
      ),
      h2: GoogleFonts.outfit(
        color: strongColor,
        fontWeight: FontWeight.bold,
        fontSize: 16,
        height: 1.38,
      ),
      h3: GoogleFonts.outfit(
        color: baseColor,
        fontWeight: FontWeight.bold,
        fontSize: 15,
        height: 1.4,
      ),
      blockquote: GoogleFonts.outfit(
        color: isUser ? userTextColor.withValues(alpha: 0.88) : t.textSecondary,
        fontSize: 13.5,
        height: 1.45,
      ),
      blockquoteDecoration: BoxDecoration(
        color: isUser
            ? t.buttonForeground.withValues(alpha: 0.12)
            : t.darkBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: strongColor,
            width: 3,
          ),
        ),
      ),
      blockquotePadding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      code: GoogleFonts.jetBrainsMono(
        color: strongColor,
        backgroundColor: codeBg,
        fontSize: 12.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: codeBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isUser ? userTextColor.withValues(alpha: 0.22) : t.borderSubtle,
        ),
      ),
      codeblockPadding: const EdgeInsets.all(10),
    );
  }

  Widget _buildSuggestionShell({
    required Widget child,
    required double width,
  }) {
    final t = context.appTheme;
    return Container(
      constraints: BoxConstraints(
        minWidth: width,
        maxWidth: width,
        minHeight: 152,
      ),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.borderSubtle, width: 1),
      ),
      child: child,
    );
  }

  Widget _buildSuggestionTypePill(String type, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
      ),
      child: Text(
        type == 'Income' ? 'INGRESO' : 'GASTO',
        style: GoogleFonts.outfit(
          color: accentColor,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSuggestionActionBar({
    required VoidCallback onDiscard,
    required VoidCallback onEdit,
    required VoidCallback onSave,
  }) {
    final t = context.appTheme;
    final isLargeText = MediaQuery.textScalerOf(context).scale(11.5) > 15.0;

    final discardButton = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDiscard,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Text(
            'Descartar',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: t.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );

    final editButton = Tooltip(
      message: 'Editar',
      child: Material(
        color: t.darkBackground,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.borderSubtle),
            ),
            child: Icon(
              Icons.edit_outlined,
              color: t.textSecondary,
              size: 15,
            ),
          ),
        ),
      ),
    );

    final saveButton = MoneoPressableScale(
      child: Material(
        color: t.buttonBackground,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onSave,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              'Guardar',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                color: t.buttonForeground,
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.borderSubtle)),
      ),
      child: isLargeText
          ? Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                discardButton,
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    editButton,
                    const SizedBox(width: 6),
                    saveButton,
                  ],
                ),
              ],
            )
          : Row(
              children: [
                discardButton,
                const Spacer(),
                editButton,
                const SizedBox(width: 6),
                saveButton,
              ],
            ),
    );
  }

  Widget _buildCategorySuggestionsList(ChatMessage message, int messageIndex) {
    final t = context.appTheme;
    final suggestions = message.categorySuggestions!;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < suggestions.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Builder(
                  builder: (context) {
                    final sug = suggestions[index];
                    final String name = sug['name'] ?? '';
                    final String type = sug['type'] ?? 'Expenses';
                    final int iconCode =
                        sug['icon'] ?? Icons.category.codePoint;
                    final int colorValue = sug['color'] ?? t.accent.toARGB32();

                    final iconData = AppIcons.getIcon(iconCode);
                    final categoryColor =
                        AppColors.getReadableColor(Color(colorValue), context);
                    final typeColor = type == 'Income' ? t.income : t.expense;

                    return _buildSuggestionShell(
                      width: 224,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: categoryColor.withValues(
                                          alpha: 0.14),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: categoryColor,
                                      size: 17,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildSuggestionTypePill(type, typeColor),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: t.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSuggestionActionBar(
                            onDiscard: () async {
                              await _chatService.removeCategorySuggestion(
                                messageIndex,
                                name,
                              );
                            },
                            onEdit: () {
                              _showEditSuggestedCategoryDialog(
                                messageIndex: messageIndex,
                                type: type,
                                name: name,
                                iconCode: iconCode,
                                colorValue: colorValue,
                              );
                            },
                            onSave: () async {
                              await _chatService.acceptCategorySuggestion(
                                messageIndex,
                                sug,
                              );
                              if (!mounted) return;
                              _showFeedbackSnackBar(
                                'Categoría "$name" guardada exitosamente.',
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionSuggestionsList(
      ChatMessage message, int messageIndex) {
    final t = context.appTheme;
    final suggestions = message.transactionSuggestions!;

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < suggestions.length; index++) ...[
                if (index > 0) const SizedBox(width: 10),
                Builder(
                  builder: (context) {
                    final tx = suggestions[index];
                    final String type = tx['type'] ?? 'Expenses';
                    final double amount = _asDouble(tx['amount']);
                    final String category = tx['category'] ?? 'Otros';
                    final String detail = tx['detail'] ?? '';
                    final String dateStr = tx['date'] ?? '';
                    final String account = tx['account'] ?? 'Efectivo';

                    final accentColor =
                        type == 'Income' ? t.income : t.expense;
                    final displayTitle =
                        detail.trim().isNotEmpty ? detail : category;

                    return _buildSuggestionShell(
                      width: 242,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  _buildSuggestionTypePill(type, accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerRight,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          CurrencyHelper.format(amount),
                                          maxLines: 1,
                                          style: GoogleFonts.outfit(
                                            color: t.textPrimary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                displayTitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: t.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '$category • $account',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  color: t.textSecondary,
                                  fontSize: 11.5,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildSuggestionActionBar(
                            onDiscard: () async {
                              await _chatService.removeTransactionSuggestion(
                                messageIndex,
                                detail,
                              );
                            },
                            onEdit: () {
                              _showEditSuggestedTransactionDialog(
                                messageIndex: messageIndex,
                                type: type,
                                detail: detail,
                                amount: amount,
                                category: category,
                                dateStr: dateStr,
                                account: account,
                              );
                            },
                            onSave: () async {
                              await _chatService.acceptTransactionSuggestion(
                                messageIndex,
                                tx,
                              );
                              if (!mounted) return;
                              _showFeedbackSnackBar(
                                'Transacción registrada exitosamente.',
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showEditSuggestedCategoryDialog({
    required int messageIndex,
    required String type,
    required String name,
    required int iconCode,
    required int colorValue,
  }) {
    final nameController = TextEditingController(text: name);
    var selectedIcon = AppIcons.getIcon(iconCode);
    var selectedColor = Color(colorValue);
    final t = context.appTheme;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Categoría Sugerida',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, animation, _, __) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  final readableSelected =
                      AppColors.getReadableColor(selectedColor, context);
                  return Container(
                    width: double.infinity,
                    constraints:
                        const BoxConstraints(maxWidth: 400, maxHeight: 560),
                    decoration: BoxDecoration(
                      color: t.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: readableSelected.withValues(alpha: 0.08),
                            border: Border(
                              bottom: BorderSide(color: t.borderSubtle),
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: selectedColor,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  selectedIcon,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Editar Sugerencia',
                                      style: GoogleFonts.outfit(
                                        color: t.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      type == 'Income'
                                          ? 'Categoría de Ingreso'
                                          : 'Categoría de Egreso',
                                      style: GoogleFonts.outfit(
                                        color: t.textSecondary,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Nombre de Categoría',
                                  style: GoogleFonts.outfit(
                                    color: t.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: nameController,
                                  maxLength: 25,
                                  style: GoogleFonts.outfit(
                                    color: t.textPrimary,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ej. Supermercado, Salario...',
                                    hintStyle: GoogleFonts.outfit(
                                      color: t.textHint,
                                    ),
                                    filled: true,
                                    fillColor: t.darkBackground,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide:
                                          BorderSide(color: t.borderSubtle),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide:
                                          BorderSide(color: t.borderSubtle),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(14),
                                      borderSide: BorderSide(
                                        color: readableSelected,
                                        width: 1.5,
                                      ),
                                    ),
                                    counterText: '',
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Color distintivo',
                                  style: GoogleFonts.outfit(
                                    color: t.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 48,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _availableColors.length,
                                    itemBuilder: (context, index) {
                                      final color = _availableColors[index];
                                      final isSelected =
                                          color.toARGB32() == selectedColor.toARGB32();
                                      return GestureDetector(
                                        onTap: () {
                                          setDialogState(() {
                                            selectedColor = color;
                                          });
                                        },
                                        child: Container(
                                          width: 38,
                                          margin: const EdgeInsets.only(
                                            right: 10,
                                            top: 4,
                                            bottom: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: isSelected
                                                ? Border.all(
                                                    color: t.textPrimary,
                                                    width: 2.5,
                                                  )
                                                : null,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Ícono representativo',
                                  style: GoogleFonts.outfit(
                                    color: t.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                  ),
                                  itemCount: _availableIcons.length,
                                  itemBuilder: (context, index) {
                                    final icon = _availableIcons[index];
                                    final isSelected =
                                        icon.codePoint == selectedIcon.codePoint;
                                    return GestureDetector(
                                      onTap: () {
                                        setDialogState(() {
                                          selectedIcon = icon;
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? readableSelected.withValues(alpha: 0.16)
                                              : t.darkBackground,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: isSelected
                                                ? readableSelected
                                                : t.borderSubtle,
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Icon(
                                          icon,
                                          color: isSelected
                                              ? readableSelected
                                              : t.textSecondary,
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: t.borderSubtle),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: t.textSecondary,
                                    side: BorderSide(color: t.borderVisible),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: t.buttonBackground,
                                    foregroundColor: t.buttonForeground,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 13),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final enteredName =
                                        nameController.text.trim();
                                    if (enteredName.isEmpty) {
                                      _showFeedbackSnackBar(
                                        'Por favor, ingresa un nombre para la categoría.',
                                        isError: true,
                                      );
                                      return;
                                    }

                                    await CategoryService
                                        .addCategoryWithMetadata(
                                      type,
                                      enteredName,
                                      selectedIcon.codePoint,
                                      selectedColor.toARGB32(),
                                    );
                                    await _chatService.removeCategorySuggestion(
                                        messageIndex, name);

                                    if (dialogCtx.mounted) {
                                      Navigator.pop(dialogCtx);
                                    }
                                    if (!mounted) return;
                                    _showFeedbackSnackBar(
                                      'Categoría "$enteredName" guardada exitosamente.',
                                    );
                                  },
                                  child: Text(
                                    'Guardar',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
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
        );
      },
    );
  }

  void _showEditSuggestedTransactionDialog({
    required int messageIndex,
    required String type,
    required String detail,
    required double amount,
    required String category,
    required String dateStr,
    required String account,
  }) async {
    final categories = await CategoryService.getCategoriesWithMetadata(type);
    final accounts = _financialState != null && _financialState!['accounts'] != null
        ? List<Map<String, dynamic>>.from(_financialState!['accounts'])
        : <Map<String, dynamic>>[];

    final detailController = TextEditingController(text: detail);
    final amountController = TextEditingController(
      text: CurrencyHelper.format(amount, showSymbol: false),
    );

    var selectedDate = DateTime.tryParse(dateStr) ?? DateTime.now();
    var selectedCategory = category;
    var selectedAccount = account;

    if (accounts.isNotEmpty &&
        !accounts.any((a) => a['title'] == selectedAccount)) {
      selectedAccount = accounts.first['title'];
    }
    if (categories.isNotEmpty &&
        !categories.any((c) => c['text'] == selectedCategory)) {
      selectedCategory = categories.first['text'];
    }

    if (!mounted) return;
    final t = context.appTheme;
    final accentColor = type == 'Income' ? t.income : t.expense;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Editar Transacción Sugerida',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (dialogCtx, animation, _, __) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

        return ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1.0).animate(curved),
          child: FadeTransition(
            opacity: animation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: StatefulBuilder(
                builder: (context, setDialogState) {
                  return Container(
                    width: double.infinity,
                    constraints:
                        const BoxConstraints(maxWidth: 400, maxHeight: 600),
                    decoration: BoxDecoration(
                      color: t.cardBackground,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: t.borderSubtle),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.08),
                            border: Border(
                              bottom: BorderSide(color: t.borderSubtle),
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.14),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: accentColor.withValues(alpha: 0.35),
                                    width: 1.4,
                                  ),
                                ),
                                child: Icon(
                                  type == 'Income'
                                      ? Icons.trending_up_rounded
                                      : Icons.trending_down_rounded,
                                  color: accentColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Editar Registro',
                                      style: GoogleFonts.outfit(
                                        color: t.textPrimary,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      type == 'Income'
                                          ? 'Sugerencia de Ingreso'
                                          : 'Sugerencia de Gasto',
                                      style: GoogleFonts.outfit(
                                        color: t.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Descripción / Detalle',
                                  style: GoogleFonts.outfit(
                                    color: t.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: detailController,
                                  maxLength: 35,
                                  style: GoogleFonts.outfit(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Ej. Almuerzo con amigos',
                                    hintStyle: GoogleFonts.outfit(
                                      color: t.textHint,
                                    ),
                                    filled: true,
                                    fillColor: t.darkBackground,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: t.borderSubtle),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: t.borderSubtle),
                                    ),
                                    counterText: '',
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Monto',
                                  style: GoogleFonts.outfit(
                                    color: t.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: amountController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    ThousandsSeparatorInputFormatter(),
                                  ],
                                  style: GoogleFonts.outfit(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    prefixText: '${CurrencyHelper.currencySymbol} ',
                                    prefixStyle: GoogleFonts.outfit(
                                      color: accentColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    filled: true,
                                    fillColor: t.darkBackground,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 10,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: t.borderSubtle),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide:
                                          BorderSide(color: t.borderSubtle),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Cuenta',
                                            style: GoogleFonts.outfit(
                                              color: t.textSecondary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: t.darkBackground,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: t.borderSubtle),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: accounts.any((a) =>
                                                        a['title'] ==
                                                        selectedAccount)
                                                    ? selectedAccount
                                                    : null,
                                                dropdownColor: t.cardBackground,
                                                style: GoogleFonts.outfit(
                                                  color: t.textPrimary,
                                                  fontSize: 13,
                                                ),
                                                isExpanded: true,
                                                items: accounts.map((acc) {
                                                  return DropdownMenuItem<String>(
                                                    value: acc['title'],
                                                    child: Text(
                                                      acc['title'],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setDialogState(() {
                                                      selectedAccount = val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Categoría',
                                            style: GoogleFonts.outfit(
                                              color: t.textSecondary,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: t.darkBackground,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: t.borderSubtle),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: categories.any((c) =>
                                                        c['text'] ==
                                                        selectedCategory)
                                                    ? selectedCategory
                                                    : null,
                                                dropdownColor: t.cardBackground,
                                                style: GoogleFonts.outfit(
                                                  color: t.textPrimary,
                                                  fontSize: 13,
                                                ),
                                                isExpanded: true,
                                                items: categories.map((cat) {
                                                  return DropdownMenuItem<String>(
                                                    value: cat['text'],
                                                    child: Text(
                                                      cat['text'],
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setDialogState(() {
                                                      selectedCategory = val;
                                                    });
                                                  }
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  'Fecha',
                                  style: GoogleFonts.outfit(
                                    color: t.textSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: selectedDate,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2030),
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: isDark
                                                ? ColorScheme.dark(
                                                    primary: t.accent,
                                                    onPrimary: t.buttonForeground,
                                                    surface: t.cardBackground,
                                                    onSurface: t.textPrimary,
                                                  )
                                                : ColorScheme.light(
                                                    primary: t.accent,
                                                    onPrimary: t.buttonForeground,
                                                    surface: t.cardBackground,
                                                    onSurface: t.textPrimary,
                                                  ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        selectedDate = picked;
                                      });
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: t.darkBackground,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: t.borderSubtle),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(selectedDate),
                                          style: GoogleFonts.outfit(
                                            color: t.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          color: t.accent,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: t.borderSubtle),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: t.textSecondary,
                                    side: BorderSide(color: t.borderVisible),
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(dialogCtx),
                                  child: Text(
                                    'Cancelar',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: t.buttonBackground,
                                    foregroundColor: t.buttonForeground,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  onPressed: () async {
                                    final finalDetail =
                                        detailController.text.trim();
                                    final finalAmt = double.tryParse(
                                          CurrencyHelper.cleanAmountString(
                                            amountController.text.trim(),
                                          ),
                                        ) ??
                                        0.0;

                                    if (finalDetail.isEmpty) {
                                      _showFeedbackSnackBar(
                                        'Ingresa una descripción',
                                        isError: true,
                                      );
                                      return;
                                    }
                                    if (finalAmt <= 0) {
                                      _showFeedbackSnackBar(
                                        'Ingresa un monto válido',
                                        isError: true,
                                      );
                                      return;
                                    }

                                    var iconCode =
                                        Icons.receipt_long_rounded.codePoint;
                                    for (final cat in categories) {
                                      if (cat['text'] == selectedCategory) {
                                        iconCode = cat['icon'] ?? iconCode;
                                        break;
                                      }
                                    }

                                    final success =
                                        await TransactionService
                                            .processTransaction(
                                      type: type,
                                      amount: finalAmt,
                                      accountName: selectedAccount,
                                      isNewTransaction: true,
                                      recordInHive: false,
                                    );

                                    if (success) {
                                      final box = Hive.isBoxOpen('data')
                                          ? Hive.box<Add_data>('data')
                                          : await Hive.openBox<Add_data>(
                                              'data');
                                      final transaction = Add_data(
                                        type,
                                        finalAmt.toString(),
                                        selectedDate,
                                        finalDetail,
                                        selectedCategory,
                                        selectedAccount,
                                        iconCode,
                                        '1',
                                        true,
                                      );
                                      await box.add(transaction);
                                      await _chatService
                                          .removeTransactionSuggestion(
                                        messageIndex,
                                        detail,
                                      );

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      if (!mounted) return;
                                      _showFeedbackSnackBar(
                                        'Transacción guardada exitosamente.',
                                      );
                                    } else {
                                      if (!mounted) return;
                                      _showFeedbackSnackBar(
                                        'Error al procesar el saldo de la cuenta',
                                        isError: true,
                                      );
                                    }
                                  },
                                  child: Text(
                                    'Guardar',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
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
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: BouncingDotsIndicator(),
      ),
    );
  }

  Widget _buildInputBar() {
    final t = context.appTheme;
    final isDiurno = context.isDiurno;
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SafeArea(
      top: false,
      child: LiquidGlassSurface(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
        borderRadius: BorderRadius.circular(28),
        blurSigma: 22.0,
        fallbackColor: t.cardBackground,
        fallbackBorderColor:
            _isInputEmpty ? t.borderSubtle : t.accent.withValues(alpha: 0.65),
        fallbackBorderWidth: _isInputEmpty ? 1.0 : 1.3,
        fallbackBoxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isLight ? 0.08 : 0.26),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                key: const Key('ai_chat_input_field'),
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.outfit(
                  color: t.textPrimary,
                  fontSize: 14.5,
                ),
                decoration: InputDecoration(
                  hintText: 'Pregunta sobre tus finanzas...',
                  hintStyle: GoogleFonts.outfit(
                    color: isDiurno ? t.textSecondary : t.textHint,
                    fontSize: 14,
                  ),
                  filled: false,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              key: const Key('ai_chat_send_button'),
              onTap: (_isLoading || _chatService.isGenerating)
                  ? () => _chatService.cancelGeneration()
                  : _handleSend,
              child: MoneoPressableScale(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: (_isLoading || _chatService.isGenerating)
                        ? t.error
                        : _isInputEmpty
                            ? t.darkBackground
                            : (isDiurno ? t.accent : t.buttonBackground),
                    boxShadow: !_isInputEmpty && isDiurno
                        ? const [
                            BoxShadow(
                              color: Color(0x330062CC),
                              blurRadius: 10,
                              offset: Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    (_isLoading || _chatService.isGenerating)
                        ? Icons.stop_rounded
                        : Icons.arrow_upward_rounded,
                    color: (_isLoading || _chatService.isGenerating)
                        ? Colors.white
                        : _isInputEmpty
                            ? t.textHint
                            : t.buttonForeground,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final t = context.appTheme;
    final categoryExpenses = _chatService.getCategoryExpenses();
    final totalExpenses =
        categoryExpenses.values.fold(0.0, (sum, val) => sum + val);
    final bottomSafe = MediaQuery.viewPaddingOf(context).bottom;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 28 + bottomSafe),
      children: [
        _buildCognitiveOverviewSurface(),
        if (categoryExpenses.isNotEmpty) ...[
          const SizedBox(height: 20),
          _buildSectionHeading('Gastos por categoría · Mes actual'),
          const SizedBox(height: 8),
          _buildSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...categoryExpenses.entries.map((entry) {
                  final percent =
                      totalExpenses > 0 ? (entry.value / totalExpenses) : 0.0;
                  return _buildCategoryProgressBar(
                    entry.key,
                    entry.value,
                    percent,
                  );
                }),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _buildSectionHeading('Metas financieras'),
        const SizedBox(height: 8),
        _buildSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'El asistente priorizará estas metas al evaluar tus compras:',
                style: GoogleFonts.outfit(
                  color: t.textSecondary,
                  fontSize: 12.5,
                  height: 1.38,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _goalsController,
                maxLines: 2,
                style: GoogleFonts.outfit(color: t.textPrimary, fontSize: 13.5),
                decoration: InputDecoration(
                  hintText:
                      'Ej. Ahorrar para una laptop, reducir comidas fuera de casa...',
                  hintStyle: GoogleFonts.outfit(color: t.textHint, fontSize: 13),
                  filled: true,
                  fillColor: t.darkBackground,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: t.accent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: MoneoPressableScale(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.buttonBackground,
                      foregroundColor: t.buttonForeground,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: _saveGoals,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      'Guardar Metas',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: t.cardBackground,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.borderSubtle),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                leading: Icon(
                  Icons.description_outlined,
                  color: t.accent,
                  size: 20,
                ),
                title: Text(
                  'Reporte Analítico Detallado (Markdown)',
                  style: GoogleFonts.outfit(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                iconColor: t.accent,
                collapsedIconColor: t.textHint,
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  Divider(height: 12, color: t.borderSubtle),
                  const SizedBox(height: 8),
                  MarkdownBody(
                    data: _chatService.userNotes,
                    styleSheet: MarkdownStyleSheet(
                      p: GoogleFonts.outfit(
                        color: t.textSecondary,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      strong: GoogleFonts.outfit(
                        color: t.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      listBullet: GoogleFonts.outfit(
                        color: t.accent,
                        fontSize: 13,
                      ),
                      h3: GoogleFonts.outfit(
                        color: t.accent,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: t.error,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            label: Text(
              'Reiniciar Conversación y Memoria',
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  backgroundColor: t.cardBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(color: t.borderSubtle),
                  ),
                  title: Text(
                    '¿Reiniciar todo?',
                    style: GoogleFonts.outfit(
                      color: t.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  content: Text(
                    'Se borrará todo el historial del chat y el asistente comenzará de cero.',
                    style: GoogleFonts.outfit(color: t.textSecondary),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.outfit(
                          color: t.textSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        await _chatService.clearHistory();
                      },
                      child: Text(
                        'Sí, Reiniciar',
                        style: GoogleFonts.outfit(
                          color: t.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeading(String title) {
    final t = context.appTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: t.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.7,
        ),
      ),
    );
  }

  Widget _buildSectionCard({required Widget child}) {
    final t = context.appTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.borderSubtle),
      ),
      child: child,
    );
  }

  Widget _buildCognitiveOverviewSurface() {
    final t = context.appTheme;
    final status = _chatService.ratioStatus;
    final message = _chatService.ratioMessageText;

    final (Color color, IconData icon, String statusTitle) = switch (status) {
      'excellent' => (
          t.success,
          Icons.check_circle_outline_rounded,
          'Salud Financiera Óptima',
        ),
      'moderate' => (
          t.warning,
          Icons.info_outline_rounded,
          'Ahorro Moderado',
        ),
      'deficit' => (
          t.error,
          Icons.warning_amber_rounded,
          'Alerta de Déficit',
        ),
      _ => (
          t.accent,
          Icons.insights_rounded,
          'Sin Diagnóstico',
        ),
    };

    final topCat = _chatService.topCategory;
    final topCatAmt = CurrencyHelper.format(_chatService.topCategoryAmount);
    final maxExpItem = _chatService.maxExpenseItem;
    final maxExpAmt = CurrencyHelper.format(_chatService.maxExpense);
    final txCount = _chatService.expenseCount.toString();
    final savingsRatio = _chatService.savingsRatio.toStringAsFixed(1);

    final cells = [
      _buildMetricCell(
        title: 'Tasa de Ahorro',
        value: '$savingsRatio%',
        subtitle: 'De ingresos netos',
        icon: Icons.donut_large_rounded,
        color: t.accent,
      ),
      _buildMetricCell(
        title: 'Gasto Mayoritario',
        value: topCat.isEmpty ? 'Ninguna' : topCat,
        subtitle: '$topCatAmt este mes',
        icon: Icons.pie_chart_rounded,
        color: t.secondaryAccent,
      ),
      _buildMetricCell(
        title: 'Mayor Transacción',
        value: maxExpItem.isEmpty ? 'Ninguna' : maxExpItem,
        subtitle: '$maxExpAmt registrados',
        icon: Icons.trending_up_rounded,
        color: t.expense,
      ),
      _buildMetricCell(
        title: 'Total Transacciones',
        value: '$txCount egresos',
        subtitle: 'Historial analizado',
        icon: Icons.receipt_long_rounded,
        color: t.warning,
      ),
    ];

    final dividerColor = t.borderSubtle.withValues(alpha: 0.75);

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
            color: color.withValues(alpha: 0.06),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.14),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: GoogleFonts.outfit(
                          color: t.textPrimary,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.isEmpty
                            ? 'Analizando tus datos financieros en tiempo real.'
                            : message,
                        softWrap: true,
                        style: GoogleFonts.outfit(
                          color: t.textSecondary,
                          fontSize: 12.5,
                          height: 1.38,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          LayoutBuilder(
            builder: (context, constraints) {
              final useSingleColumn = constraints.maxWidth < 260 ||
                  MediaQuery.textScalerOf(context).scale(14) > 19.0;

              if (useSingleColumn) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < cells.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: dividerColor),
                      cells[i],
                    ],
                  ],
                );
              }

              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cells[0]),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: dividerColor,
                        ),
                        Expanded(child: cells[1]),
                      ],
                    ),
                  ),
                  Divider(height: 1, thickness: 1, color: dividerColor),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: cells[2]),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: dividerColor,
                        ),
                        Expanded(child: cells[3]),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCell({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final t = context.appTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.outfit(
                    color: t.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: t.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              height: 1.22,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: t.textHint,
              fontSize: 11.5,
              height: 1.3,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryProgressBar(
      String category, double amount, double percent) {
    final t = context.appTheme;
    final categoryColor = _getCategoryColor(category);
    final formattedAmount = CurrencyHelper.format(amount);
    final amountLabel = '$formattedAmount (${(percent * 100).toStringAsFixed(0)}%)';
    final isLargeText = MediaQuery.textScalerOf(context).scale(14) > 16.5;

    final categoryBadge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: categoryColor,
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            category,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.outfit(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );

    final amountText = Text(
      amountLabel,
      style: GoogleFonts.outfit(
        color: t.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLargeText) ...[
            categoryBadge,
            const SizedBox(height: 3),
            amountText,
          ] else
            Row(
              children: [
                Expanded(child: categoryBadge),
                const SizedBox(width: 10),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: amountText,
                  ),
                ),
              ],
            ),
          const SizedBox(height: 6),
          Container(
            height: 6,
            width: double.infinity,
            decoration: BoxDecoration(
              color: t.darkBackground,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: percent.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: categoryColor,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Indicador animado de escritura del asistente (3 puntos).
class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({super.key});

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.appTheme;
    final dot = Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.accent,
      ),
    );
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.cardBackground,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(6),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: t.borderSubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              child: dot,
              builder: (context, child) {
                final delay = index * 0.2;
                final wave = math.sin((_controller.value * 2 * math.pi) - delay);
                final offset = (wave * 4.0).clamp(-4.0, 0.0);
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: child,
                );
              },
            );
          }),
        ),
      ),
    );
  }
}
