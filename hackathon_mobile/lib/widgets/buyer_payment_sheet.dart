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
  final String? initialCode;

  const BuyerPaymentSheet({
    super.key,
    required this.backendUrl,
    this.onPaymentSuccess,
    this.initialCode,
  });

  static void show(
    BuildContext context, {
    required String backendUrl,
    VoidCallback? onPaymentSuccess,
    String? initialCode,
  }) {
    AppBottomSheet.show(
      context,
      BuyerPaymentSheet(
        backendUrl: backendUrl,
        onPaymentSuccess: onPaymentSuccess,
        initialCode: initialCode,
      ),
    );
  }

  @override
  State<BuyerPaymentSheet> createState() => _BuyerPaymentSheetState();
}

class _BuyerPaymentSheetState extends State<BuyerPaymentSheet> {
  final TextEditingController _inputController = TextEditingController();
  final TextEditingController _amountFcfaController = TextEditingController();
  bool _isLoading = false;
  bool _isPaying = false;
  String? _errorMessage;

  /// Facture marchand OU adresse Recevoir PayChain
  Map<String, dynamic>? _invoiceData;
  String? _extractedRef;

  bool get _isAddressTransfer => _invoiceData?['type']?.toString() == 'paychain_address';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialCode?.trim();
    if (initial != null && initial.isNotEmpty) {
      _inputController.text = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _lookupInvoice(initial);
      });
    }
  }

  @override
  void dispose() {
    _inputController.dispose();
    _amountFcfaController.dispose();
    super.dispose();
  }

  String _cleanReference(String raw) {
    String text = raw.trim();
    final lower = text.toLowerCase();
    if (lower.startsWith('lightning:')) {
      text = text.substring('lightning:'.length).trim();
    }
    if (lower.startsWith('paychain://pay/')) {
      text = text.substring('paychain://pay/'.length).split('?').first.split('#').first.trim();
    }
    if (text.contains('/pay/')) {
      final parts = text.split('/pay/');
      if (parts.length > 1) {
        text = parts[1].split('?')[0].split('#')[0].trim();
      }
    }
    return text;
  }

  int _satsFromFcfaInput() {
    final fcfa = double.tryParse(_amountFcfaController.text.replaceAll(',', '.').trim()) ?? 0;
    if (fcfa <= 0) return 0;
    return (fcfa / AppConstants.satRateInFcfa).round();
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
      setState(() => _errorMessage = 'Veuillez saisir, coller ou scanner un QR valide.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _invoiceData = null;
      _extractedRef = ref;
      _amountFcfaController.clear();
    });

    final res = await ApiService.lookupInvoice(widget.backendUrl, raw);

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (res != null && res['error'] != null && res['status']?.toString() == 'expired') {
        _errorMessage = res['error']?.toString() ??
            'Ce QR / lien a expiré après 24 heures. Demandez un nouveau paiement.';
      } else if (res != null && res['error'] == null) {
        final type = res['type']?.toString();
        if (type == 'paychain_address' || (res['address'] != null && res['recipientUserId'] != null)) {
          _invoiceData = {...res, 'type': 'paychain_address'};
          _extractedRef = res['address']?.toString() ?? ref;
        } else if (res['reference'] != null) {
          _invoiceData = {...res, 'type': res['type'] ?? 'invoice'};
          _extractedRef = res['reference']?.toString();
          if (res['status']?.toString() == 'paid' || res['alreadyPaid'] == true) {
            _errorMessage = 'Ce QR est déjà payé. Un seul paiement est accepté.';
          }
        } else {
          _errorMessage = 'Commande ou adresse introuvable.';
        }
      } else {
        _errorMessage = res?['error']?.toString() ??
            'QR introuvable. Scannez une facture ou une adresse Recevoir.';
      }
    });
  }

  Future<void> _confirmPayment() async {
    if (_isAddressTransfer) {
      await _confirmAddressTransfer();
      return;
    }

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
        _invoiceData = {...?_invoiceData, ...res, 'status': 'paid', 'type': 'invoice'};
      });
      widget.onPaymentSuccess?.call();
    } else {
      setState(() {
        _errorMessage = res?['error']?.toString() ?? 'Échec du règlement';
      });
    }
  }

  Future<void> _confirmAddressTransfer() async {
    final address = _invoiceData?['address']?.toString() ?? _extractedRef;
    final sats = _satsFromFcfaInput();
    if (address == null || address.isEmpty) return;
    if (sats <= 0) {
      setState(() => _errorMessage = 'Entrez un montant en FCFA à envoyer.');
      return;
    }

    setState(() {
      _isPaying = true;
      _errorMessage = null;
    });
    HapticFeedback.mediumImpact();

    final res = await ApiService.payPaychainAddress(
      widget.backendUrl,
      address: address,
      amountSats: sats,
    );

    if (!mounted) return;
    setState(() => _isPaying = false);

    if (res != null && res['success'] == true) {
      HapticFeedback.heavyImpact();
      setState(() {
        _invoiceData = {
          ...?_invoiceData,
          ...res,
          'type': 'paychain_address',
          'status': 'paid',
          'amount': res['amountSats'],
          'amountFcfa': res['amountFcfa'],
          'description': 'Envoi à ${res['recipientName'] ?? address}',
        };
      });
      widget.onPaymentSuccess?.call();
    } else {
      setState(() {
        _errorMessage = res?['error']?.toString() ?? 'Échec de l’envoi';
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
    final isAddress = _isAddressTransfer;
    final releaseCode = _invoiceData?['releaseCode']?.toString();
    final sats = int.tryParse(_invoiceData?['amount']?.toString() ?? '0') ?? 0;
    final fcfa = (_invoiceData?['amountFcfa'] as num?)?.toDouble() ?? sats * AppConstants.satRateInFcfa;
    final merchantName = (_invoiceData?['merchantName'] ?? _invoiceData?['recipientName'])?.toString();
    final previewSats = isAddress ? _satsFromFcfaInput() : sats;
    final previewFcfa = isAddress
        ? (double.tryParse(_amountFcfaController.text.replaceAll(',', '.').trim()) ?? 0)
        : fcfa;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  isEscrow
                      ? Icons.shield_rounded
                      : (isAddress ? Icons.send_rounded : Icons.qr_code_scanner_rounded),
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
                      isAddress
                          ? 'Envoyer de l’argent'
                          : (isEscrow ? 'Espace Acheteur • Séquestre' : 'Régler une commande'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAddress
                          ? 'Scan du QR Recevoir → choisissez le montant'
                          : 'Réglez et obtenez votre code secret de livraison',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (_invoiceData == null) ...[
            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _scanQr,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('Scanner un QR (facture ou Recevoir)'),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _inputController,
              decoration: InputDecoration(
                hintText: 'Lien /pay/…, réf. ou adresse …@raktak.cash',
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
              label: Text(_isLoading ? 'Recherche en cours…' : 'VÉRIFIER'),
              onPressed: _isLoading ? null : () => _lookupInvoice(_inputController.text),
            ),
          ] else ...[
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
                          color: isAddress
                              ? AppColors.chipBackground
                              : (isEscrow ? AppColors.whatsappSoft : AppColors.chipBackground),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isAddress
                              ? 'Adresse Recevoir'
                              : (isEscrow ? 'Séquestre Anti-Arnaque' : 'Paiement direct'),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isEscrow && !isAddress ? AppColors.whatsappDark : AppColors.primary,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          isAddress ? (_invoiceData?['address']?.toString() ?? '') : 'Réf. ${_extractedRef ?? '-'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
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
                    _invoiceData?['description']?.toString() ?? (isAddress ? 'Envoi RAK TAK CASH' : 'Article'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (!isAddress || isPaid) ...[
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
                  ],
                  if (isAddress && !isPaid) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _amountFcfaController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Montant à envoyer (FCFA)',
                        hintText: 'Ex. 1000',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    if (previewSats > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        '≈ ${Formatters.sats(previewSats)}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ],
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
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
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
                            'Ne donnez ce code au livreur qu’après avoir inspecté et validé votre colis.',
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

            if (!isPaid) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  isAddress
                      ? (previewSats > 0
                          ? 'Votre solde sera débité de ${Formatters.fcfa(previewFcfa)}. Le destinataire reçoit l’argent tout de suite.'
                          : 'Entrez le montant puis validez l’envoi.')
                      : 'Ce compte va débiter ${Formatters.fcfa(fcfa)}. Le marchand n’est crédité que lorsque vous appuyez sur Payer.',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amberDark, height: 1.35),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isEscrow && !isAddress ? AppColors.whatsapp : AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                icon: _isPaying
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Icon(isAddress ? Icons.send_rounded : Icons.payments_rounded, size: 20),
                label: Text(
                  _isPaying
                      ? (isAddress ? 'Envoi en cours…' : 'Règlement en cours…')
                      : (isAddress
                          ? (previewSats > 0 ? 'ENVOYER ${Formatters.fcfa(previewFcfa)}' : 'ENVOYER')
                          : 'PAYER ${Formatters.fcfa(fcfa)}'),
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
                child: Text(isAddress ? 'Envoi terminé — Fermer' : 'Fermer'),
              ),
            ],

            if (!isPaid) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => setState(() {
                  _invoiceData = null;
                  _amountFcfaController.clear();
                }),
                child: Text(isAddress ? 'Scanner une autre adresse' : 'Vérifier une autre commande'),
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
