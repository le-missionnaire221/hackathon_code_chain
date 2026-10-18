import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/utils/formatters.dart';
import '../widgets/common/status_pill.dart';
import '../widgets/whatsapp_share_modal.dart';

enum _PosStage { input, waiting, paid }

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
  static const List<String> _fcfaPresets = ['500', '1000', '2500', '5000', '10000'];
  static const Duration _pollInterval = Duration(seconds: 2);
  static const Duration _pollTimeout = Duration(hours: 24);

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _otpInputController = TextEditingController();

  // Saisie
  bool _inputInFcfa = true;       // Le TPE saisit en FCFA : 2000 = 2 000 francs
  bool _isDistanceMode = false;   // false = Comptoir (TPE), true = WhatsApp / Séquestre Distance
  bool _isLoading = false;
  bool _isReleasingEscrow = false;

  // Facture en cours
  _PosStage _stage = _PosStage.input;
  String? _bolt11Invoice;
  String? _invoiceReference;
  String? _preimage;
  String? _releaseCode;
  String _escrowStatus = 'none'; // 'none', 'awaiting_lock', 'locked', 'released'
  int _invoiceSats = 0;
  String _invoiceDescription = '';
  DateTime? _invoiceCreatedAt;
  bool _isExpired = false;

  Timer? _statusTimer;
  Timer? _clockTimer;
  bool _pollInFlight = false;

  int get _enteredValue => int.tryParse(_amountController.text) ?? 0;

  int get _sats => _inputInFcfa ? (_enteredValue / AppConstants.satRateInFcfa).round() : _enteredValue;

  double get _fcfa => _inputInFcfa ? _enteredValue.toDouble() : _enteredValue * AppConstants.satRateInFcfa;

  Color get _accent => _isDistanceMode ? AppColors.whatsappDark : AppColors.primary;

  @override
  void dispose() {
    _stopTimers();
    _amountController.dispose();
    _descController.dispose();
    _otpInputController.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _statusTimer?.cancel();
    _clockTimer?.cancel();
    _statusTimer = null;
    _clockTimer = null;
  }

  // ───────────────────────── Logique de saisie ─────────────────────────
  void _toggleUnit() {
    HapticFeedback.lightImpact();
    setState(() {
      final sats = _sats;
      final fcfa = _fcfa;
      _inputInFcfa = !_inputInFcfa;
      final next = _inputInFcfa ? fcfa.round() : sats;
      _amountController.text = next > 0 ? next.toString() : '';
    });
  }

  // ───────────────────────── Facturation Bitnob & Séquestre ─────────────────────────
  Future<void> _createInvoice() async {
    final sats = _sats;
    if (sats <= 0) {
      _showSnackbar('Entrez un montant supérieur à 0.', AppColors.error);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final description = _descController.text.trim().isEmpty ? 'Paiement RAK TAK CASH' : _descController.text.trim();
    final data = await ApiService.createInvoice(
      widget.backendUrl,
      amount: sats,
      description: description,
      isEscrow: _isDistanceMode,
    );
    if (!mounted) return;

    final invoiceData = data?['data'];
    final request = invoiceData is Map ? invoiceData['request'] : null;

    if (request is String && request.isNotEmpty) {
      final reference = data?['reference']?.toString() ?? '';
      HapticFeedback.mediumImpact();
      setState(() {
        _isLoading = false;
        _bolt11Invoice = request;
        _invoiceReference = reference;
        _invoiceSats = sats;
        _invoiceDescription = description;
        _invoiceCreatedAt = DateTime.now();
        _preimage = null;
        _releaseCode = null;
        _escrowStatus = _isDistanceMode ? 'awaiting_lock' : 'none';
        _isExpired = false;
        _stage = _PosStage.waiting;
      });
      _startPolling(reference);
    } else {
      setState(() => _isLoading = false);
      final err = data?['error'] ?? data?['message'] ?? 'Impossible de joindre le serveur';
      _showSnackbar('Erreur Bitnob : $err', AppColors.error);
    }
  }

  void _startPolling(String reference) {
    _stopTimers();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _statusTimer = Timer.periodic(_pollInterval, (timer) async {
      if (_pollInFlight) return;

      final createdAt = _invoiceCreatedAt;
      if (createdAt != null && DateTime.now().difference(createdAt) > _pollTimeout) {
        _stopTimers();
        if (mounted) setState(() => _isExpired = true);
        return;
      }

      _pollInFlight = true;
      final data = await ApiService.getInvoiceStatus(widget.backendUrl, reference);
      _pollInFlight = false;

      if (!mounted || _invoiceReference != reference || _stage != _PosStage.waiting) return;

      if (data != null && data['status'] == 'paid') {
        _stopTimers();
        HapticFeedback.heavyImpact();
        final rawPreimage = data['preimage']?.toString();
        final code = data['releaseCode']?.toString() ?? (rawPreimage != null && rawPreimage.length >= 4 ? rawPreimage.substring(rawPreimage.length - 4).toUpperCase() : '80F9');
        final currentEscrow = data['escrowStatus']?.toString() ?? (_isDistanceMode ? 'locked' : 'none');

        setState(() {
          _preimage = rawPreimage;
          _releaseCode = code;
          _escrowStatus = currentEscrow;
          _stage = _PosStage.paid;
        });

        widget.onPaymentReceived(_invoiceSats, reference, rawPreimage, _invoiceDescription);
      }
    });
  }

  Future<void> _handleReleaseEscrow() async {
    final ref = _invoiceReference;
    if (ref == null) return;

    final enteredCode = _otpInputController.text.trim();
    if (enteredCode.isEmpty) {
      _showSnackbar('Entrez le code secret à 4 chiffres fourni par le client à la livraison.', AppColors.error);
      return;
    }

    setState(() => _isReleasingEscrow = true);
    HapticFeedback.mediumImpact();

    final res = await ApiService.releaseEscrow(
      widget.backendUrl,
      ref,
      enteredCode,
    );

    if (!mounted) return;
    setState(() => _isReleasingEscrow = false);

    if (res != null && res['success'] == true) {
      HapticFeedback.heavyImpact();
      setState(() {
        _escrowStatus = 'released';
      });
      widget.onPaymentReceived(_invoiceSats, ref, _preimage, _invoiceDescription);
      _showSnackbar('Livraison validée. L\'argent est sur votre compte.', AppColors.success);
    } else {
      final err = res?['error'] ?? 'Code secret invalide';
      _showSnackbar('Erreur : $err', AppColors.error);
    }
  }

  void _resetToInput() {
    _stopTimers();
    _otpInputController.clear();
    setState(() {
      _stage = _PosStage.input;
      _bolt11Invoice = null;
      _invoiceReference = null;
      _preimage = null;
      _releaseCode = null;
      _escrowStatus = 'none';
      _invoiceCreatedAt = null;
      _isExpired = false;
    });
  }

  void _copy(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    _showSnackbar(message, AppColors.primary);
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)));
  }

  String get _invoiceAmountText =>
      '${Formatters.sats(_invoiceSats)} (≈ ${Formatters.fcfa(_invoiceSats * AppConstants.satRateInFcfa)})';

  void _shareInvoice() {
    final bolt11 = _bolt11Invoice;
    if (bolt11 == null) return;
    WhatsappShareModal.show(
      context,
      title: _invoiceDescription,
      amountText: _invoiceAmountText,
      reference: _invoiceReference ?? 'N/A',
      bolt11OrPreimage: bolt11,
      isDeliveryReceipt: false,
      isEscrow: _isDistanceMode,
      backendUrl: widget.backendUrl,
    ).then((_) {
      if (!mounted || _stage != _PosStage.waiting) return;
      _resetToInput();
      _showSnackbar(
        'Lien prêt. Valable 24 h. Suivez le paiement dans Reçus.',
        AppColors.primary,
      );
    });
  }

  void _shareProof() {
    WhatsappShareModal.show(
      context,
      title: _invoiceDescription,
      amountText: _invoiceAmountText,
      reference: _invoiceReference ?? 'N/A',
      bolt11OrPreimage: _preimage ?? (_releaseCode ?? 'Preimage confirmée'),
      isDeliveryReceipt: true,
      isEscrow: _isDistanceMode,
      backendUrl: widget.backendUrl,
    );
  }

  // ───────────────────────── UI ─────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: switch (_stage) {
              _PosStage.input => KeyedSubtree(key: const ValueKey('input'), child: _buildInputStage()),
              _PosStage.waiting => KeyedSubtree(key: const ValueKey('waiting'), child: _buildWaitingStage()),
              _PosStage.paid => KeyedSubtree(key: const ValueKey('paid'), child: _buildPaidStage()),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final String title;
    final String subtitle;
    switch (_stage) {
      case _PosStage.input:
        title = _isDistanceMode ? 'Vente avec livraison' : 'Encaisser sur place';
        subtitle = _isDistanceMode
            ? 'Le client paie avant l\'envoi. Vous recevez l\'argent à la livraison.'
            : 'Le client scanne le QR code et paie tout de suite.';
        break;
      case _PosStage.waiting:
        title = 'En attente du paiement';
        subtitle = 'Valable 24 h. Vous pouvez quitter cet écran.';
        break;
      case _PosStage.paid:
        if (_isDistanceMode) {
          title = _escrowStatus == 'released' ? 'Colis remis' : 'Argent en attente';
          subtitle = _escrowStatus == 'released'
              ? 'Le client a reçu le colis. L\'argent est sur votre compte.'
              : 'L\'argent sera versé quand le client aura reçu le colis.';
        } else {
          title = 'Paiement reçu';
          subtitle = 'L\'argent est sur votre compte.';
        }
        break;
    }

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        StatusPill(
          label: _isDistanceMode ? 'Livraison' : 'Sur place',
          tone: _isDistanceMode ? PillTone.whatsapp : PillTone.info,
          icon: _isDistanceMode ? Icons.shield_rounded : Icons.storefront_rounded,
        ),
      ],
    );
  }

  // ───────────── Étape 1 : saisie ─────────────
  Widget _buildInputStage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChannelSelector(),
        const SizedBox(height: 14),
        if (_isDistanceMode) ...[
          _buildBilateralProtectionCard(),
          const SizedBox(height: 14),
        ],
        _buildAmountDisplay(),
        const SizedBox(height: 12),
        _buildPresets(),
        const SizedBox(height: 16),
        TextField(
          controller: _descController,
          textInputAction: TextInputAction.done,
          maxLength: 60,
          decoration: InputDecoration(
            labelText: 'Nom de l\'article',
            hintText: 'ex : Sac artisanal, chaussures cuir…',
            prefixIcon: Icon(_isDistanceMode ? Icons.local_shipping_outlined : Icons.shopping_bag_outlined),
            counterText: '',
          ),
        ),
        const SizedBox(height: 16),
        _buildPrimaryButton(),
      ],
    );
  }

  Widget _buildBilateralProtectionCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whatsappSoft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.whatsapp.withValues(alpha: 0.3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: AppColors.whatsappDark, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'COMMENT ÇA MARCHE',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.whatsappDark, letterSpacing: 0.5),
                ),
                SizedBox(height: 3),
                Text(
                  '1. Le client paie maintenant. L\'argent est gardé.\n2. Vous envoyez le colis.\n3. L\'argent arrive sur votre compte quand le client reçoit le colis.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textBody, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ChannelOption(
              label: 'En boutique',
              icon: Icons.storefront_rounded,
              selected: !_isDistanceMode,
              color: AppColors.primary,
              onTap: () => setState(() => _isDistanceMode = false),
            ),
          ),
          Expanded(
            child: _ChannelOption(
              label: 'Livraison',
              icon: Icons.shield_rounded,
              selected: _isDistanceMode,
              color: AppColors.whatsappDark,
              onTap: () => setState(() => _isDistanceMode = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountDisplay() {
    final unit = _inputInFcfa ? 'FCFA' : 'SATS';
    final converted = _inputInFcfa ? '≈ ${Formatters.sats(_sats)}' : '≈ ${Formatters.fcfa(_fcfa)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: _accent.withValues(alpha: 0.06), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isDistanceMode ? 'MONTANT À PAYER' : 'MONTANT À ENCAISSER',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Material(
                color: _accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: _toggleUnit,
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swap_horiz_rounded, size: 16, color: _accent),
                        const SizedBox(width: 4),
                        Text(
                          _inputInFcfa ? 'Écrire en sats' : 'Écrire en francs',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _accent),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: _accent,
              letterSpacing: -1,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: _accent.withValues(alpha: 0.28),
              ),
              suffixText: unit,
              suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMuted),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text(
            converted,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPresets() {
    final presets = _inputInFcfa ? _fcfaPresets : AppConstants.quickSatsPresets;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = presets[index];
          final selected = preset == _amountController.text;
          return Material(
            color: selected ? _accent : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _amountController.text = preset);
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? _accent : AppColors.border),
                ),
                child: Text(
                  Formatters.thousands(int.parse(preset)),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textBody,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrimaryButton() {
    final color = _isDistanceMode ? AppColors.whatsapp : AppColors.primary;
    final label = _isDistanceMode ? 'Créer le paiement' : 'Afficher le QR code';
    final enabled = !_isLoading && _sats > 0;

    return SizedBox(
      height: 58,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.45),
          disabledForegroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        onPressed: enabled ? _createInvoice : null,
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isDistanceMode ? Icons.shield_rounded : Icons.qr_code_2_rounded,
                    color: _isDistanceMode ? Colors.white : AppColors.lightningGold,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ───────────── Étape 2 : attente du paiement ─────────────
  Widget _buildWaitingStage() {
    final createdAt = _invoiceCreatedAt;
    final elapsed = createdAt == null ? Duration.zero : DateTime.now().difference(createdAt);
    final bolt11 = _bolt11Invoice ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _accent.withValues(alpha: 0.25), width: 1.5),
            boxShadow: [
              BoxShadow(color: _accent.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              Formatters.sats(_invoiceSats),
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _accent),
                            ),
                          ),
                        ),
                        Text(
                          '≈ ${Formatters.fcfa(_invoiceSats * AppConstants.satRateInFcfa)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _isExpired
                      ? const StatusPill(label: 'Expirée', tone: PillTone.neutral, icon: Icons.timer_off_rounded)
                      : (_isDistanceMode
                          ? const StatusPill(label: 'En attente du client', tone: PillTone.warning, icon: Icons.lock_clock_rounded)
                          : const StatusPill(label: 'En attente', tone: PillTone.warning, icon: Icons.schedule_rounded)),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_invoiceDescription • Réf. ${_invoiceReference ?? '-'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 18),
              if (_isDistanceMode) ...[
                _buildWhatsappHint(),
                const SizedBox(height: 16),
              ],
              _buildQrCode(bolt11),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isExpired) ...[
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _accent),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      _isExpired
                          ? 'Le délai est dépassé. Créez un nouveau paiement.'
                          : (_isDistanceMode
                              ? 'En attente du paiement du client • ${Formatters.elapsed(elapsed)}'
                              : 'En attente du paiement • ${Formatters.elapsed(elapsed)}'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copier', maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: () => _copy(bolt11, 'Code de paiement copié.'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp),
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Partager', maxLines: 1, overflow: TextOverflow.ellipsis),
                onPressed: _shareInvoice,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          onPressed: () {
            if (_isExpired) {
              _resetToInput();
              return;
            }
            _resetToInput();
            _showSnackbar(
              'Paiement en attente 24 h. Le client peut encore payer avec le lien.',
              AppColors.primary,
            );
          },
          icon: Icon(_isExpired ? Icons.add_rounded : Icons.check_rounded, size: 18),
          label: Text(_isExpired ? 'Nouveau paiement' : 'Continuer plus tard'),
        ),
      ],
    );
  }

  Widget _buildWhatsappHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.whatsappSoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.whatsapp.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: AppColors.whatsappDark, size: 24),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Envoyez le lien au client. Il paie, et l\'argent reste gardé jusqu\'à ce qu\'il reçoive le colis.',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: AppColors.textBody, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCode(String bolt11) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - 40).clamp(140.0, 250.0).toDouble();
        return Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isExpired ? 0.25 : 1,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: QrImageView(
                data: bolt11.startsWith('lightning:') ? bolt11 : 'lightning:$bolt11',
                version: QrVersions.auto,
                size: size,
                padding: EdgeInsets.zero,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.primary),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.sapphire,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────── Étape 3 : paiement reçu / Séquestre ─────────────
  Widget _buildPaidStage() {
    final fcfa = _invoiceSats * AppConstants.satRateInFcfa;
    final isEscrowLocked = _isDistanceMode && _escrowStatus == 'locked';
    final isEscrowReleased = _isDistanceMode && _escrowStatus == 'released';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isEscrowLocked ? AppColors.amber : AppColors.success,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isEscrowLocked ? AppColors.amber : AppColors.success).withValues(alpha: 0.15),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 750),
                curve: Curves.elasticOut,
                builder: (context, value, child) => Transform.scale(scale: value, child: child),
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    gradient: isEscrowLocked
                        ? const LinearGradient(colors: [AppColors.amber, AppColors.amberDark])
                        : AppColors.successGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (isEscrowLocked ? AppColors.amber : AppColors.success).withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    isEscrowLocked ? Icons.lock_outline_rounded : Icons.check_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                isEscrowLocked
                    ? 'Argent reçu, en attente de livraison'
                    : (isEscrowReleased ? 'Colis remis, argent disponible' : 'Paiement reçu'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${Formatters.sats(_invoiceSats)}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: isEscrowLocked ? AppColors.amberDark : AppColors.successDark,
                  ),
                ),
              ),
              Text(
                '≈ ${Formatters.fcfa(fcfa)} • ${isEscrowLocked ? "gardé jusqu'à la livraison" : "disponible sur votre compte"}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // CARTE PREUVE SÉQUESTRE & CODE DE DÉBLOCAGE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isEscrowLocked ? const Color(0xFFFFFBEB) : AppColors.successSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isEscrowLocked ? AppColors.amber.withValues(alpha: 0.4) : AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isEscrowLocked ? Icons.shield_rounded : Icons.verified_rounded,
                          color: isEscrowLocked ? AppColors.amberDark : AppColors.successDark,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isEscrowLocked
                                ? 'VOUS POUVEZ ENVOYER LE COLIS'
                                : 'LE CLIENT A REÇU LE COLIS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                              color: isEscrowLocked ? AppColors.amberDark : AppColors.successDark,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEscrowLocked
                          ? 'Le client a payé. L\'argent est gardé. Vous pouvez envoyer le colis.'
                          : 'Le client a reçu le colis. L\'argent est maintenant sur votre compte.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textBody, height: 1.35),
                    ),
                    if (isEscrowLocked) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.pin_rounded, size: 16, color: AppColors.primary),
                                SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Code donné par le client',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _otpInputController,
                              keyboardType: TextInputType.text,
                              textAlign: TextAlign.center,
                              maxLength: 6,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 8,
                                color: AppColors.primaryDark,
                              ),
                              decoration: InputDecoration(
                                counterText: '',
                                hintText: '• • • •',
                                hintStyle: TextStyle(
                                  fontSize: 24,
                                  color: Colors.grey.shade400,
                                  letterSpacing: 8,
                                ),
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                filled: true,
                                fillColor: AppColors.background,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Demandez au client le code affiché sur son reçu, une fois le colis vérifié.',
                              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_isDistanceMode && _escrowStatus == 'released') ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.lock_open_rounded, color: AppColors.successDark, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Colis remis. L\'argent est disponible.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.successDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Réf. ${_invoiceReference ?? '-'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // BOUTON DE DÉBLOCAGE DU SÉQUESTRE LORSQUE LE LIVREUR A REMIS LE COLIS
        if (isEscrowLocked) ...[
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              icon: _isReleasingEscrow
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.lock_open_rounded, size: 20),
              label: Text(
                _isReleasingEscrow ? 'Validation en cours…' : 'Valider la livraison et encaisser',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              onPressed: _isReleasingEscrow ? null : _handleReleaseEscrow,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // BOUTON PARTAGER WHATSAPP
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.whatsapp),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: Text(
              isEscrowLocked ? 'Envoyer le reçu au client' : 'Envoyer la preuve sur WhatsApp',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: _shareProof,
          ),
        ),
        const SizedBox(height: 10),

        // BOUTON NOUVELLE TRANSACTION
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(
              isEscrowLocked ? 'Continuer plus tard' : 'Nouvelle vente',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () {
              _resetToInput();
              if (isEscrowLocked) {
                _showSnackbar(
                  'Allez dans Reçus pour entrer le code à la livraison.',
                  AppColors.primary,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class _ChannelOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ChannelOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? color : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

