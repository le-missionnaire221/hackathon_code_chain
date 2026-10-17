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

class WalletTab extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _buildHeader(context),
            const SizedBox(height: 20),
            _buildBalanceCard(context),
            if (escrowSats > 0) ...[
              const SizedBox(height: 14),
              _buildEscrowBanner(),
            ],
            const SizedBox(height: 16),
            _buildStatsRow(),
            const SizedBox(height: 26),
            _buildSectionHeader(),
            const SizedBox(height: 8),
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
            _initials(accountName),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Bonjour 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                accountName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => BuyerPaymentSheet.show(
            context,
            backendUrl: backendUrl,
            onPaymentSuccess: onRefresh,
          ),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.chipBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        StatusPill(
          label: isBackendOnline ? 'Bitnob actif' : 'Hors ligne',
          tone: isBackendOnline ? PillTone.success : PillTone.error,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned(top: -70, right: -50, child: _glow(200, 0.10)),
            Positioned(bottom: -80, left: -40, child: _glow(170, 0.07)),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.lightningGold, size: 18),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'SOLDE DISPONIBLE • BITNOB TESTNET',
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
                        onTap: onToggleBalanceVisibility,
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Montant principal en FCFA : FittedBox = jamais d'overflow
                  SizedBox(
                    height: 50,
                    width: double.infinity,
                    child: isLoading && balanceSats == 0
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
                            child: isBalanceVisible
                                ? TweenAnimationBuilder<double>(
                                    tween: Tween(begin: 0, end: balanceFcfa),
                                    duration: const Duration(milliseconds: 900),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, value, child) =>
                                        Text(Formatters.fcfa(value), style: _balanceStyle),
                                  )
                                : const Text('••••••\u00A0FCFA', style: _balanceStyle),
                          ),
                  ),
                  const SizedBox(height: 6),
                  // Double montant : SATS (épargne) + taux BTC
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
                          isBalanceVisible ? '⚡ ${Formatters.sats(balanceSats)}' : '⚡ ••••\u00A0SATS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.lightningGold,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      Text(
                        '1 BTC ≈ ${Formatters.compactFcfa(btcPriceFcfa)}',
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
                          icon: Icons.bolt_rounded,
                          label: 'Encaisser',
                          highlight: true,
                          onTap: onNavigateToPos,
                        ),
                      ),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.shield_rounded,
                          label: 'Payer 🛡️',
                          onTap: () => BuyerPaymentSheet.show(
                            context,
                            backendUrl: backendUrl,
                            onPaymentSuccess: onRefresh,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.qr_code_2_rounded,
                          label: 'Recevoir',
                          onTap: () => BlinkAddressSheet.show(context),
                        ),
                      ),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.receipt_long_rounded,
                          label: 'Reçus',
                          onTap: onNavigateToHistory,
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
                    StatusPill(label: '$escrowInvoicesCount commande(s)', tone: PillTone.warning, dense: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${Formatters.fcfa(escrowFcfa)} (${Formatters.sats(escrowSats)}) garantis, libérables à la livraison.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF78350F), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }

  // ───────────────────────── Statistiques ─────────────────────────
  Widget _buildStatsRow() {
    final ratio = totalInvoicesCount == 0 ? 0.0 : paidInvoicesCount / totalInvoicesCount;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.verified_rounded,
            iconColor: AppColors.success,
            title: 'Factures réglées',
            value: '$paidInvoicesCount / $totalInvoicesCount',
            footer: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.success,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.savings_rounded,
            iconColor: AppColors.amber,
            title: 'Épargne en SATS',
            value: isBalanceVisible ? Formatters.thousands(balanceSats) : '••••',
            footer: const Text(
              'Protégée de l\'inflation',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Transactions ─────────────────────────
  Widget _buildSectionHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Dernières factures',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
        ),
        TextButton(
          onPressed: onNavigateToHistory,
          child: const Text('Tout voir'),
        ),
      ],
    );
  }

  List<Widget> _buildTransactions(BuildContext context) {
    if (transactions.isEmpty && isLoading) {
      return const [SkeletonCard(), SkeletonCard(), SkeletonCard()];
    }
    if (transactions.isEmpty) {
      return [
        EmptyState(
          icon: Icons.bolt_rounded,
          title: 'Aucune facture pour le moment',
          message: 'Créez votre premier encaissement Lightning en quelques secondes.',
          actionLabel: 'Encaisser maintenant',
          onAction: onNavigateToPos,
        ),
      ];
    }
    return transactions
        .take(4)
        .map((tx) => TransactionCard(
              transaction: tx,
              onTap: () => ReceiptBottomSheet.show(context, tx),
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final Widget footer;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 8),
          footer,
        ],
      ),
    );
  }
}
