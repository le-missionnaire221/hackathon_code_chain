import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_item.dart';
import 'common/status_pill.dart';

class TransactionCard extends StatelessWidget {
  final TransactionItem transaction;
  final VoidCallback onTap;

  const TransactionCard({
    super.key,
    required this.transaction,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = StatusPill.fromTransactionStatus(transaction.status);
    final isConfirmed = tone == PillTone.success;
    final iconBg = isConfirmed ? AppColors.successSoft : AppColors.surfaceMuted;
    final iconColor = isConfirmed ? AppColors.success : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                    isConfirmed ? Icons.bolt_rounded : Icons.schedule_rounded,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              Formatters.relative(transaction.date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 6),
                          StatusPill(label: statusLabel, tone: tone, dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '+${Formatters.thousands(transaction.amountSats)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: isConfirmed ? AppColors.primary : AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '≈ ${Formatters.fcfa(transaction.amountFcfa)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
