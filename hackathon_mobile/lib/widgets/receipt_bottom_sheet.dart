import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/session.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_item.dart';
import 'common/app_bottom_sheet.dart';
import 'common/info_row.dart';
import 'common/status_pill.dart';
import 'whatsapp_share_modal.dart';

class ReceiptBottomSheet extends StatefulWidget {
  final TransactionItem transaction;
  final BuildContext parentContext;
  final Future<void> Function()? onUpdated;

  const ReceiptBottomSheet({
    super.key,
    required this.transaction,
    required this.parentContext,
    this.onUpdated,
  });

  static void show(
    BuildContext context,
    TransactionItem transaction, {
    Future<void> Function()? onUpdated,
  }) {
    AppBottomSheet.show(
      context,
      ReceiptBottomSheet(
        transaction: transaction,
        parentContext: context,
        onUpdated: onUpdated,
      ),
    );
  }

  @override
  State<ReceiptBottomSheet> createState() => _ReceiptBottomSheetState();
}

class _ReceiptBottomSheetState extends State<ReceiptBottomSheet> {
  final _codeController = TextEditingController();
  bool _releasing = false;
  String? _error;

  TransactionItem get transaction => widget.transaction;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _copy(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  Future<void> _unlock() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Entrez le code donné par le client.');
      return;
    }
    setState(() {
      _releasing = true;
      _error = null;
    });
    final backend = Session.backendUrl ?? AppConstants.productionBackendUrl;
    final res = await ApiService.releaseEscrow(backend, transaction.reference, code);
    if (!mounted) return;
    setState(() => _releasing = false);
    if (res == null || res['success'] != true) {
      setState(() => _error = res?['error']?.toString() ?? 'Code incorrect ou déblocage impossible.');
      return;
    }
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
    await widget.onUpdated?.call();
    if (!widget.parentContext.mounted) return;
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      const SnackBar(
        content: Text('Livraison validée. L\'argent est sur votre compte.'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final (statusLabel, tone) = StatusPill.fromTransactionStatus(transaction.status);
    final hasPreimage = transaction.preimage != null && transaction.preimage!.isNotEmpty;
    final hasRequest = transaction.request != null && transaction.request!.isNotEmpty;
    final isLocked = transaction.isLockedInEscrow;
    final isPending = !transaction.isConfirmed && !isLocked && !transaction.status.toLowerCase().contains('expir');

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
              isLocked
                  ? Icons.lock_outline_rounded
                  : (tone == PillTone.success ? Icons.check_rounded : Icons.receipt_long_rounded),
              color: tone == PillTone.success ? Colors.white : AppColors.textSecondary,
              size: 30,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isLocked ? 'Paiement bloqué' : (isPending ? 'En attente de paiement' : 'Reçu'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
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
        if (isPending) ...[
          const SizedBox(height: 8),
          const Text(
            'Le client a 24 h pour payer avec le lien ou le QR.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ],
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
                onCopy: () => _copy(transaction.reference, 'Référence copiée !'),
              ),
              const Divider(),
              InfoRow(label: 'Date', value: Formatters.dateTime(transaction.date)),
              if (hasPreimage) ...[
                const Divider(),
                InfoRow(
                  label: 'Preuve',
                  value: Formatters.shortHash(transaction.preimage!),
                  monospace: true,
                  valueColor: AppColors.successDark,
                  onCopy: () => _copy(transaction.preimage!, 'Preuve copiée !'),
                ),
              ],
            ],
          ),
        ),
        if (isLocked) ...[
          const SizedBox(height: 18),
          const Text(
            'Le client a payé. Entrez le code qu’il vous donne à la livraison pour débloquer l’argent.',
            style: TextStyle(fontSize: 13, color: AppColors.textBody, height: 1.35),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _codeController,
            textAlign: TextAlign.center,
            maxLength: 8,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 6),
            decoration: const InputDecoration(
              counterText: '',
              labelText: 'Code du client',
              hintText: '••••',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _releasing ? null : _unlock,
              icon: _releasing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(_releasing ? 'Validation…' : 'Valider la livraison et encaisser'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (hasPreimage && !isLocked) ...[
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text(
              'Partager la preuve',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () {
              Navigator.pop(context);
              if (!widget.parentContext.mounted) return;
              WhatsappShareModal.show(
                widget.parentContext,
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
        if (isPending && hasRequest) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 16),
            label: const Text('Partager le lien à nouveau', maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () {
              Navigator.pop(context);
              if (!widget.parentContext.mounted) return;
              WhatsappShareModal.show(
                widget.parentContext,
                title: transaction.title,
                amountText: '${Formatters.sats(transaction.amountSats)} (≈ ${Formatters.fcfa(transaction.amountFcfa)})',
                reference: transaction.reference,
                bolt11OrPreimage: transaction.request!,
                isEscrow: transaction.isEscrow,
                backendUrl: Session.backendUrl ?? AppConstants.productionBackendUrl,
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
                  label: const Text('Copier le code', maxLines: 1, overflow: TextOverflow.ellipsis),
                  onPressed: () => _copy(transaction.request!, 'Code Lightning copié.'),
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
