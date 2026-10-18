import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_item.dart';
import '../widgets/blink_address_sheet.dart';
import '../widgets/buyer_payment_sheet.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/receipt_bottom_sheet.dart';
import '../widgets/transaction_card.dart';

class WalletTab extends StatefulWidget {
  final int balanceSats;
  final double balanceFcfa;
  final int escrowSats;
  final double escrowFcfa;
  final int escrowInvoicesCount;
  final int btcPriceFcfa;
  final int paidInvoicesCount;
  final int totalInvoicesCount;
  final bool isBalanceVisible;
  final bool isLoading;
  final bool isBackendOnline;
  final String accountName;
  final String backendUrl;
  final List<TransactionItem> transactions;
  final VoidCallback onToggleBalanceVisibility;
  final Future<void> Function() onRefresh;
  final VoidCallback onNavigateToPos;
  final VoidCallback onNavigateToHistory;

  const WalletTab({
    super.key,
    required this.balanceSats,
    required this.balanceFcfa,
    this.escrowSats = 0,
    this.escrowFcfa = 0.0,
    this.escrowInvoicesCount = 0,
    required this.btcPriceFcfa,
    required this.paidInvoicesCount,
    required this.totalInvoicesCount,
    required this.isBalanceVisible,
    required this.isLoading,
    required this.isBackendOnline,
    required this.accountName,
    required this.backendUrl,
    required this.transactions,
    required this.onToggleBalanceVisibility,
    required this.onRefresh,
    required this.onNavigateToPos,
    required this.onNavigateToHistory,
  });

  @override
  State<WalletTab> createState() => _WalletTabState();
}

class _WalletTabState extends State<WalletTab> {
  int _filterIndex = 0; // 0 = Tout, 1 = Confirmés, 2 = En attente / Autres

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'PC';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  static const TextStyle _balanceStyle = TextStyle(
    fontSize: 38,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    letterSpacing: -0.8,
  );

  List<TransactionItem> get _filteredTransactions {
    final all = widget.transactions;
    if (_filterIndex == 1) return all.where((tx) => tx.isConfirmed).toList();
    if (_filterIndex == 2) return all.where((tx) => !tx.isConfirmed).toList();
    return all;
  }

  int get _confirmedCount => widget.transactions.where((tx) => tx.isConfirmed).length;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildBalanceCard(context),
            if (widget.escrowSats > 0) ...[
              const SizedBox(height: 14),
              _buildEscrowBanner(),
            ],
            const SizedBox(height: 20),
            _buildSectionHeader(),
            const SizedBox(height: 12),
            _buildFilters(),
            const SizedBox(height: 12),
            ..._buildTransactions(context),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── En-tête profil ─────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.avatarGradient,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4)),
            ],
          ),
          child: Text(
            _initials(widget.accountName),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bonjour',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                widget.accountName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        StatusPill(
          label: widget.isBackendOnline ? 'En ligne' : 'Hors ligne',
          tone: widget.isBackendOnline ? PillTone.success : PillTone.error,
          showDot: true,
        ),
      ],
    );
  }

  // ───────────────────────── Carte solde ─────────────────────────
  Widget _buildBalanceCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.walletGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 14)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet_rounded, color: Colors.white70, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'SOLDE DISPONIBLE',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                InkWell(
                  onTap: widget.onToggleBalanceVisibility,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      widget.isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              width: double.infinity,
              child: widget.isLoading && widget.balanceSats == 0
                  ? const Align(
                      alignment: Alignment.centerLeft,
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: widget.isBalanceVisible
                          ? TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: widget.balanceFcfa),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) =>
                                  Text(Formatters.fcfa(value), style: _balanceStyle),
                            )
                          : const Text('••••••\u00A0FCFA', style: _balanceStyle),
                    ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    widget.isBalanceVisible
                        ? Formatters.sats(widget.balanceSats)
                        : '•••• SATS',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                Text(
                  '1 BTC ≈ ${Formatters.compactFcfa(widget.btcPriceFcfa)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11.5),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.point_of_sale_rounded,
                    label: 'Encaisser',
                    highlight: true,
                    onTap: widget.onNavigateToPos,
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_scanner_rounded,
                    label: 'Scanner',
                    onTap: () => BuyerPaymentSheet.show(
                      context,
                      backendUrl: widget.backendUrl,
                      onPaymentSuccess: widget.onRefresh,
                    ),
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.qr_code_2_rounded,
                    label: 'Recevoir',
                          onTap: () => BlinkAddressSheet.show(
                            context,
                            backendUrl: widget.backendUrl,
                            currentBalanceSats: widget.balanceSats,
                            onReceived: widget.onRefresh,
                          ),
                  ),
                ),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.receipt_long_rounded,
                    label: 'Reçus',
                    onTap: widget.onNavigateToHistory,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Bannière Séquestre ─────────────────────────
  Widget _buildEscrowBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.amberDark, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'SÉQUESTRE EN COURS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.amberDark, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 6),
                    StatusPill(label: '${widget.escrowInvoicesCount} commande(s)', tone: PillTone.warning, dense: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.fcfa(widget.escrowFcfa)} (${Formatters.sats(widget.escrowSats)}) gardés jusqu’à la livraison.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final total = widget.transactions.length;
    final confirmed = _confirmedCount;
    final others = total - confirmed;
    return Row(
      children: [
        _filterChip(0, 'Tout ($total)'),
        const SizedBox(width: 8),
        _filterChip(1, 'Confirmés ($confirmed)'),
        const SizedBox(width: 8),
        _filterChip(2, 'Autres ($others)'),
      ],
    );
  }

  Widget _filterChip(int index, String label) {
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
              border: Border.all(color: selected ? AppColors.primary : AppColors.border),
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

  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Transactions',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
        TextButton(
          onPressed: widget.onNavigateToHistory,
          child: const Text('Tout voir'),
        ),
      ],
    );
  }

  List<Widget> _buildTransactions(BuildContext context) {
    final filtered = _filteredTransactions;
    if (widget.transactions.isEmpty && widget.isLoading) {
      return const [SkeletonCard(), SkeletonCard(), SkeletonCard()];
    }
    if (widget.transactions.isEmpty) {
      return [
        EmptyState(
          icon: Icons.point_of_sale_rounded,
          title: 'Aucune facture pour le moment',
          message: 'Créez votre premier encaissement en quelques secondes.',
          actionLabel: 'Encaisser maintenant',
          onAction: widget.onNavigateToPos,
        ),
      ];
    }
    if (filtered.isEmpty) {
      return [
        const EmptyState(
          icon: Icons.filter_list_rounded,
          title: 'Aucun élément pour ce filtre',
          message: 'Sélectionnez « Tout » pour voir toutes les transactions.',
        ),
      ];
    }
    return filtered
        .take(6)
        .map((tx) => TransactionCard(
              transaction: tx,
              onTap: () => ReceiptBottomSheet.show(context, tx, onUpdated: widget.onRefresh),
            ))
        .toList();
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: highlight ? AppColors.lightningGold : Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: highlight ? 0 : 0.22)),
              ),
              child: Icon(icon, color: highlight ? AppColors.sapphire : Colors.white, size: 24),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
