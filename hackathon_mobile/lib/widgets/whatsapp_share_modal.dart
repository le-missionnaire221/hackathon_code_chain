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
      final payLink = widget.backendUrl != null && widget.backendUrl!.isNotEmpty
          ? '${widget.backendUrl}/pay/${widget.reference}'
          : 'http://localhost:5000/pay/${widget.reference}';
      return '''🛡️ *COMMANDE SOUS SÉQUESTRE SÉCURISÉ - PAYCHAIN DAKAR* 🇸🇳

📦 *Article :* ${widget.title}
💰 *Montant :* ${widget.amountText}
🔗 *Réf :* ${widget.reference}

🛡️ *GARANTIE ANTI-ARNAQUE ACHETEUR & MARCHAND :*
Vos fonds sont consignés sous séquestre sécurisé. Ils ne seront débloqués au vendeur que lorsque vous aurez inspecté et validé votre colis en mains propres !

🌐 *Page de Paiement & Code Secret de Livraison :*
$payLink

⚡ *Facture Lightning BOLT11 directe :*
${widget.bolt11OrPreimage}''';
    } else {
      final payLink = widget.backendUrl != null && widget.backendUrl!.isNotEmpty
          ? '${widget.backendUrl}/pay/${widget.reference}'
          : 'http://localhost:5000/pay/${widget.reference}';
      return '''⚡ *FACTURE SÉCURISÉE PAYCHAIN DAKAR* 🇸🇳

📦 *Article :* ${widget.title}
💰 *Montant :* ${widget.amountText}
🔗 *Réf :* ${widget.reference}

🌐 *Page de Paiement Direct :*
$payLink

⚡ *Facture Lightning BOLT11 :*
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
                        : (widget.isEscrow ? 'Facture sous séquestre 🛡️' : 'Facture WhatsApp'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isDelivery
                        ? 'Garantie anti-arnaque confirmée'
                        : (widget.isEscrow ? 'Fonds protégés jusqu\'à la remise physique' : 'Vente à distance sans carte bancaire'),
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
