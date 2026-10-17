import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../widgets/common/info_row.dart';
import '../widgets/common/status_pill.dart';

class SettingsTab extends StatefulWidget {
  final bool isBackendOnline;
  final String? backendPingLatency;
  final Future<void> Function() onTestPing;
  final String accountName;
  final String accountPhone;
  final Future<void> Function() onLogout;

  const SettingsTab({
    super.key,
    required this.isBackendOnline,
    required this.backendPingLatency,
    required this.onTestPing,
    required this.accountName,
    required this.accountPhone,
    required this.onLogout,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isTestingPing = false;

  Future<void> _handleTestPing() async {
    setState(() => _isTestingPing = true);
    HapticFeedback.lightImpact();
    await widget.onTestPing();
    if (!mounted) return;
    setState(() => _isTestingPing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.isBackendOnline
              ? 'Connectivité réussie (latence : ${widget.backendPingLatency})'
              : 'Serveur inaccessible. Vérifiez le backend Node.js.',
        ),
        backgroundColor: widget.isBackendOnline ? AppColors.success : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          // En-tête
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Supervision & Nœud',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Diagnostic d\'infrastructure Lightning & API',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: widget.isBackendOnline ? 'En ligne' : 'Hors ligne',
                tone: widget.isBackendOnline ? PillTone.success : PillTone.error,
                showDot: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'COMPTE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 12),
                InfoRow(label: 'Nom', value: widget.accountName),
                const Divider(),
                InfoRow(
                  label: 'Téléphone',
                  value: widget.accountPhone.isEmpty ? '—' : '+${widget.accountPhone}',
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                    label: const Text('Se déconnecter', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Carte Statut Système
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'ÉTAT DE L\'INFRASTRUCTURE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                InfoRow(
                  label: 'Serveur Express',
                  value: widget.isBackendOnline ? 'En ligne 🟢' : 'Inaccessible 🔴',
                  valueColor: widget.isBackendOnline ? AppColors.successDark : AppColors.error,
                ),
                const Divider(),
                InfoRow(
                  label: 'Latence ping backend',
                  value: widget.backendPingLatency ?? 'Non testé',
                ),
                const Divider(),
                const InfoRow(
                  label: 'Moteur API Bitnob',
                  value: 'Sandbox Testnet ⚡',
                ),
                const Divider(),
                const InfoRow(
                  label: 'Sécurité Webhooks',
                  value: 'HMAC-SHA512 🔒',
                ),
                const Divider(),
                const InfoRow(
                  label: 'Règlement automatique',
                  value: 'Auto-Settle actif ✅',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Bouton test ping
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              icon: _isTestingPing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                    )
                  : const Icon(Icons.network_check_rounded, size: 20),
              label: Text(_isTestingPing ? 'Test en cours…' : 'Tester la connectivité en direct'),
              onPressed: _isTestingPing ? null : _handleTestPing,
            ),
          ),
          const SizedBox(height: 22),

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bolt_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'BITNOB SANDBOX',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                InfoRow(label: 'Réseau', value: 'Lightning · sandbox'),
                Divider(),
                InfoRow(label: 'Serveur', value: 'En ligne, fixe'),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // Carte Mémoire & Hackathon
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.chipBackground, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppConstants.hackathonName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            AppConstants.hackathonLocation,
                            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Solution TPE & Commerce Social Bitcoin Lightning développée pour les commerçants du Sénégal et d\'Afrique de l\'Ouest.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textBody, height: 1.4),
                ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 15, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      AppConstants.developerName,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.textPrimary),
                    ),
                    SizedBox(width: 6),
                    Text(
                      '(${AppConstants.developerGithub})',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
