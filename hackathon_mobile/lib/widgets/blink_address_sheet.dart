import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/session.dart';
import '../core/utils/formatters.dart';
import 'common/app_bottom_sheet.dart';

class BlinkAddressSheet extends StatefulWidget {
  final String backendUrl;
  final int initialBalanceSats;
  final Future<void> Function()? onReceived;

  const BlinkAddressSheet({
    super.key,
    required this.backendUrl,
    required this.initialBalanceSats,
    this.onReceived,
  });

  static String get receiveAddress {
    final phone = (Session.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return 'compte@raktak.cash';
    return '$phone@raktak.cash';
  }

  static Future<void> show(
    BuildContext context, {
    required String backendUrl,
    required int currentBalanceSats,
    Future<void> Function()? onReceived,
  }) {
    return AppBottomSheet.show(
      context,
      BlinkAddressSheet(
        backendUrl: backendUrl,
        initialBalanceSats: currentBalanceSats,
        onReceived: onReceived,
      ),
    );
  }

  @override
  State<BlinkAddressSheet> createState() => _BlinkAddressSheetState();
}

class _BlinkAddressSheetState extends State<BlinkAddressSheet> {
  Timer? _pollTimer;
  late int _baselineSats;
  int? _receivedSats;
  double? _receivedFcfa;
  bool _received = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _baselineSats = widget.initialBalanceSats;
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _checkIncoming());
    // Premier check un peu plus tôt
    Future.delayed(const Duration(milliseconds: 800), _checkIncoming);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkIncoming() async {
    if (!mounted || _received || _closing) return;
    final wallet = await ApiService.getWalletData(widget.backendUrl);
    if (!mounted || wallet == null || _received) return;

    final delta = wallet.balanceSats - _baselineSats;
    if (delta > 0) {
      _pollTimer?.cancel();
      setState(() {
        _received = true;
        _receivedSats = delta;
        _receivedFcfa = delta * AppConstants.satRateInFcfa;
      });
      HapticFeedback.heavyImpact();
      await widget.onReceived?.call();
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 1800));
      if (!mounted || _closing) return;
      _closing = true;
      Navigator.of(context).pop();
    }
  }

  void _copy() {
    final address = BlinkAddressSheet.receiveAddress;
    Clipboard.setData(ClipboardData(text: address));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Adresse RAK TAK CASH copiée !'), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_received) {
      return _buildSuccess();
    }
    return _buildWaiting();
  }

  Widget _buildSuccess() {
    final sats = _receivedSats ?? 0;
    final fcfa = _receivedFcfa ?? (sats * AppConstants.satRateInFcfa);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: AppColors.successGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Paiement reçu',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          '+${Formatters.fcfa(fcfa)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.success),
        ),
        const SizedBox(height: 4),
        Text(
          '≈ ${Formatters.sats(sats)}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        const Text(
          'Votre solde a été mis à jour automatiquement.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () {
              _closing = true;
              Navigator.pop(context);
            },
            child: const Text('OK'),
          ),
        ),
      ],
    );
  }

  Widget _buildWaiting() {
    final address = BlinkAddressSheet.receiveAddress;
    final qrPayload = 'lightning:$address';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(gradient: AppColors.walletGradient, shape: BoxShape.circle),
            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 30),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Recevoir de l’argent',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Montrez ce QR. Dès qu’un autre compte paie, cet écran se valide tout seul.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.amberLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.amberDark),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'En attente d’un paiement…',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.amberDark),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final size = (constraints.maxWidth - 48).clamp(140.0, 220.0).toDouble();
            return Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: AppColors.border, width: 1.5),
                ),
                child: QrImageView(
                  data: qrPayload,
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
            );
          },
        ),
        const SizedBox(height: 16),
        Material(
          color: AppColors.chipBackground,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: _copy,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ),
      ],
    );
  }
}
