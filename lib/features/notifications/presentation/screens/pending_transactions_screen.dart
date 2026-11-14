import 'package:flutter/material.dart';
import 'package:finazaap/features/notifications/domain/models/pending_transaction_item.dart';
import 'package:finazaap/features/notifications/presentation/notifiers/pending_transactions_notifier.dart';
import 'package:finazaap/features/notifications/presentation/widgets/correction_dialog.dart';
import 'package:finazaap/features/notifications/presentation/widgets/pending_transaction_card.dart';
import 'package:finazaap/themes/app_colors.dart';

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
    } else {
      _notifier = PendingTransactionsNotifier();
      _ownsNotifier = true;
      _notifier.initialize();
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.cardBackground,
        content: Text(
          'Se aceptaron ${summary.acceptedCount} transacciones. '
          'Quedan ${summary.remainingCount} pendientes de revisión.',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _handleConfirm(PendingTransactionItem item) async {
    final success = await _notifier.confirmItem(item.id);
    if (!mounted) return;

    if (!success && _notifier.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            _notifier.errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _handleCorrect(PendingTransactionItem item) async {
    final correction = await CorrectionDialog.show(
      context,
      item: item,
    );

    if (correction == null || !mounted) return;

    final success = await _notifier.correctItem(
      id: item.id,
      newClassification: correction.classification,
      newCategory: correction.category,
      newAccountName: correction.accountName,
      newDestinationAccount: correction.destinationAccount,
      newAmount: correction.amount,
    );

    if (!mounted) return;

    if (!success && _notifier.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          content: Text(
            _notifier.errorMessage!,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }
  }

  Future<void> _handleDiscard(PendingTransactionItem item) async {
    await _notifier.discardItem(item.id);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final items = _notifier.items;
        final hasEligible = _notifier.eligibleCount > 0;

        return Scaffold(
          backgroundColor: AppColors.primaryBackground,
          appBar: AppBar(
            backgroundColor: AppColors.primaryBackground,
            elevation: 0,
            title: Row(
              children: [
                Text(
                  'Transacciones Pendientes',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (items.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: Text(
                      '${items.length}',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ElevatedButton(
                    key: const Key('accept_all_button'),
                    onPressed: hasEligible ? _handleAcceptAll : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: AppColors.primaryBackground,
                      disabledBackgroundColor:
                          AppColors.borderSubtle.withValues(alpha: 0.3),
                      disabledForegroundColor: AppColors.textHint,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
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
                ),
            ],
          ),
          body: Column(
            children: [
              if (widget.isDemoMode) _buildDemoBanner(),
              Expanded(child: _buildBody(items)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDemoBanner() {
    return Container(
      key: const Key('demo_mode_banner'),
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.science_outlined,
            size: 18,
            color: AppColors.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Demostración: datos simulados. No modifica saldos reales.',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(List<PendingTransactionItem> items) {
    if (_notifier.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: AppColors.accent,
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay transacciones pendientes',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Las notificaciones bancarias detectadas aparecerán aquí.',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_notifier.manualReviewCount > 0)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.warning.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_notifier.manualReviewCount} de ${items.length} transacciones requieren revisión manual '
                    '(sospechosas o baja confianza).',
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            padding: const EdgeInsets.only(bottom: 24),
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
