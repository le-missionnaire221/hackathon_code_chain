import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import 'common/app_bottom_sheet.dart';

class WhatsappShareModal extends StatefulWidget {
  final String title;
  final String amountText;
  final String reference;
  final String bolt11OrPreimage;
  final bool isDeliveryReceipt; // true = Reçu de Livraison, false = Facture de Vente
  final bool isEscrow; // true = Commande sous séquestre bilatéral
  final String? backendUrl;

  const WhatsappShareModal({
    super.key,
    required this.title,
    required this.amountText,
    required this.reference,
    required this.bolt11OrPreimage,
    this.isDeliveryReceipt = false,
    this.isEscrow = false,
    this.backendUrl,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String amountText,
    required String reference,
    required String bolt11OrPreimage,
    bool isDeliveryReceipt = false,
    bool isEscrow = false,
    String? backendUrl,
  }) {
    AppBottomSheet.show(
      context,
      WhatsappShareModal(
        title: title,
        amountText: amountText,
        reference: reference,
        bolt11OrPreimage: bolt11OrPreimage,
        isDeliveryReceipt: isDeliveryReceipt,
        isEscrow: isEscrow,
        backendUrl: backendUrl,
      ),
    );
  }

  @override
  State<WhatsappShareModal> createState() => _WhatsappShareModalState();
}

class _WhatsappShareModalState extends State<WhatsappShareModal> {
  final TextEditingController _phoneController = TextEditingController();

  String get _formattedMessage {
    if (widget.isDeliveryReceipt) {
      return '''✅ *PAYCHAIN DAKAR - REMISE DU COLIS CONFIRMÉE* 🛡️

📦 *Commande :* ${widget.title}
💰 *Montant Débloqué :* ${widget.amountText}
🔗 *Référence :* ${widget.reference}
🔐 *Preimage / Clé de Preuve :*
${widget.bolt11OrPreimage}

La remise du colis a été certifiée et les fonds sont définitivement libérés.''';
    } else if (widget.isEscrow) {
      return '''Commande PayChain — livraison sécurisée

Article : ${widget.title}
Montant : ${widget.amountText}
Réf : ${widget.reference}

Ouvrez ce lien pour payer :
$_payLink

Vous payez maintenant. L'argent est gardé. Donnez le code au marchand seulement quand vous avez reçu le colis.''';
    } else {
      return '''Facture PayChain

Article : ${widget.title}
Montant : ${widget.amountText}
Réf : ${widget.reference}

Ouvrez ce lien pour payer :
$_payLink''';
    }
  }

  String get _payLink {
    final base = (widget.backendUrl != null && widget.backendUrl!.isNotEmpty)
        ? widget.backendUrl!
        : AppConstants.productionBackendUrl;
    return '$base/pay/${widget.reference}';
  }

  String get _phoneDigits => _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  String get _waLink => 'https://wa.me/$_phoneDigits?text=${Uri.encodeComponent(_formattedMessage)}';

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _copyAndClose(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.whatsappDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = widget.isDeliveryReceipt;
    final hasPhone = _phoneDigits.length >= 8;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isDelivery ? AppColors.successGradient : AppColors.whatsappGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isDelivery
                    ? Icons.verified_rounded
                    : (widget.isEscrow ? Icons.shield_rounded : Icons.chat_rounded),
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isDelivery
                        ? 'Preuve de remise'
                        : (widget.isEscrow ? 'Lien de paiement · livraison' : 'Lien de paiement'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDelivery
                        ? 'À envoyer après la remise du colis'
                        : 'À envoyer sur WhatsApp, SMS ou tout autre réseau',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        const Text(
          'APERÇU DU MESSAGE',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.8),
        ),
        const SizedBox(height: 8),
        // Bulle façon WhatsApp, hauteur limitée et scrollable
        Container(
          constraints: const BoxConstraints(maxHeight: 220),
          decoration: BoxDecoration(
            color: AppColors.whatsappLight,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(color: AppColors.whatsapp.withValues(alpha: 0.25)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: SelectableText(
              _formattedMessage,
              style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: 18),

        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Numéro WhatsApp du client (optionnel)',
            hintText: 'ex : 221771234567',
            prefixIcon: Icon(Icons.phone_iphone_rounded, color: AppColors.whatsapp, size: 20),
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Copier le lien', maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () => _copyAndClose(
              _payLink,
              'Lien copié. Collez-le où vous voulez.',
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.ios_share_rounded, size: 18),
            label: const Text('Partager le lien', maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () async {
              final nav = Navigator.of(context);
              await Share.share(_formattedMessage, subject: 'Paiement PayChain');
              nav.pop();
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copier le message', maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () => _copyAndClose(
              _formattedMessage,
              'Message copié.',
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: hasPhone
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.whatsappDark,
                        side: BorderSide(color: AppColors.whatsapp.withValues(alpha: 0.5)),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: const Text('Ouvrir WhatsApp', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => _copyAndClose(
                        _waLink,
                        'Lien WhatsApp copié. Ouvrez-le pour écrire au client.',
                      ),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
