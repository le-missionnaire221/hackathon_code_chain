import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/services/session.dart';
import 'common/app_bottom_sheet.dart';

class BlinkAddressSheet extends StatelessWidget {
  const BlinkAddressSheet({super.key});

  static String get receiveAddress {
    final phone = (Session.phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return 'compte@paychain.app';
    return '$phone@paychain.app';
  }

  static void show(BuildContext context) {
    AppBottomSheet.show(context, const BlinkAddressSheet());
  }

  @override
  Widget build(BuildContext context) {
    final address = receiveAddress;
    final qrPayload = 'lightning:$address';

    void copy() {
      Clipboard.setData(ClipboardData(text: address));
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse PayChain copiée !'), backgroundColor: AppColors.primary),
      );
    }

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
          'Montrez ce QR ou partagez votre adresse. Un autre compte PayChain scanne et vous envoie un montant.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 18),
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
            onTap: copy,
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
        const SizedBox(height: 14),
        const Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _Feature(icon: Icons.qr_code_scanner_rounded, label: 'Scannable'),
            _Feature(icon: Icons.speed_rounded, label: 'Instantané'),
            _Feature(icon: Icons.account_balance_wallet_rounded, label: 'PayChain'),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ),
      ],
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Feature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
