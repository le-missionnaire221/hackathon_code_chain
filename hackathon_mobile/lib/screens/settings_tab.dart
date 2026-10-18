import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/session.dart';
import '../core/utils/formatters.dart';
import '../widgets/blink_address_sheet.dart';
import '../widgets/common/info_row.dart';
import '../widgets/common/status_pill.dart';

class SettingsTab extends StatefulWidget {
  final bool isBackendOnline;
  final String? backendPingLatency;
  final Future<void> Function() onTestPing;
  final String accountName;
  final String accountPhone;
  final Future<void> Function() onLogout;
  final int balanceSats;
  final double balanceFcfa;
  final int escrowSats;
  final int paidCount;
  final int receivedCount;
  final int totalTransactions;
  final String backendUrl;
  final Future<void> Function() onRefresh;

  const SettingsTab({
    super.key,
    required this.isBackendOnline,
    required this.backendPingLatency,
    required this.onTestPing,
    required this.accountName,
    required this.accountPhone,
    required this.onLogout,
    this.balanceSats = 0,
    this.balanceFcfa = 0,
    this.escrowSats = 0,
    this.paidCount = 0,
    this.receivedCount = 0,
    this.totalTransactions = 0,
    required this.backendUrl,
    required this.onRefresh,
  });

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _isTestingPing = false;

  String get _initials {
    final parts = widget.accountName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'PC';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  String get _roleLabel {
    final role = (Session.role ?? 'user').toLowerCase();
    if (role == 'admin') return 'Administrateur';
    return 'Marchand';
  }

  String get _receiveAddress => BlinkAddressSheet.receiveAddress;

  String get _memberSince {
    // Session n’expose pas createdAt ; on affiche une info stable pour la démo.
    return 'Compte RAK TAK CASH actif';
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
              ? 'Connectivité OK (${widget.backendPingLatency})'
              : 'Serveur inaccessible.',
        ),
        backgroundColor: widget.isBackendOnline ? AppColors.success : AppColors.error,
      ),
    );
  }

  void _copy(String value, String message) {
    Clipboard.setData(ClipboardData(text: value));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final phone = widget.accountPhone.isEmpty ? '—' : '+${widget.accountPhone}';

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: widget.onRefresh,
        color: AppColors.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Profil',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                ),
                StatusPill(
                  label: widget.isBackendOnline ? 'En ligne' : 'Hors ligne',
                  tone: widget.isBackendOnline ? PillTone.success : PillTone.error,
                  showDot: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Carte identité
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.walletGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 2),
                    ),
                    child: Text(
                      _initials,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.accountName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone,
                    style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Stats profil
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Solde',
                    value: Formatters.fcfa(widget.balanceFcfa),
                    subtitle: Formatters.sats(widget.balanceSats),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Reçu',
                    value: '${widget.receivedCount}',
                    subtitle: 'entrées',
                    accent: AppColors.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    label: 'Payé',
                    value: '${widget.paidCount}',
                    subtitle: 'sorties',
                    accent: AppColors.error,
                  ),
                ),
              ],
            ),
            if (widget.escrowSats > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.amberLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
                ),
                child: Text(
                  'Séquestre en cours : ${Formatters.sats(widget.escrowSats)}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.amberDark),
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Adresse Recevoir
            _SectionCard(
              title: 'ADRESSE RECEVOIR',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Votre QR Recevoir. Partagez-la pour recevoir de l’argent d’un autre compte.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: AppColors.chipBackground,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => _copy(_receiveAddress, 'Adresse copiée !'),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Row(
                          children: [
                            const Icon(Icons.alternate_email_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _receiveAddress,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  fontSize: 13.5,
                                ),
                              ),
                            ),
                            const Icon(Icons.copy_rounded, size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: () => BlinkAddressSheet.show(
                        context,
                        backendUrl: widget.backendUrl,
                        currentBalanceSats: widget.balanceSats,
                        onReceived: widget.onRefresh,
                      ),
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Afficher mon QR Recevoir'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Infos compte
            _SectionCard(
              title: 'INFORMATIONS DU COMPTE',
              child: Column(
                children: [
                  InfoRow(label: 'Nom complet', value: widget.accountName),
                  const Divider(),
                  InfoRow(
                    label: 'Téléphone',
                    value: phone,
                    onCopy: widget.accountPhone.isEmpty
                        ? null
                        : () => _copy('+${widget.accountPhone}', 'Téléphone copié !'),
                  ),
                  const Divider(),
                  InfoRow(label: 'Rôle', value: _roleLabel),
                  const Divider(),
                  InfoRow(label: 'Statut', value: _memberSince),
                  const Divider(),
                  InfoRow(
                    label: 'Transactions',
                    value: '${widget.totalTransactions} au total',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Connexion (compact)
            _SectionCard(
              title: 'CONNEXION & SÉCURITÉ',
              child: Column(
                children: [
                  InfoRow(
                    label: 'API',
                    value: widget.isBackendOnline ? 'Connectée' : 'Hors ligne',
                    valueColor: widget.isBackendOnline ? AppColors.successDark : AppColors.error,
                  ),
                  const Divider(),
                  InfoRow(
                    label: 'Latence',
                    value: widget.backendPingLatency ?? 'Non testé',
                  ),
                  const Divider(),
                  const InfoRow(label: 'Lightning', value: 'Bitnob sandbox'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      icon: _isTestingPing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            )
                          : const Icon(Icons.network_check_rounded, size: 18),
                      label: Text(_isTestingPing ? 'Test…' : 'Tester la connexion'),
                      onPressed: _isTestingPing ? null : _handleTestPing,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Hackathon
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.card,
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
                        decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppConstants.hackathonName,
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
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
                  const SizedBox(height: 10),
                  const Text(
                    'RAK TAK CASH — paiements Lightning pour commerçants (TPE, livraison, Recevoir).',
                    style: TextStyle(fontSize: 12.5, color: AppColors.textBody, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '${AppConstants.developerName} · ${AppConstants.developerGithub}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: widget.onLogout,
                icon: const Icon(Icons.logout_rounded, color: AppColors.error),
                label: const Text('Se déconnecter', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final Color? accent;

  const _StatTile({
    required this.label,
    required this.value,
    required this.subtitle,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: accent ?? AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
