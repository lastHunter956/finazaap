import 'package:flutter/material.dart';
import 'package:finazaap/core/theme_notifier.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/domain/models/spam_models.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/presentation/widgets/correction_dialog.dart';
import 'package:finazaap/features/notifications/presentation/widgets/pending_transaction_card.dart';
import 'package:finazaap/features/notifications/services/notification_pipeline_service.dart';
import 'package:finazaap/themes/app_theme_data.dart';
import 'package:finazaap/utils/alert_helper.dart';
import 'package:finazaap/utils/currency_helper.dart';
import 'package:finazaap/widgets/moneo_header_bar.dart';

enum _PendingInboxTab { pending, spam }

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
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};
  _PendingInboxTab _activeTab = _PendingInboxTab.pending;

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
      NotificationPipelineService.instance.initialize().then((_) {
        NotificationPipelineService.instance.flushBatchNow();
      });
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
    _selectedIds.remove(item.id);
    await _notifier.discardItem(item.id);
  }

  Future<void> _handleConfirmSpam(SpamNotificationItem spamItem) async {
    final ok = await _notifier.confirmSpamItem(spamItem.id);
    if (!mounted || !ok) return;
    AlertHelper.success(
      context,
      'Spam confirmado. Avisos similares se filtrarán sin usar IA.',
    );
  }

  Future<void> _handleRestoreFromSpam(SpamNotificationItem spamItem) async {
    final restored = await _notifier.restoreFromSpam(spamItem.id);
    if (!mounted || restored == null) return;
    setState(() {
      _activeTab = _PendingInboxTab.pending;
    });
    AlertHelper.success(
      context,
      'Movida a Pendientes. Se desactivó la regla de spam para este aviso.',
    );
  }

  Future<void> _handleCorrectFromSpam(SpamNotificationItem spamItem) async {
    final restored = await _notifier.restoreFromSpam(spamItem.id);
    if (!mounted || restored == null) return;
    setState(() {
      _activeTab = _PendingInboxTab.pending;
    });
    await _handleCorrect(restored);
  }

  Future<void> _handleSplit(PendingTransactionItem item) async {
    final ok = await _notifier.splitMergedItem(item.id);
    if (!mounted) return;
    if (ok) {
      AlertHelper.success(context, 'Avisos separados en movimientos individuales');
    }
  }

  Future<void> _handleMergeSelected() async {
    if (_selectedIds.length < 2) return;
    final merged = await _notifier.mergePendingItems(_selectedIds.toList());
    if (!mounted) return;
    if (merged != null) {
      setState(() {
        _isSelectionMode = false;
        _selectedIds.clear();
      });
      AlertHelper.success(context, 'Notificaciones agrupadas en 1 movimiento');
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedIds.clear();
    });
  }

  void _toggleItemSelection(String id, bool? selected) {
    setState(() {
      if (selected ?? false) {
        _selectedIds.add(id);
      } else {
        _selectedIds.remove(id);
      }
    });
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
        final spamItems = _notifier.spamItems;
        final hasEligible = _notifier.eligibleCount > 0;

        Widget buildScaffold(BuildContext scaffoldContext) {
          final isSpamView = _activeTab == _PendingInboxTab.spam;
          final activeCount = isSpamView ? spamItems.length : items.length;
          final header = MoneoHeaderBar.subScreen(
            title: isSpamView ? 'Spam' : 'Pendientes',
            badge: activeCount > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: (isSpamView ? theme.warning : theme.accent)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$activeCount',
                      style: TextStyle(
                        color: isSpamView ? theme.warning : theme.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            actions: [
              Semantics(
                button: true,
                label: isSpamView
                    ? 'Volver a Pendientes'
                    : 'Abrir carpeta Spam',
                child: TextButton.icon(
                  key: const Key('pending_spam_tab_button'),
                  onPressed: () {
                    setState(() {
                      _activeTab = isSpamView
                          ? _PendingInboxTab.pending
                          : _PendingInboxTab.spam;
                      _isSelectionMode = false;
                      _selectedIds.clear();
                    });
                  },
                  icon: Icon(
                    isSpamView
                        ? Icons.inbox_outlined
                        : Icons.filter_alt_off_outlined,
                    size: 16,
                  ),
                  label: Text(
                    isSpamView
                        ? 'Pendientes (${items.length})'
                        : 'Spam (${spamItems.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        isSpamView ? theme.accent : theme.textSecondary,
                    minimumSize: const Size(48, 48),
                    tapTargetSize: MaterialTapTargetSize.padded,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ),
            ],
          );

          return Scaffold(
            backgroundColor: theme.primaryBackground,
            appBar: header.asPreferredSize(scaffoldContext),
            body: Column(
              children: [
                if (widget.isDemoMode) _buildDemoBanner(theme),
                Expanded(
                  child: _activeTab == _PendingInboxTab.pending
                      ? _buildBody(theme, items, hasEligible)
                      : _buildSpamBody(theme, spamItems),
                ),
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

    final validIds = items.map((e) => e.id).toSet();
    _selectedIds.removeWhere((id) => !validIds.contains(id));
    final canSelectToGroup = items.length >= 2;
    if (!canSelectToGroup && _isSelectionMode) {
      _isSelectionMode = false;
      _selectedIds.clear();
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isSelectionMode
                            ? '${_selectedIds.length} seleccionadas para agrupar'
                            : hasEligible
                                ? '${_notifier.eligibleCount} listas para aprobar'
                                : 'Revisión manual requerida',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!_isSelectionMode &&
                          _notifier.manualReviewCount > 0) ...[
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (canSelectToGroup)
                        Semantics(
                          button: true,
                          label: _isSelectionMode
                              ? 'Cancelar selección para agrupar'
                              : 'Seleccionar avisos para agrupar',
                          child: OutlinedButton.icon(
                            key: const Key('toggle_selection_mode_button'),
                            onPressed: _toggleSelectionMode,
                            icon: Icon(
                              _isSelectionMode
                                  ? Icons.close_rounded
                                  : Icons.layers_outlined,
                              size: 16,
                            ),
                            label: Text(
                              _isSelectionMode ? 'Cancelar' : 'Agrupar',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.accent,
                              minimumSize: const Size(48, 48),
                              tapTargetSize: MaterialTapTargetSize.padded,
                              side: BorderSide(
                                color: theme.accent.withValues(alpha: 0.45),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      if (_isSelectionMode)
                        ElevatedButton(
                          key: const Key('merge_selected_button'),
                          onPressed: _selectedIds.length >= 2
                              ? _handleMergeSelected
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.buttonBackground,
                            foregroundColor: theme.buttonForeground,
                            disabledBackgroundColor:
                                theme.borderSubtle.withValues(alpha: 0.25),
                            disabledForegroundColor: theme.textHint,
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
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
                            'Agrupar en 1',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          key: const Key('accept_all_button'),
                          onPressed: hasEligible ? _handleAcceptAll : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.buttonBackground,
                            foregroundColor: theme.buttonForeground,
                            disabledBackgroundColor:
                                theme.borderSubtle.withValues(alpha: 0.25),
                            disabledForegroundColor: theme.textHint,
                            minimumSize: const Size(48, 48),
                            tapTargetSize: MaterialTapTargetSize.padded,
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
                ],
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
                onSplit: item.isGrouped ? () => _handleSplit(item) : null,
                isSelectionMode: _isSelectionMode,
                isSelected: _selectedIds.contains(item.id),
                onSelectionChanged: (selected) =>
                    _toggleItemSelection(item.id, selected),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpamBody(
    AppTheme theme,
    List<SpamNotificationItem> spamItems,
  ) {
    if (_notifier.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.accent),
      );
    }

    if (spamItems.isEmpty) {
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
                  Icons.mark_email_read_outlined,
                  size: 34,
                  color: theme.textSecondary.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sin notificaciones en Spam',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Las promociones y avisos ignorados se guardan aquí hasta 5 días por si necesitas rescatar alguno.',
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
        Container(
          key: const Key('spam_retention_banner'),
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: theme.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.borderSubtle),
          ),
          child: Row(
            children: [
              Icon(
                Icons.auto_delete_outlined,
                size: 16,
                color: theme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Los avisos en Spam se borran automáticamente después de 5 días. No afectan saldos ni consumen IA si ya fueron marcados.',
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: spamItems.length,
            padding: MoneoLayoutMetrics.scrollBottomPadding(
              context,
              hasFab: false,
              horizontal: 0,
              top: 2,
            ),
            itemBuilder: (context, index) {
              return _buildSpamCard(theme, spamItems[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSpamCard(AppTheme theme, SpamNotificationItem spamItem) {
    final item = spamItem.item;
    final daysLeft = spamItem.remainingDays();
    final title = item.comercio ?? item.packageName ?? 'Notificación filtrada';
    final hasAmount = item.monto != null && item.monto! > 0;
    final daysLabel = daysLeft <= 1
        ? 'Se borra en menos de 1 día'
        : 'Se borra en $daysLeft días';

    return Container(
      key: ValueKey('spam_card_${spamItem.id}'),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.warning.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.filter_alt_off_outlined,
                  size: 18,
                  color: theme.warning,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      daysLabel,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasAmount) ...[
                const SizedBox(width: 8),
                Text(
                  CurrencyHelper.format(item.monto!),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: theme.darkBackground.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item.rawText,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            spamItem.spamReason,
            style: TextStyle(
              color: theme.warning,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: theme.borderSubtle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextButton(
                key: ValueKey('confirm_spam_${spamItem.id}'),
                onPressed: () => _handleConfirmSpam(spamItem),
                style: TextButton.styleFrom(
                  foregroundColor: theme.error,
                  minimumSize: const Size(48, 48),
                  tapTargetSize: MaterialTapTargetSize.padded,
                ),
                child: const Text(
                  'Confirmar spam',
                  style: TextStyle(fontSize: 12.5),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    key: ValueKey('restore_spam_${spamItem.id}'),
                    onPressed: () => _handleRestoreFromSpam(spamItem),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.accent,
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      side: BorderSide(
                        color: theme.accent.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'A Pendientes',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                  ElevatedButton(
                    key: ValueKey('correct_spam_${spamItem.id}'),
                    onPressed: () => _handleCorrectFromSpam(spamItem),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.buttonBackground,
                      foregroundColor: theme.buttonForeground,
                      minimumSize: const Size(48, 48),
                      tapTargetSize: MaterialTapTargetSize.padded,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Corregir',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
