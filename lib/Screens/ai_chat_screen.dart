import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gradient_borders/gradient_borders.dart';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:finazaap/services/ai_chat_service.dart';
import 'package:finazaap/themes/app_colors.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({Key? key}) : super(key: key);

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiChatService _chatService = AiChatService();
  bool _isLoading = false;
  bool _isInputEmpty = true;
  Map<String, dynamic>? _financialState;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _chatService.addListener(_onServiceUpdate);
    _messageController.addListener(_onInputChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _chatService.initialize();
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
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
      _loadFinancialState();
      _scrollToBottom();
    }
  }

  void _onInputChanged() {
    final text = _messageController.text.trim();
    if (mounted) {
      setState(() {
        _isInputEmpty = text.isEmpty;
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
    } catch (e) {
      // Omitir errores menores de base de datos en UI
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
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
    if (text.isNotEmpty) {
      await _chatService.updateUserGoals(text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Metas financieras actualizadas en memoria.',
            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.cardBackground,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'comida':
      case 'alimentos':
      case 'restaurantes':
        return const Color(0xFFFFB74D); // Naranja
      case 'transporte':
      case 'gasolina':
      case 'viajes':
        return const Color(0xFF64B5F6); // Azul
      case 'servicios':
      case 'luz':
      case 'agua':
      case 'internet':
        return const Color(0xFF81C784); // Verde
      case 'entretenimiento':
      case 'ocio':
      case 'cine':
      case 'suscripciones':
        return const Color(0xFFBA68C8); // Púrpura
      case 'compras':
      case 'ropa':
      case 'regalos':
        return const Color(0xFFF06292); // Rosa
      case 'salud':
      case 'medicina':
        return const Color(0xFF4DB6AC); // Turquesa
      case 'educación':
      case 'libros':
        return const Color(0xFFFFD54F); // Amarillo
      default:
        return AppColors.accent; // Cyan predeterminado
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryBackground,
      appBar: null,
      body: SafeArea(
        child: Column(
          children: [
            // 1. HEADER (Igual que en Home/Categorías)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(42, 49, 67, 1),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    left: 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 22),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  Text(
                    'Asistente Financiero',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. TABS ESTILO PREMIUM (Igual que en Categorías)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF52E2FF),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF52E2FF).withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 0),
                      ),
                    ],
                  ),
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: const Color.fromRGBO(31, 38, 57, 1),
                  unselectedLabelColor: Colors.white.withOpacity(0.5),
                  labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: const [
                    Tab(text: 'Consultas'),
                    Tab(text: 'Perfil Cognitivo'),
                  ],
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: MaterialStateProperty.all(Colors.transparent),
                ),
              ),
            ),

            // 3. VISTAS
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

  Widget _buildChatTab() {
    return Column(
      children: [
        _buildEngineSelector(),
        Expanded(
          child: _chatService.messages.isEmpty
              ? _buildEmptyChat()
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  itemCount: _chatService.messages.length,
                  itemBuilder: (context, index) {
                    final message = _chatService.messages[index];
                    return _buildChatBubble(message);
                  },
                ),
        ),
        if (_isLoading) _buildTypingIndicator(),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildEngineSelector() {
    final isGemma = !_chatService.useLocalSimulator;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: AppColors.accent.withOpacity(0.8), size: 18),
              const SizedBox(width: 8),
              Text(
                'Motor de Inteligencia:',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                padding: const EdgeInsets.all(2),
                child: Row(
                  children: [
                    _buildEngineTab('Simulador', !isGemma, () {
                      _chatService.setSimulatorMode(true);
                    }),
                    _buildEngineTab('Gemma IA', isGemma, () {
                      _chatService.setSimulatorMode(false);
                    }),
                  ],
                ),
              ),
            ],
          ),
          if (isGemma && !_chatService.gemmaInitialized) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBackground.withOpacity(0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_chatService.gemmaInitializing || _chatService.isDownloading) ...[
                    Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _chatService.isDownloading 
                                ? 'Descargando modelo Gemma AI (2.5 GB)...' 
                                : 'Cargando motor de IA...',
                            style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Este proceso puede tomar varios minutos según tu conexión. El modelo se guarda para usos futuros.',
                      style: GoogleFonts.outfit(color: AppColors.textHint, fontSize: 10),
                    ),
                  ] else if (!kIsWeb && _chatService.gemmaError != null && _chatService.gemmaError!.contains('URL')) ...[
                    // Android: Mostrar campo para ingresar la URL del modelo
                    _buildModelUrlSetup(),
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _chatService.gemmaError != null
                                ? 'Error al inicializar Gemma IA:\n${_chatService.gemmaError}'
                                : !kIsWeb 
                                    ? 'Configura la URL de descarga del modelo para continuar.'
                                    : 'Error: No se encontró el modelo gemma.litertlm.',
                            style: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
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
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildEngineTab(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: GoogleFonts.outfit(
            color: isSelected ? AppColors.darkBackground : AppColors.textSecondary,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Widget para configurar la URL del modelo en Android/iOS
  /// Aparece cuando el usuario activa Gemma IA pero no hay modelo instalado.
  Widget _buildModelUrlSetup() {
    final urlController = TextEditingController();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.download_rounded, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Configura la descarga del modelo Gemma AI',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'El modelo (2.5 GB) se descarga una sola vez y se guarda en tu dispositivo. '
          'Ingresa la URL de descarga directa del archivo .litertlm:',
          style: GoogleFonts.outfit(color: AppColors.textHint, fontSize: 10),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: urlController,
                style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'https://ejemplo.com/gemma.litertlm',
                  hintStyle: GoogleFonts.outfit(color: AppColors.textHint, fontSize: 11),
                  filled: true,
                  fillColor: AppColors.darkBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.borderSubtle),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  isDense: true,
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final url = urlController.text.trim();
                if (url.isNotEmpty && url.startsWith('http')) {
                  _chatService.setModelUrl(url);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Iniciando descarga del modelo...',
                        style: GoogleFonts.outfit(color: AppColors.textPrimary),
                      ),
                      backgroundColor: AppColors.cardBackground,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Por favor ingresa una URL válida (http...)',
                        style: GoogleFonts.outfit(color: AppColors.error),
                      ),
                      backgroundColor: AppColors.cardBackground,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.darkBackground,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                'Descargar',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.accent.withOpacity(0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Mientras tanto, el Simulador Financiero está completamente funcional '
                  'y puede responder todas tus consultas financieras sin necesidad del modelo de IA.',
                  style: GoogleFonts.outfit(color: AppColors.accent, fontSize: 9.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Dynamic Insight Dashboard
            _buildEmptyChatDashboard(),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Preguntas Recomendadas',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildQuerySuggestion(
              title: '¿Debería comprar algo?',
              subtitle: 'ej: ¿Debería comprar una laptop por 700 dólares?',
              icon: Icons.shopping_bag_outlined,
              text: '¿Debería comprar una laptop de 700 dólares?',
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
              icon: Icons.wallet_outlined,
              text: '¿Cuáles son mis cuentas y saldos?',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkBackground.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: AppColors.textHint,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyChatDashboard() {
    final balance = _financialState?['availableBalance']?.toStringAsFixed(2) ?? '0.00';
    final income = _financialState?['monthlyIncome']?.toStringAsFixed(2) ?? '0.00';
    final expenses = _financialState?['monthlyExpenses']?.toStringAsFixed(2) ?? '0.00';
    
    final ratioStatus = _chatService.ratioStatus;
    
    Color healthColor;
    IconData healthIcon;
    String healthText;
    
    switch (ratioStatus) {
      case 'excellent':
        healthColor = AppColors.success;
        healthIcon = Icons.check_circle_outline_rounded;
        healthText = 'Salud Financiera Excelente. Buen margen para ahorrar e invertir.';
        break;
      case 'moderate':
        healthColor = AppColors.warning;
        healthIcon = Icons.info_outline_rounded;
        healthText = 'Ahorro moderado. Se sugiere vigilar los gastos hormiga.';
        break;
      case 'deficit':
        healthColor = AppColors.error;
        healthIcon = Icons.warning_amber_rounded;
        healthText = 'Déficit Financiero. Estás gastando más de lo que ingresas.';
        break;
      default:
        healthColor = AppColors.accent;
        healthIcon = Icons.insights_rounded;
        healthText = 'Ingresa transacciones para evaluar tu salud financiera.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.4),
        borderRadius: BorderRadius.circular(24),
        border: const GradientBoxBorder(
          gradient: LinearGradient(
            colors: [
              AppColors.accent,
              Colors.transparent,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.1),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                'Insights de Inteligencia Artificial',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Saldo Disponible', '\$$balance', Icons.account_balance_wallet_rounded, AppColors.accent),
              const SizedBox(width: 8),
              _buildStatCard('Ingresos Mes', '\$$income', Icons.trending_up_rounded, AppColors.income),
              const SizedBox(width: 8),
              _buildStatCard('Gastos Mes', '\$$expenses', Icons.trending_down_rounded, AppColors.expense),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: healthColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: healthColor.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(healthIcon, color: healthColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    healthText,
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _messageController.text = text;
            _onInputChanged();
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textHint,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatBubble(ChatMessage message) {
    final isUser = message.role == 'user';
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1),
              ),
              child: CircleAvatar(
                backgroundColor: AppColors.cardBackground,
                radius: 13,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.accent,
                  size: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [
                          Color(0xFF3B82F6),
                          Color(0xFF1D4ED8),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: !isUser ? AppColors.cardBackground.withOpacity(0.7) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                border: !isUser 
                    ? const GradientBoxBorder(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF52E2FF),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        width: 1.0,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Stack(
                children: [
                  if (!isUser)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'AI',
                          style: GoogleFonts.outfit(
                            color: AppColors.accent,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: !isUser ? 6 : 0, right: !isUser ? 16 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MarkdownBody(
                          data: message.content,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              height: 1.45,
                            ),
                            strong: GoogleFonts.outfit(
                              color: isUser ? AppColors.textPrimary : AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            listBullet: GoogleFonts.outfit(
                              color: AppColors.accent,
                              fontSize: 14,
                            ),
                            h1: GoogleFonts.outfit(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              height: 1.5,
                            ),
                            h2: GoogleFonts.outfit(
                              color: AppColors.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              height: 1.4,
                            ),
                            h3: GoogleFonts.outfit(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            blockquote: GoogleFonts.outfit(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: AppColors.darkBackground.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(8),
                              border: const Border(
                                left: BorderSide(color: AppColors.accent, width: 3.5),
                              ),
                            ),
                            blockquotePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            code: GoogleFonts.jetBrainsMono(
                              color: AppColors.accent,
                              backgroundColor: AppColors.darkBackground,
                              fontSize: 12,
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: AppColors.darkBackground,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            codeblockPadding: const EdgeInsets.all(10),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Spacer(),
                            Text(
                              DateFormat('HH:mm').format(message.timestamp),
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 9,
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
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withOpacity(0.2), width: 1),
            ),
            child: CircleAvatar(
              backgroundColor: AppColors.cardBackground,
              radius: 12,
              child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 12),
            ),
          ),
          const SizedBox(width: 8),
          const BouncingDotsIndicator(),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, -3),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isInputEmpty ? AppColors.borderSubtle : AppColors.accent.withOpacity(0.4),
                  ),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Pregunta sobre tus finanzas...',
                    hintStyle: GoogleFonts.outfit(color: AppColors.textHint, fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _handleSend,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isInputEmpty ? AppColors.borderSubtle : AppColors.accent,
                  boxShadow: _isInputEmpty 
                      ? null 
                      : [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: _isInputEmpty ? AppColors.textHint : AppColors.darkBackground,
                  size: 20,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() {
    final categoryExpenses = _chatService.getCategoryExpenses();
    final double totalExpenses = categoryExpenses.values.fold(0.0, (sum, val) => sum + val);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Salud Financiera Banner Card
        _buildHealthBannerCard(),
        const SizedBox(height: 16),

        // Key stats metric dashboard
        _buildMetricsDashboard(),
        const SizedBox(height: 16),

        // Categories graph card
        if (categoryExpenses.isNotEmpty) ...[
          Card(
            color: AppColors.cardBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderSubtle),
            ),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondaryAccent.withOpacity(0.1),
                        ),
                        child: const Icon(Icons.pie_chart_outline_rounded, color: AppColors.secondaryAccent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Gastos por Categoría (Mes actual)',
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Colors.white10),
                  ...categoryExpenses.entries.map((entry) {
                    final percent = totalExpenses > 0 ? (entry.value / totalExpenses) : 0.0;
                    return _buildCategoryProgressBar(entry.key, entry.value, percent);
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Metas de Ahorro Card
        Card(
          color: AppColors.cardBackground,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: AppColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                      ),
                      child: const Icon(Icons.flag_rounded, color: Color(0xFF2ECC71), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Tus Metas Financieras',
                      style: GoogleFonts.outfit(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'El bot de IA evaluará la conveniencia de tus consumos basándose en estas metas:',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: TextField(
                    controller: _goalsController,
                    maxLines: 2,
                    style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Ej. Ahorrar para una laptop, reducir comidas fuera de casa...',
                      hintStyle: GoogleFonts.outfit(color: AppColors.textHint, fontSize: 13),
                      contentPadding: const EdgeInsets.all(12),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: AppColors.darkBackground,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(double.infinity, 42),
                  ),
                  onPressed: _saveGoals,
                  child: Text(
                    'Guardar Metas',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Reporte textual completo de aprendizaje (Acordeón desplegable)
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Card(
            color: AppColors.cardBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderSubtle),
            ),
            child: ExpansionTile(
              leading: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent.withOpacity(0.1),
                ),
                child: const Icon(Icons.description_outlined, color: AppColors.accent, size: 20),
              ),
              title: Text(
                'Reporte Analítico Detallado (Markdown)',
                style: GoogleFonts.outfit(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              iconColor: AppColors.accent,
              collapsedIconColor: AppColors.textHint,
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              children: [
                const Divider(height: 12, color: Colors.white10),
                const SizedBox(height: 8),
                MarkdownBody(
                  data: _chatService.userNotes,
                  styleSheet: MarkdownStyleSheet(
                    p: GoogleFonts.outfit(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    strong: GoogleFonts.outfit(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    listBullet: GoogleFonts.outfit(
                      color: AppColors.accent,
                      fontSize: 13,
                    ),
                    h3: GoogleFonts.outfit(
                      color: AppColors.accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Reset action button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.error),
            foregroundColor: AppColors.error,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            minimumSize: const Size(double.infinity, 46),
          ),
          icon: const Icon(Icons.delete_sweep_rounded, size: 18),
          label: Text('Reiniciar Conversación y Memoria', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: AppColors.cardBackground,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text('¿Reiniciar todo?', style: GoogleFonts.outfit(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                content: Text(
                  'Se borrará todo el historial del chat y el bot comenzará de cero.',
                  style: GoogleFonts.outfit(color: AppColors.textSecondary),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancelar', style: GoogleFonts.outfit(color: AppColors.textHint, fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _chatService.clearHistory();
                    },
                    child: Text('Sí, Reiniciar', style: GoogleFonts.outfit(color: AppColors.error, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHealthBannerCard() {
    final status = _chatService.ratioStatus;
    final message = _chatService.ratioMessageText;
    
    Color color;
    IconData icon;
    String statusTitle;
    
    switch (status) {
      case 'excellent':
        color = AppColors.success;
        icon = Icons.emoji_emotions_outlined;
        statusTitle = 'Salud Financiera Óptima';
        break;
      case 'moderate':
        color = AppColors.warning;
        icon = Icons.sentiment_satisfied_alt_outlined;
        statusTitle = 'Ahorro Moderado';
        break;
      case 'deficit':
        color = AppColors.error;
        icon = Icons.sentiment_very_dissatisfied_outlined;
        statusTitle = 'Alerta de Déficit';
        break;
      default:
        color = AppColors.accent;
        icon = Icons.hourglass_empty_rounded;
        statusTitle = 'Sin Diagnóstico';
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              icon,
              size: 90,
              color: color.withOpacity(0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(0.1),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: GoogleFonts.outfit(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.isEmpty ? 'Analizando tus datos en tiempo real.' : message,
                        style: GoogleFonts.outfit(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsDashboard() {
    final topCat = _chatService.topCategory;
    final topCatAmt = _chatService.topCategoryAmount.toStringAsFixed(2);
    final maxExpItem = _chatService.maxExpenseItem;
    final maxExpAmt = _chatService.maxExpense.toStringAsFixed(2);
    final txCount = _chatService.expenseCount.toString();
    final savingsRatio = _chatService.savingsRatio.toStringAsFixed(1);

    return Column(
      children: [
        Row(
          children: [
            _buildMetricCard(
              title: 'Tasa de Ahorro',
              value: '$savingsRatio%',
              subtitle: 'Porcentaje de ingresos netos',
              icon: Icons.donut_large_rounded,
              color: AppColors.accent,
            ),
            const SizedBox(width: 14),
            _buildMetricCard(
              title: 'Gasto Mayoritario',
              value: topCat.length > 12 ? '${topCat.substring(0, 10)}...' : topCat,
              subtitle: '\$$topCatAmt COP este mes',
              icon: Icons.pie_chart_rounded,
              color: AppColors.secondaryAccent,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _buildMetricCard(
              title: 'Mayor Transacción',
              value: maxExpItem.length > 12 ? '${maxExpItem.substring(0, 10)}...' : maxExpItem,
              subtitle: '\$$maxExpAmt COP registrados',
              icon: Icons.trending_up_rounded,
              color: AppColors.expense,
            ),
            const SizedBox(width: 14),
            _buildMetricCard(
              title: 'Total Transacciones',
              value: '$txCount egresos',
              subtitle: 'En tu historial registrado',
              icon: Icons.receipt_long_rounded,
              color: Colors.amber,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: AppColors.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(icon, color: color.withOpacity(0.8), size: 18),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.outfit(
                color: AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryProgressBar(String category, double amount, double percent) {
    final categoryColor = _getCategoryColor(category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: categoryColor,
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.4),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    category,
                    style: GoogleFonts.outfit(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${amount.toStringAsFixed(2)} USD (${(percent * 100).toStringAsFixed(0)}%)',
                style: GoogleFonts.outfit(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.darkBackground,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: percent.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      colors: [
                        categoryColor.withOpacity(0.6),
                        categoryColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: categoryColor.withOpacity(0.3),
                        blurRadius: 4,
                        spreadRadius: 1,
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
  }
}

// --- WIDGET AUXILIAR: INDICADOR DE ESCRITURA ANIMADO (3 PUNTOS REBOTANDO) ---
class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({Key? key}) : super(key: key);

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator> with SingleTickerProviderStateMixin {
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = index * 0.2;
              final wave = math.sin((_controller.value * 2 * math.pi) - delay);
              final offset = (wave * 4.0).clamp(-4.0, 0.0);
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                transform: Matrix4.translationValues(0, offset, 0),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.accent,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
