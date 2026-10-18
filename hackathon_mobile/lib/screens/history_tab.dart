import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_item.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/receipt_bottom_sheet.dart';
import '../widgets/transaction_card.dart';

class HistoryTab extends StatefulWidget {
  final List<TransactionItem> transactions;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final VoidCallback onNavigateToPos;

  const HistoryTab({
    super.key,
    required this.transactions,
    required this.isLoading,
    required this.onRefresh,
    required this.onNavigateToPos,
  });

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  int _filterIndex = 0; // 0 = Tout, 1 = Confirmés, 2 = En attente / Expirés

  List<TransactionItem> get _filteredTransactions {
    if (_filterIndex == 1) {
      return widget.transactions.where((tx) => tx.isConfirmed).toList();
    }
    if (_filterIndex == 2) {
      return widget.transactions.where((tx) => !tx.isConfirmed).toList();
    }
    return widget.transactions;
  }

  int get _totalSatsConfirmed {
    return widget.transactions
        .where((tx) => tx.isConfirmed)
        .fold(0, (sum, tx) => sum + tx.amountSats);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final totalConfirmed = widget.transactions.where((tx) => tx.isConfirmed).length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            // En-tête
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Reçus & Factures',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Historique en temps réel du nœud Bitnob',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Actualiser',
                  icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                  onPressed: widget.onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bannière de synthèse de trésorerie
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.sapphire, Color(0xFF0F2B48)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sapphire.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.lightningGold, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TOTAL ENCAISSÉ CONFIRMÉ',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '+${Formatters.sats(_totalSatsConfirmed)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: '$totalConfirmed payées',
                    tone: PillTone.success,
                    dense: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Filtres rapides (Tout, Confirmés, En attente)
            Row(
              children: [
                _buildFilterChip(0, 'Tout (${widget.transactions.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(1, 'Confirmés ($totalConfirmed)'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  2,
                  'Autres (${widget.transactions.length - totalConfirmed})',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Liste des transactions
            if (widget.isLoading && widget.transactions.isEmpty)
              ...List.generate(4, (_) => const SkeletonCard())
            else if (filtered.isEmpty)
              EmptyState(
                icon: Icons.receipt_long_rounded,
                title: _filterIndex == 0
                    ? 'Aucune facture enregistrée'
                    : 'Aucun élément pour ce filtre',
                message: _filterIndex == 0
                    ? 'Générez des factures depuis le TPE ou WhatsApp pour voir l\'historique se remplir.'
                    : 'Sélectionnez "Tout" pour afficher l\'ensemble des transactions.',
                actionLabel: _filterIndex == 0 ? 'Créer un paiement ⚡' : null,
                onAction: _filterIndex == 0 ? widget.onNavigateToPos : null,
              )
            else
              ...filtered.map(
                (tx) => TransactionCard(
                  transaction: tx,
                  onTap: () => ReceiptBottomSheet.show(
                    context,
                    tx,
                    onUpdated: widget.onRefresh,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final selected = _filterIndex == index;
    return Expanded(
      child: Material(
        color: selected ? AppColors.primary : AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => setState(() => _filterIndex = index),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
