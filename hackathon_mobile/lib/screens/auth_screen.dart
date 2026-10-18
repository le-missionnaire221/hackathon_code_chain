import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/branding_service.dart';
import '../core/services/session.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onSuccess;

  const AuthScreen({super.key, required this.onSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isRegister = false;
  bool _isLoading = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _fillDemoAccount({required String phone, required String password, String? name}) {
    HapticFeedback.lightImpact();
    setState(() {
      _phoneController.text = phone;
      _passwordController.text = password;
      if (name != null) _nameController.text = name;
      _error = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('⚡ Identifiants chargés : $phone'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.sapphire,
      ),
    );
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (_isRegister && _nameController.text.trim().length < 2) {
      setState(() => _error = 'Indiquez votre nom ou le nom de votre boutique.');
      return;
    }
    if (phone.length < 9 || password.length < 6) {
      setState(() => _error = 'Téléphone (min 9 chiffres) et mot de passe (min 6 caractères) requis.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    const backendUrl = AppConstants.productionBackendUrl;
    final data = _isRegister
        ? await ApiService.register(
            backendUrl,
            phone: phone,
            password: password,
            fullName: _nameController.text.trim(),
          )
        : await ApiService.login(backendUrl, phone: phone, password: password);

    if (!mounted) return;

    final token = data?['token']?.toString();
    final user = data?['user'];
    if (token == null || user is! Map) {
      setState(() {
        _isLoading = false;
        _error = data?['error']?.toString() ?? 'Serveur injoignable. Vérifiez la connexion.';
      });
      return;
    }

    await Session.save(
      token: token,
      phone: user['phone']?.toString() ?? phone,
      fullName: user['fullName']?.toString() ?? _nameController.text.trim(),
      role: user['role']?.toString() ?? 'user',
    );
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    widget.onSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final logoUrl = BrandingService.absoluteLogoUrl(AppConstants.productionBackendUrl);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),

              // Hero Branding Card
              _buildHeroHeader(logoUrl),

              const SizedBox(height: 24),

              // Segmented Tab Switcher (Connexion vs Inscription)
              _buildSegmentedTabs(),

              const SizedBox(height: 20),

              // Formulaire Principal
              _buildFormCard(),

              const SizedBox(height: 22),

              // Démo Rapide Hackathon / Jury
              _buildDemoAccountsCard(),

              const SizedBox(height: 24),

              // Badges de Réassurance Sécurité
              _buildSecurityTrustRow(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(String logoUrl) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.sapphire, Color(0xFF003BB5), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo avec bordure or et effet lumineux
          Container(
            width: 84,
            height: 84,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.lightningGold.withValues(alpha: 0.8), width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.lightningGold.withValues(alpha: 0.3),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: logoUrl.isNotEmpty
                  ? Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                    )
                  : Image.asset(
                      BrandingService.localLogoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Titre officiel
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                BrandingService.appName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.lightningGold,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'CASH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: AppColors.sapphire,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          Text(
            _isRegister
                ? 'Rejoignez les marchands & acheteurs de Dakar ⚡'
                : 'Paiements Lightning & Séquestre WhatsApp 🛡️',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: const Text(
        '⚡',
        style: TextStyle(fontSize: 32),
      ),
    );
  }

  Widget _buildSegmentedTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isRegister) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isRegister = false;
                    _error = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_isRegister ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !_isRegister
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.login_rounded,
                      size: 16,
                      color: !_isRegister ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Se connecter',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: !_isRegister ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isRegister) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _isRegister = true;
                    _error = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _isRegister ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _isRegister
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_add_rounded,
                      size: 16,
                      color: _isRegister ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Créer un compte',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _isRegister ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isRegister) ...[
            _buildFieldLabel('Nom ou Enseigne Commerciale'),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'Ex: Boutique Sandaga ou Idrissa C.',
                prefixIcon: _buildIconBox(Icons.storefront_rounded, AppColors.primary),
              ),
            ),
            const SizedBox(height: 16),
          ],

          _buildFieldLabel('Numéro de Téléphone'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: '77 000 00 00',
              prefixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.chipBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '🇸🇳 +221',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.sapphire),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          _buildFieldLabel('Mot de Passe Sécurisé'),
          TextField(
            controller: _passwordController,
            obscureText: _obscure,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: 'Au moins 6 caractères',
              prefixIcon: _buildIconBox(Icons.lock_rounded, AppColors.amber),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),

          // Bouton CTA Principal
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 4,
                shadowColor: AppColors.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _isRegister ? Icons.rocket_launch_rounded : Icons.bolt_rounded,
                          color: AppColors.lightningGold,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRegister ? 'Créer mon Portefeuille' : 'Se Connecter à l\'App',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildIconBox(IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildDemoAccountsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightningGold.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: AppColors.lightningGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bolt_rounded, size: 16, color: AppColors.sapphire),
              ),
              const SizedBox(width: 8),
              const Text(
                'Comptes Démo (Accès Rapide Jury)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sapphire,
                ),
              ),
              const Spacer(),
              const Text(
                '1-CLIC',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.amberDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildDemoChip(
                label: '🏪 Marchand Sandaga',
                onTap: () => _fillDemoAccount(
                  phone: '771234567',
                  password: 'pass123456',
                  name: 'Boutique Sandaga',
                ),
              ),
              _buildDemoChip(
                label: '🛍️ Client Dakar',
                onTap: () => _fillDemoAccount(
                  phone: '779876543',
                  password: 'pass123456',
                  name: 'Client Acheteur',
                ),
              ),
              _buildDemoChip(
                label: '🛡️ Super-Admin',
                onTap: () => _fillDemoAccount(
                  phone: '221770000001',
                  password: 'RakTakCashAdmin2026',
                  name: 'Administrateur RAK TAK CASH',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoChip({required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityTrustRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTrustPill('⚡ Lightning 0% Frais'),
        const SizedBox(width: 8),
        _buildTrustPill('🛡️ Séquestre Bilatéral'),
        const SizedBox(width: 8),
        _buildTrustPill('🇸🇳 Dakar 2026'),
      ],
    );
  }

  Widget _buildTrustPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}
