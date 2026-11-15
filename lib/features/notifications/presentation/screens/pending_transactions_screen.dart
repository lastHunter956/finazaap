import 'package:flutter/material.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/presentation/widgets/correction_dialog.dart';
import 'package:finazaap/features/notifications/presentation/widgets/pending_transaction_card.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

/// Pantalla principal de la bandeja de transacciones bancarias pendientes en Moneo.
///
/// Permite al usuario revisar de forma aislada las transacciones detectadas por
/// el pipeline de notificaciones, ejecutar aprobación en lote ("Aceptar todo"
/// restringido a alta confianza), corregir parámetros y descartar elementos.
class PendingTransactionsScreen extends StatefulWidget {
  final PendingTransactionsNotifier? notifier;
  final bool isDemoMode;

  const PendingTransactionsScreen({
    super.key,
    this.notifier,
    this.isDemoMode = false,
  });

  const PendingTransactionsScreen.demo({
    super.key,
    this.notifier,
  }) : isDemoMode = true;

  @override
  State<PendingTransactionsScreen> createState() =>
      _PendingTransactionsScreenState();
}

class _PendingTransactionsScreenState extends State<PendingTransactionsScreen> {
  late final PendingTransactionsNotifier _notifier;
  bool _ownsNotifier = false;

  @override
  void initState() {
    super.initState();
    if (widget.notifier != null) {
      _notifier = widget.notifier!;
    } else if (widget.isDemoMode) {
      _notifier = PendingTransactionsNotifier();
      _ownsNotifier = true;
      _notifier.initialize();
    } else {
      _notifier = NotificationPipelineService.instance.pendingNotifier;
      NotificationPipelineService.instance.initialize();
    }
  }

  @override
  void dispose() {
    if (_ownsNotifier) {
      _notifier.dispose();
    }
    super.dispose();
  }

  Future<void> _handleAcceptAll() async {
    final summary = await _notifier.acceptAll();
    if (!mounted) return;

    AlertHelper.success(
      context,
      'Se aceptaron ${summary.acceptedCount} transacciones. '
      'Quedan ${summary.remainingCount} pendientes de revisión.',
    );
  }

  Future<void> _handleConfirm(PendingTransactionItem item) async {
    final success = await _notifier.confirmItem(item.id);
    if (!mounted) return;

    if (!success && _notifier.errorMessage != null) {
      AlertHelper.error(context, _notifier.errorMessage!);
    }
  }

  Future<void> _handleCorrect(PendingTransactionItem item) async {
    final correction = await CorrectionDialog.show(
      context,
      item: item,
      availableAccounts: widget.isDemoMode
          ? const ['Ahorros Bancolombia *1234', 'Nequi *5678']
          : null,
    );

    if (correction == null || !mounted) return;

    final success = await _notifier.correctItem(
      id: item.id,
      newClassification: correction.classification,
      newCategory: correction.category,
      newAccountName: correction.accountName,
      newDestinationAccount: correction.destinationAccount,
      newAmount: correction.amount,
      newDescription: correction.description,
      newDate: correction.date,
    );

    if (!mounted) return;

    if (!success && _notifier.errorMessage != null) {
      AlertHelper.error(context, _notifier.errorMessage!);
    }
  }

  Future<void> _handleDiscard(PendingTransactionItem item) async {
    await _notifier.discardItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    final appThemeExtension = Theme.of(context).extension<AppTheme>();
    final theme = appThemeExtension ??
        AppTheme.forMode(ThemeNotifier.activeMode);

    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final items = _notifier.items;
        final hasEligible = _notifier.eligibleCount > 0;

        Widget buildScaffold(BuildContext scaffoldContext) {
          final header = MoneoHeaderBar.subScreen(
            title: 'Pendientes',
            badge: items.isNotEmpty
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: theme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          );

          return Scaffold(
            backgroundColor: theme.primaryBackground,
            appBar: header.asPreferredSize(scaffoldContext),
            body: Column(
              children: [
                if (widget.isDemoMode) _buildDemoBanner(theme),
                Expanded(child: _buildBody(theme, items, hasEligible)),
              ],
            ),
          );
        }

        if (appThemeExtension == null) {
          return Theme(
            data: buildThemeData(ThemeNotifier.activeMode),
            child: Builder(builder: buildScaffold),
          );
        }

        return buildScaffold(context);
      },
    );
  }

  Widget _buildDemoBanner(AppTheme theme) {
    return Container(
      key: const Key('demo_mode_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.accent.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 16,
            color: theme.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demostración: datos simulados. No modifica saldos reales.',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    AppTheme theme,
    List<PendingTransactionItem> items,
    bool hasEligible,
  ) {
    if (_notifier.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: theme.accent,
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: theme.cardBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inbox_outlined,
                  size: 36,
                  color: theme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No hay transacciones pendientes',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Las notificaciones bancarias detectadas aparecerán aquí.',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Barra de resumen y aprobación en lote fuera del AppBar (evita desbordamiento)
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasEligible
                          ? '${_notifier.eligibleCount} listas para aprobar'
                          : 'Revisión manual requerida',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_notifier.manualReviewCount > 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_notifier.manualReviewCount} requieren revisión manual',
                        style: TextStyle(
                          color: theme.warning,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                key: const Key('accept_all_button'),
                onPressed: hasEligible ? _handleAcceptAll : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.buttonBackground,
                  foregroundColor: theme.buttonForeground,
                  disabledBackgroundColor:
                      theme.borderSubtle.withValues(alpha: 0.25),
                  disabledForegroundColor: theme.textHint,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Aceptar todo',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            padding: MoneoLayoutMetrics.scrollBottomPadding(
              context,
              hasFab: false,
              horizontal: 0,
              top: 2,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return PendingTransactionCard(
                key: ValueKey(item.id),
                item: item,
                onConfirm: () => _handleConfirm(item),
                onCorrect: () => _handleCorrect(item),
                onDiscard: () => _handleDiscard(item),
              );
            },
          ),
        ),
      ],
    );
  }
}
