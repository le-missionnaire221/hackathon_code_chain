import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import 'common/app_bottom_sheet.dart';

class BlinkAddressSheet extends StatelessWidget {
  const BlinkAddressSheet({super.key});

  static void show(BuildContext context) {
    AppBottomSheet.show(context, const BlinkAddressSheet());
  }

  @override
  Widget build(BuildContext context) {
    const address = AppConstants.blinkLightningAddress;

    void copy() {
      Clipboard.setData(const ClipboardData(text: address));
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adresse Lightning copiée !'), backgroundColor: AppColors.primary),
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
          'Recevoir des paiements',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          'Partagez cette adresse à vos clients et à la diaspora : ils vous paient depuis n\'importe quel pays.',
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
                  data: 'lightning:$address',
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
                  const Expanded(
                    child: Text(
                      address,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 14),
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
            _Feature(icon: Icons.money_off_rounded, label: '0 frais'),
            _Feature(icon: Icons.speed_rounded, label: 'Instantané'),
            _Feature(icon: Icons.public_rounded, label: 'Mondial'),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.success),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textBody)),
        ],
      ),
    );
  }
}
