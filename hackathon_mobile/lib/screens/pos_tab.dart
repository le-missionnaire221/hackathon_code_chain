import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../widgets/whatsapp_share_modal.dart';

class PosTab extends StatefulWidget {
  final String backendUrl;
  final Function(int sats, String reference, String? preimage, String description) onPaymentReceived;

  const PosTab({
    super.key,
    required this.backendUrl,
    required this.onPaymentReceived,
  });

  @override
  State<PosTab> createState() => _PosTabState();
}

class _PosTabState extends State<PosTab> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  final TextEditingController _descController = TextEditingController(text: 'Sac Artisanal Cuir Ngor');

  bool _isDistanceMode = false; // false = Mode TPE Comptoir, true = Mode Vente à Distance WhatsApp
  bool _isLoading = false;
  String? _bolt11Invoice;
  String? _invoiceReference;
  String? _preimage;
  bool _isPaid = false;
  Timer? _statusTimer;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackbar('Veuillez entrer un montant valide supérieur à 0.', AppColors.error);
      return;
    }

    setState(() {
      _isLoading = true;
      _bolt11Invoice = null;
      _invoiceReference = null;
      _isPaid = false;
      _preimage = null;
    });

    final data = await ApiService.createInvoice(
      widget.backendUrl,
      amount: amount,
      description: _descController.text,
    );

    if (data != null && data['data'] != null && data['data']['request'] != null) {
      setState(() {
        _bolt11Invoice = data['data']['request'];
        _invoiceReference = data['reference'];
        _isLoading = false;
      });

      _startPolling(data['reference']);
    } else {
      setState(() => _isLoading = false);
      _showSnackbar(
        'Erreur Bitnob : ${data?['error'] ?? data?['message'] ?? 'Impossible de joindre le backend'}',
        AppColors.error,
      );
    }
  }

  void _startPolling(String reference) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final data = await ApiService.getInvoiceStatus(widget.backendUrl, reference);
      if (data != null && data['status'] == 'paid') {
        timer.cancel();
        setState(() {
          _isPaid = true;
          _preimage = data['preimage'];
        });
        final sats = int.tryParse(_amountController.text) ?? 100;
        widget.onPaymentReceived(sats, reference, data['preimage'], _descController.text);
      }
    });
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sats = int.tryParse(_amountController.text) ?? 0;
    final fcfa = sats * AppConstants.satRateInFcfa;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isDistanceMode ? 'Vente à Distance 📦' : 'Point de Vente TPE ⚡',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      _isDistanceMode ? 'Facturation WhatsApp & Freelance mondial' : 'Caisse présentielle par QR Code BOLT11',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isDistanceMode ? const Color(0xFFE8F8EE) : AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _isDistanceMode ? 'WhatsApp 📲' : 'Comptoir 🏪',
                    style: TextStyle(
                      color: _isDistanceMode ? AppColors.whatsapp : AppColors.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (_isPaid)
              _buildSuccessCard()
            else if (_bolt11Invoice != null)
              _buildInvoiceCard()
            else
              _buildGeneratorCard(fcfa),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratorCard(double fcfa) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SÉLECTEUR DE CANAL : COMPTOIR VS VENTE À DISTANCE
          const Text('CANAL DE VENTE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.8)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isDistanceMode = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isDistanceMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_isDistanceMode
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.storefront_rounded, size: 16, color: !_isDistanceMode ? AppColors.primary : AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'Comptoir (TPE)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: !_isDistanceMode ? AppColors.primary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isDistanceMode = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isDistanceMode ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isDistanceMode
                            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_rounded, size: 16, color: _isDistanceMode ? AppColors.whatsapp : AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(
                            'WhatsApp / À distance',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _isDistanceMode ? AppColors.whatsapp : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('MONTANT À ENCAISSER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('SATS ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '≈ ${fcfa.toStringAsFixed(0)} FCFA (Taux de conversion instantané)',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppConstants.quickSatsPresets.map((sats) {
              return InkWell(
                onTap: () {
                  setState(() => _amountController.text = sats);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                  ),
                  child: Text('+$sats sats', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Article / Description de la vente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.background,
              hintText: 'ex: Sac Artisanal Cuir, Prestation Freelance...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isDistanceMode ? AppColors.whatsapp : AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _createInvoice,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isDistanceMode ? Icons.chat_bubble_rounded : Icons.bolt_rounded,
                          color: _isDistanceMode ? Colors.white : AppColors.lightningGold,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isDistanceMode ? 'GÉNÉRER LA COMMANDE WHATSAPP' : 'GÉNÉRER LE QR CODE TPE',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildInvoiceCard() {
    final sats = _amountController.text;
    final fcfa = (int.tryParse(sats) ?? 0) * AppConstants.satRateInFcfa;
    final amountText = '$sats SATS (~ ${fcfa.toStringAsFixed(0)} FCFA)';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$sats SATS', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.primary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amber)),
                    SizedBox(width: 6),
                    Text('En attente ⚡', style: TextStyle(color: AppColors.amberDark, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('${_descController.text} • Réf: $_invoiceReference', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 18),

          // BOUTON WHATSAPP TRÈS VISIBLE EN MODE DISTANCE
          if (_isDistanceMode) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8EE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.whatsapp.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, color: AppColors.whatsapp, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Commande à distance prête !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                        Text('Envoyez la facture sur WhatsApp à votre client pour qu\'il règle.', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.whatsapp,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('ENVOYER LA FACTURE PAR WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  WhatsappShareModal.show(
                    context,
                    title: _descController.text,
                    amountText: amountText,
                    reference: _invoiceReference ?? 'N/A',
                    bolt11OrPreimage: _bolt11Invoice!,
                    isDeliveryReceipt: false,
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
          ],

          // QR CODE POUR MODE COMPTOIR / PRÉSENTIEL
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: QrImageView(
              data: _bolt11Invoice!,
              version: QrVersions.auto,
              size: 210,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppColors.sapphire),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                  label: const Text('Copier BOLT11', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _bolt11Invoice!));
                    _showSnackbar('Facture Lightning copiée dans le presse-papier !', AppColors.primary);
                  },
                ),
              ),
              if (!_isDistanceMode) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.whatsapp, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.whatsapp),
                    label: const Text('WhatsApp', style: TextStyle(color: AppColors.whatsapp, fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      WhatsappShareModal.show(
                        context,
                        title: _descController.text,
                        amountText: amountText,
                        reference: _invoiceReference ?? 'N/A',
                        bolt11OrPreimage: _bolt11Invoice!,
                        isDeliveryReceipt: false,
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
              SizedBox(width: 8),
              Text('Règlement sur le réseau Lightning en cours...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () {
              _statusTimer?.cancel();
              setState(() {
                _bolt11Invoice = null;
                _invoiceReference = null;
                _preimage = null;
              });
            },
            child: const Text('Annuler et revenir', style: TextStyle(color: AppColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    final sats = _amountController.text;
    final fcfa = (int.tryParse(sats) ?? 0) * AppConstants.satRateInFcfa;
    final amountText = '$sats SATS (${fcfa.toStringAsFixed(0)} FCFA)';

    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.success, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.success.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.successLight, shape: BoxShape.circle),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, size: 50, color: AppColors.success),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Paiement Reçu avec Succès !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(
            '$sats Satoshis confirmés sur Lightning Network ⚡',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.success, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),

          // BANNIÈRE PREUVE DE LIVRAISON SÉCURISÉE (ANTI-ARNAQUE)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_rounded, color: AppColors.success, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'PREUVE DE LIVRAISON SÉCURISÉE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.success, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Fonds débloqués de façon irrévocable (Zero-Conf). Aucun risque de chargeback. Le commerçant peut remettre la marchandise en toute confiance.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3),
                ),
                if (_preimage != null) ...[
                  const SizedBox(height: 10),
                  const Text('Preimage (Preuve Cryptographique) :', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _preimage!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text('Réf Commande : $_invoiceReference', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 22),

          // BOUTON PARTAGE DU REÇU SUR WHATSAPP
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.whatsapp,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.share_rounded, size: 18),
              label: const Text('PARTAGER LE REÇU DE LIVRAISON WHATSAPP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: () {
                WhatsappShareModal.show(
                  context,
                  title: _descController.text,
                  amountText: amountText,
                  reference: _invoiceReference ?? 'N/A',
                  bolt11OrPreimage: _preimage ?? 'Preimage confirmée',
                  isDeliveryReceipt: true,
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // BOUTON NOUVEAU PAIEMENT
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () {
                setState(() {
                  _bolt11Invoice = null;
                  _invoiceReference = null;
                  _isPaid = false;
                  _preimage = null;
                });
              },
              child: const Text('NOUVELLE TRANSACTION ⚡', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
