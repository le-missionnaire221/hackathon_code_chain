import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/transaction_item.dart';
import '../widgets/transaction_card.dart';
import '../widgets/receipt_bottom_sheet.dart';

class HistoryTab extends StatelessWidget {
  final List<TransactionItem> transactions;
  final Future<void> Function() onRefresh;

  const HistoryTab({
    super.key,
    required this.transactions,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Historique Réel Bitnob', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      Text('Factures Lightning enregistrées dans votre Sandbox', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                    onPressed: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (transactions.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Aucune transaction trouvée sur l\'API Bitnob.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: transactions.length,
                    itemBuilder: (ctx, i) => TransactionCard(
                      transaction: transactions[i],
                      onTap: () => ReceiptBottomSheet.show(context, transactions[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
