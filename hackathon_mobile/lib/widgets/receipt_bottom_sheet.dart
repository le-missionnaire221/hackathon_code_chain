import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../models/transaction_item.dart';

class ReceiptBottomSheet extends StatelessWidget {
  final TransactionItem transaction;

  const ReceiptBottomSheet({super.key, required this.transaction});

  static void show(BuildContext context, TransactionItem transaction) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReceiptBottomSheet(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: AppColors.chipBackground, shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Reçu Réel Lightning Bitnob', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          Text(transaction.status, style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text(
            '+${transaction.amountSats} SATS',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
          Text('≈ ${transaction.amountFcfa.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Description', transaction.title),
                const Divider(height: 16, color: AppColors.border),
                _buildReceiptRow('Référence', transaction.reference, isMonospace: true),
                const Divider(height: 16, color: AppColors.border),
                _buildReceiptRow(
                  'Identifiant Bitnob',
                  transaction.id.length > 14 ? '${transaction.id.substring(0, 14)}...' : transaction.id,
                  isMonospace: true,
                ),
                const Divider(height: 16, color: AppColors.border),
                _buildReceiptRow('Horodatage', transaction.date.toString().substring(0, 16)),
                if (transaction.preimage != null && transaction.preimage!.isNotEmpty) ...[
                  const Divider(height: 16, color: AppColors.border),
                  _buildReceiptRow('Preimage (Preuve)', '${transaction.preimage!.substring(0, 14)}...', isMonospace: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (transaction.request != null && transaction.request!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                    label: const Text('Copier BOLT11', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: transaction.request!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Facture BOLT11 copiée !'), backgroundColor: AppColors.primary),
                      );
                    },
                  ),
                ),
              if (transaction.request != null && transaction.request!.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
}
