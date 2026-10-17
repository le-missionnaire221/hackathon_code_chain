import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../models/transaction_item.dart';
import '../widgets/transaction_card.dart';
import '../widgets/receipt_bottom_sheet.dart';
import '../widgets/blink_address_sheet.dart';

class WalletTab extends StatelessWidget {
  final int balanceSats;
  final double balanceFcfa;
  final int btcPriceFcfa;
  final int paidInvoicesCount;
  final int totalInvoicesCount;
  final bool isBalanceVisible;
  final bool isLoading;
  final bool isBackendOnline;
  final List<TransactionItem> transactions;
  final VoidCallback onToggleBalanceVisibility;
  final Future<void> Function() onRefresh;
  final VoidCallback onNavigateToPos;
  final VoidCallback onNavigateToHistory;

  const WalletTab({
    super.key,
    required this.balanceSats,
    required this.balanceFcfa,
    required this.btcPriceFcfa,
    required this.paidInvoicesCount,
    required this.totalInvoicesCount,
    required this.isBalanceVisible,
    required this.isLoading,
    required this.isBackendOnline,
    required this.transactions,
    required this.onToggleBalanceVisibility,
    required this.onRefresh,
    required this.onNavigateToPos,
    required this.onNavigateToHistory,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar : Profil & Statut du Nœud
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: AppColors.avatarGradient,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text(
                            AppConstants.developerInitials,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(AppConstants.developerName, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                          Text(AppConstants.hackathonLocation, style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isBackendOnline ? AppColors.successLight : AppColors.errorLight,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (isBackendOnline ? AppColors.success : AppColors.error).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: isBackendOnline ? AppColors.success : AppColors.error, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          isBackendOnline ? 'Bitnob Actif ⚡' : 'Hors Ligne',
                          style: TextStyle(color: isBackendOnline ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // Carte Principale du Solde en Dégradé Neobank
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppColors.walletGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SOLDE RÉEL BITNOB (TESTNET)',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: onToggleBalanceVisibility,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    isLoading
                        ? const SizedBox(
                            height: 38,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            ),
                          )
                        : Text(
                            isBalanceVisible ? '${balanceFcfa.toStringAsFixed(0)} FCFA' : '•••••••• FCFA',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                          ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            isBalanceVisible ? '$balanceSats SATS ⚡' : '•••• SATS',
                            style: const TextStyle(color: AppColors.lightningGold, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('1 BTC ≈ ${(btcPriceFcfa / 1000000).toStringAsFixed(1)}M FCFA', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Actions Rapides
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickActionButton(
                          icon: Icons.bolt_rounded,
                          label: 'Encaisser',
                          color: AppColors.lightningGold,
                          onTap: onNavigateToPos,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.sync_rounded,
                          label: 'Actualiser',
                          color: Colors.white,
                          onTap: onRefresh,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.qr_code_rounded,
                          label: 'Adresse Blink',
                          color: Colors.white,
                          onTap: () => BlinkAddressSheet.show(context),
                        ),
                        _buildQuickActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Reçus',
                          color: Colors.white,
                          onTap: onNavigateToHistory,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bannière Réelle Bitnob
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Règlement Réel Bitnob', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                          Text('$paidInvoicesCount / $totalInvoicesCount factures Lightning réglées avec Preimage', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // En-tête des dernières transactions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dernières Factures Bitnob', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  TextButton(
                    onPressed: onNavigateToHistory,
                    child: const Text('Tout voir', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (transactions.isEmpty && !isLoading)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'Aucune facture générée pour le moment.\nAllez dans "Encaisser ⚡" pour créer votre premier paiement !',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ),
                )
              else
                ...transactions.take(4).map(
                      (tx) => TransactionCard(
                        transaction: tx,
                        onTap: () => ReceiptBottomSheet.show(context, tx),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
