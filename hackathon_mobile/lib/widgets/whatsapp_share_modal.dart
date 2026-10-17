import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import 'common/app_bottom_sheet.dart';

class WhatsappShareModal extends StatefulWidget {
  final String title;
  final String amountText;
  final String reference;
  final String bolt11OrPreimage;
  final bool isDeliveryReceipt; // true = Reçu de Livraison, false = Facture de Vente

  const WhatsappShareModal({
    super.key,
    required this.title,
    required this.amountText,
    required this.reference,
    required this.bolt11OrPreimage,
    this.isDeliveryReceipt = false,
  });

  static void show(
    BuildContext context, {
    required String title,
    required String amountText,
    required String reference,
    required String bolt11OrPreimage,
    bool isDeliveryReceipt = false,
  }) {
    AppBottomSheet.show(
      context,
      WhatsappShareModal(
        title: title,
        amountText: amountText,
        reference: reference,
        bolt11OrPreimage: bolt11OrPreimage,
        isDeliveryReceipt: isDeliveryReceipt,
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
      return '''✅ *PAYCHAIN DAKAR - PREUVE DE LIVRAISON SÉCURISÉE* 🛡️

📦 *Commande :* ${widget.title}
💰 *Montant Réglé :* ${widget.amountText}
🔗 *Référence :* ${widget.reference}
🔐 *Preimage (Preuve Cryptographique) :*
${widget.bolt11OrPreimage}

Ce reçu officiel certifie le déblocage irrévocable des fonds sur le réseau Bitcoin Lightning.''';
    } else {
      return '''⚡ *FACTURE SÉCURISÉE PAYCHAIN DAKAR* 🇸🇳

📦 *Article :* ${widget.title}
💰 *Montant :* ${widget.amountText}
🔗 *Réf :* ${widget.reference}

Réglez en 1 clic avec votre portefeuille Lightning (Blink, Strike, CashApp, Phoenix) :
${widget.bolt11OrPreimage}''';
    }
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
                isDelivery ? Icons.verified_rounded : Icons.chat_rounded,
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
                    isDelivery ? 'Preuve de livraison' : 'Facture WhatsApp',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDelivery ? 'Garantie anti-arnaque pour le client' : 'Vente à distance sans carte bancaire',
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copier le message', maxLines: 1, overflow: TextOverflow.ellipsis),
            onPressed: () => _copyAndClose(
              _formattedMessage,
              'Message copié ! Collez-le dans la discussion WhatsApp.',
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
                      icon: const Icon(Icons.link_rounded, size: 18),
                      label: const Text('Copier le lien wa.me direct', maxLines: 1, overflow: TextOverflow.ellipsis),
                      onPressed: () => _copyAndClose(
                        _waLink,
                        'Lien wa.me copié ! Ouvrez-le pour écrire directement au client.',
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
