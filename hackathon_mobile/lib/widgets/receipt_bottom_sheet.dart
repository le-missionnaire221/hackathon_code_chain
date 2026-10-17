import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_item.dart';
import 'common/app_bottom_sheet.dart';
import 'common/info_row.dart';
import 'common/status_pill.dart';
import 'whatsapp_share_modal.dart';

class ReceiptBottomSheet extends StatelessWidget {
  final TransactionItem transaction;
  final BuildContext parentContext;

  const ReceiptBottomSheet({
    super.key,
    required this.transaction,
    required this.parentContext,
  });

  static void show(BuildContext context, TransactionItem transaction) {
    AppBottomSheet.show(
      context,
      ReceiptBottomSheet(transaction: transaction, parentContext: context),
    );
  }

  void _copy(BuildContext context, String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = StatusPill.fromTransactionStatus(transaction.status);
    final hasPreimage = transaction.preimage != null && transaction.preimage!.isNotEmpty;
    final hasRequest = transaction.request != null && transaction.request!.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: tone == PillTone.success ? AppColors.successGradient : null,
              color: tone == PillTone.success ? null : AppColors.surfaceMuted,
              shape: BoxShape.circle,
            ),
            child: Icon(
              tone == PillTone.success ? Icons.check_rounded : Icons.receipt_long_rounded,
              color: tone == PillTone.success ? Colors.white : AppColors.textSecondary,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Reçu Lightning',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        Center(child: StatusPill(label: statusLabel, tone: tone)),
        const SizedBox(height: 16),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '+${Formatters.sats(transaction.amountSats)}',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
        ),
        Text(
          '≈ ${Formatters.fcfa(transaction.amountFcfa)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              InfoRow(label: 'Description', value: transaction.title),
              const Divider(),
              InfoRow(
                label: 'Référence',
                value: transaction.reference,
                monospace: true,
                onCopy: () => _copy(context, transaction.reference, 'Référence copiée !'),
              ),
              const Divider(),
              InfoRow(
                label: 'ID Bitnob',
                value: Formatters.shortHash(transaction.id),
                monospace: true,
                onCopy: () => _copy(context, transaction.id, 'Identifiant Bitnob copié !'),
              ),
              const Divider(),
              InfoRow(label: 'Date', value: Formatters.dateTime(transaction.date)),
              if (hasPreimage) ...[
                const Divider(),
                InfoRow(
                  label: 'Preimage (preuve)',
                  value: Formatters.shortHash(transaction.preimage!),
                  monospace: true,
                  valueColor: AppColors.successDark,
                  onCopy: () => _copy(context, transaction.preimage!, 'Preimage copiée !'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (hasPreimage) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.verified_rounded, size: 18),
            label: const Text(
              'Partager la preuve de paiement',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (!parentContext.mounted) return;
              WhatsappShareModal.show(
                parentContext,
                title: transaction.title,
                amountText: '${Formatters.sats(transaction.amountSats)} (≈ ${Formatters.fcfa(transaction.amountFcfa)})',
                reference: transaction.reference,
                bolt11OrPreimage: transaction.preimage!,
                isDeliveryReceipt: true,
              );
            },
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            if (hasRequest) ...[
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copier BOLT11', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () => _copy(context, transaction.request!, 'Facture BOLT11 copiée !'),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Fermer', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
