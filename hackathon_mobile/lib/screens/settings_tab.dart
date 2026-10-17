import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../widgets/common/info_row.dart';
import '../widgets/common/status_pill.dart';

class SettingsTab extends StatefulWidget {
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
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  late final TextEditingController _urlController;
  bool _isTestingPing = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.backendUrl);
  }

  @override
  void didUpdateWidget(covariant SettingsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.backendUrl != widget.backendUrl &&
        _urlController.text != widget.backendUrl) {
      _urlController.text = widget.backendUrl;
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

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

  void _applyUrl(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return;
    _urlController.text = clean;
    widget.onBackendUrlChanged(clean);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('URL enregistrée : $clean'),
        backgroundColor: AppColors.primary,
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

          // Configuration URL Backend
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
                const Row(
                  children: [
                    Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'SERVEUR BACKEND',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _urlController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _applyUrl,
                  decoration: InputDecoration(
                    labelText: 'URL du serveur Express',
                    hintText: 'http://localhost:5000',
                    prefixIcon: const Icon(Icons.dns_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Enregistrer',
                      icon: const Icon(Icons.check_circle_rounded, color: AppColors.primary),
                      onPressed: () => _applyUrl(_urlController.text),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.language_rounded, size: 16),
                      label: const Text('Web (localhost:5000)', style: TextStyle(fontSize: 12)),
                      onPressed: () => _applyUrl(AppConstants.defaultWebBackendUrl),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.phone_android_rounded, size: 16),
                      label: const Text('Android (10.0.2.2:5000)', style: TextStyle(fontSize: 12)),
                      onPressed: () => _applyUrl(AppConstants.defaultAndroidBackendUrl),
                    ),
                  ],
                ),
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
