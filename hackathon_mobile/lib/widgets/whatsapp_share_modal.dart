import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';

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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WhatsappShareModal(
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

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDelivery = widget.isDeliveryReceipt;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 18),

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDelivery ? AppColors.successLight : const Color(0xFFE8F8EE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isDelivery ? Icons.verified_rounded : Icons.chat_bubble_outline_rounded,
                    color: isDelivery ? AppColors.success : AppColors.whatsapp,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDelivery ? 'Partage Preuve de Livraison 🛡️' : 'Facturation WhatsApp 📲',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        isDelivery ? 'Garantie anti-arnaque pour le client' : 'Vente à distance sans carte bancaire',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Aperçu du message WhatsApp
            const Text('Aperçu du message pour le client :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: SelectableText(
                _formattedMessage,
                style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textPrimary, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 18),

            // Champ optionnel pour le numéro WhatsApp
            const Text('Numéro WhatsApp du client (optionnel) :', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: 'ex: 221771234567 ou 33612345678',
                hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.background,
                prefixIcon: const Icon(Icons.phone_iphone_rounded, color: AppColors.whatsapp, size: 20),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
              ),
            ),
            const SizedBox(height: 22),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.whatsapp,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: const Text('COPIER LE MESSAGE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _formattedMessage));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Message WhatsApp copié ! Collez-le dans votre discussion.'),
                          backgroundColor: AppColors.whatsappDark,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
