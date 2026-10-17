import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';

class SettingsTab extends StatelessWidget {
  final String backendUrl;
  final bool isBackendOnline;
  final String? backendPingLatency;
  final Function(String newUrl) onBackendUrlChanged;
  final Future<void> Function() onTestPing;

  const SettingsTab({
    super.key,
    required this.backendUrl,
    required this.isBackendOnline,
    required this.backendPingLatency,
    required this.onBackendUrlChanged,
    required this.onTestPing,
  });

  @override
  Widget build(BuildContext context) {
    final urlController = TextEditingController(text: backendUrl);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Supervision & Nœud', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            const Text('Vérification en direct de la connectivité Express et Bitnob', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 20),

            // État du système
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  _buildStatusRow('Serveur Express', isBackendOnline ? 'En ligne 🟢' : 'Inaccessible 🔴'),
                  const Divider(height: 18, color: AppColors.border),
                  _buildStatusRow('Latence Ping Backend', backendPingLatency ?? 'Calcul en cours...'),
                  const Divider(height: 18, color: AppColors.border),
                  _buildStatusRow('Moteur API Bitnob', 'Sandbox Testnet ⚡'),
                  const Divider(height: 18, color: AppColors.border),
                  _buildStatusRow('Sécurité Webhook', 'HMAC-SHA512 🔒'),
                  const Divider(height: 18, color: AppColors.border),
                  _buildStatusRow('Règlement Automatique', 'Auto-Settle Activé ✅'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.network_check_rounded, color: AppColors.primary),
                label: const Text('Tester la Connectivité en Direct', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await onTestPing();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Test réussi : Latence $backendPingLatency'), backgroundColor: AppColors.primary),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 20),

            // Configuration URL
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('URL du Serveur Backend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                        onPressed: () {
                          onBackendUrlChanged(urlController.text.trim());
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('URL enregistrée : ${urlController.text.trim()}'), backgroundColor: AppColors.primary),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Web (localhost:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          urlController.text = AppConstants.defaultWebBackendUrl;
                          onBackendUrlChanged(AppConstants.defaultWebBackendUrl);
                        },
                      ),
                      ActionChip(
                        label: const Text('Émulateur (10.0.2.2:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          urlController.text = AppConstants.defaultAndroidBackendUrl;
                          onBackendUrlChanged(AppConstants.defaultAndroidBackendUrl);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // À propos du hackathon
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.chipBackground,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppConstants.hackathonName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                  SizedBox(height: 4),
                  Text(
                    'Application Fintech développée par ${AppConstants.developerName} (${AppConstants.developerGithub}) avec Bitnob API & Flutter.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
