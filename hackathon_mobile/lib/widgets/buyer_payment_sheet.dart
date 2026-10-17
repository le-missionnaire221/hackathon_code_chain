import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/utils/formatters.dart';
import '../screens/qr_scan_screen.dart';
import 'common/app_bottom_sheet.dart';

class BuyerPaymentSheet extends StatefulWidget {
  final String backendUrl;
  final VoidCallback? onPaymentSuccess;

  const BuyerPaymentSheet({
    super.key,
    required this.backendUrl,
    this.onPaymentSuccess,
  });

  static void show(
    BuildContext context, {
    required String backendUrl,
    VoidCallback? onPaymentSuccess,
  }) {
    AppBottomSheet.show(
      context,
      BuyerPaymentSheet(
        backendUrl: backendUrl,
        onPaymentSuccess: onPaymentSuccess,
      ),
    );
  }

  @override
  State<BuyerPaymentSheet> createState() => _BuyerPaymentSheetState();
}

class _BuyerPaymentSheetState extends State<BuyerPaymentSheet> {
  final TextEditingController _inputController = TextEditingController();
  bool _isLoading = false;
  bool _isPaying = false;
  String? _errorMessage;

  // Détails de la facture trouvée
  Map<String, dynamic>? _invoiceData;
  String? _extractedRef;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  String _cleanReference(String raw) {
    String text = raw.trim();
    if (text.contains('/pay/')) {
      final parts = text.split('/pay/');
      if (parts.length > 1) {
        text = parts[1].split('?')[0].split('#')[0].trim();
      }
    }
    return text;
  }

  Future<void> _scanQr() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;
    _inputController.text = code.trim();
    await _lookupInvoice(code);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null && text.isNotEmpty) {
      _inputController.text = text;
      _lookupInvoice(text);
    }
  }

  Future<void> _lookupInvoice(String raw) async {
    final ref = _cleanReference(raw);
    if (ref.isEmpty) {
      setState(() => _errorMessage = 'Veuillez saisir ou coller une référence valide.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _invoiceData = null;
      _extractedRef = ref;
    });

    final res = await ApiService.lookupInvoice(widget.backendUrl, raw);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res != null && res['error'] == null && res['reference'] != null) {
        _invoiceData = res;
        _extractedRef = res['reference']?.toString();
      } else {
        _errorMessage = 'Commande introuvable. Vérifiez la référence ou le lien.';
      }
    });
  }

  Future<void> _confirmPayment() async {
    final ref = _extractedRef;
    if (ref == null) return;

    setState(() {
      _isPaying = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    final res = await ApiService.payInvoice(widget.backendUrl, ref);

    if (!mounted) return;
    setState(() => _isPaying = false);

    if (res != null && res['success'] == true) {
      HapticFeedback.heavyImpact();
      setState(() {
        _invoiceData = res['invoice'] ?? res;
      });
      widget.onPaymentSuccess?.call();
    } else {
      setState(() {
        _errorMessage = res?['error'] ?? 'Échec du règlement';
      });
    }
  }

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(label), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = _invoiceData?['status'] == 'paid';
    final isEscrow = _invoiceData?['isEscrow'] == true;
    final releaseCode = _invoiceData?['releaseCode']?.toString();
    final sats = int.tryParse(_invoiceData?['amount']?.toString() ?? '0') ?? 0;
    final fcfa = (_invoiceData?['amountFcfa'] as num?)?.toDouble() ?? sats * AppConstants.satRateInFcfa;
    final merchantName = _invoiceData?['merchantName']?.toString();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isEscrow ? AppColors.whatsappSoft : AppColors.chipBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isEscrow ? Icons.shield_rounded : Icons.qr_code_scanner_rounded,
                  color: isEscrow ? AppColors.whatsappDark : AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEscrow ? 'Espace Acheteur • Séquestre 🛡️' : 'Régler une Commande ⚡',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Réglez et obtenez votre code secret de livraison',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Champ de saisie ou de collage si pas encore chargé
          if (_invoiceData == null) ...[
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scanner le QR du marchand'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'Collez le lien /pay/... ou la réf. ESC_...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.link_rounded, color: AppColors.textSecondary, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'Coller depuis le presse-papier',
                  onPressed: _pasteFromClipboard,
                ),
              ),
              onSubmitted: _lookupInvoice,
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.search_rounded, size: 20),
              label: Text(_isLoading ? 'Recherche en cours…' : 'VÉRIFIER LA COMMANDE 🔍'),
              onPressed: _isLoading ? null : () => _lookupInvoice(_inputController.text),
            ),
          ] else ...[
            // CARTE COMMANDE TROUVÉE
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isPaid ? AppColors.successSoft : AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isPaid ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isEscrow ? AppColors.whatsappSoft : AppColors.chipBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isEscrow ? '🛡️ Séquestre Anti-Arnaque' : '⚡ Paiement Direct',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isEscrow ? AppColors.whatsappDark : AppColors.primary,
                          ),
                        ),
                      ),
                      Text(
                        'Réf. ${_extractedRef ?? '-'}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (merchantName != null && merchantName.isNotEmpty)
                    Text(
                      merchantName,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                    ),
                  Text(
                    _invoiceData?['description'] ?? 'Article PayChain',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        Formatters.fcfa(fcfa),
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '≈ ${Formatters.sats(sats)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),

                  // SI DÉJÀ RÉGLÉ : AFFICHAGE DU CODE SECRET ACHETEUR (OTP)
                  if (isPaid && isEscrow) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.success, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.2),
                            blurRadius: 15,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.vpn_key_rounded, color: AppColors.successDark, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'VOTRE CODE SECRET DE DÉBLOCAGE (OTP)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.successDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            releaseCode ?? '••••',
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 8,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '⚠️ Ne donnez ce code au livreur qu\'après avoir inspecté et validé votre colis physique !',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // BOUTON PAYER SI NON ENCORE RÉGLÉ
            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'Bitnob va régler ${Formatters.fcfa(fcfa)} sur Lightning. Le marchand est crédité seulement après confirmation Bitnob.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amberDark, height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEscrow ? AppColors.whatsapp : AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: _isPaying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.bolt_rounded, size: 20),
                label: Text(
                  _isPaying
                      ? 'Règlement en cours…'
                      : 'PAYER ${Formatters.fcfa(fcfa)}',
                ),
                onPressed: _isPaying ? null : _confirmPayment,
              ),
            ] else ...[
              if (releaseCode != null && releaseCode.isNotEmpty) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('COPIER MON CODE SECRET (OTP)'),
                  onPressed: () => _copy(releaseCode, 'Code secret copié !'),
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],

            if (!isPaid) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() => _invoiceData = null),
                child: const Text('Vérifier une autre commande'),
              ),
            ],
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
