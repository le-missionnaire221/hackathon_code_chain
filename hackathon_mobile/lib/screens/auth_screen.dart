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

class _AuthScreenState extends State<AuthScreen> {
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

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (_isRegister && _nameController.text.trim().length < 2) {
      setState(() => _error = 'Veuillez renseigner votre nom complet.');
      return;
    }
    if (phone.length < 9 || password.length < 6) {
      setState(() => _error = 'Numéro de téléphone et mot de passe (6 caractères min) requis.');
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
        _error = data?['error']?.toString() ?? 'Connexion impossible. Vérifiez vos identifiants.';
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Logo libre en haut
                Center(
                  child: Image.asset(
                    'assets/logo_final.png',
                    height: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      BrandingService.localLogoAsset,
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 72,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // 2. Nom de l'application en bas du logo
                Text(
                  BrandingService.appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: AppColors.sapphire,
                  ),
                ),

                const SizedBox(height: 32),

                // 3. Switcher discret (Se connecter / Créer un compte)
                _buildSwitcher(),

                const SizedBox(height: 28),

                // 4. Formulaire épuré type application en production
                if (_isRegister) ...[
                  _buildInputLabel('Nom complet'),
                  TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      hintText: 'Ex: Idrissa Coulibaly',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: AppColors.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                _buildInputLabel('Numéro de téléphone'),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: '77 000 00 00',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2F6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            '+221',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sapphire,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                _buildInputLabel('Mot de passe'),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.textSecondary),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFDC2626),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 26),

                // 5. Bouton Principal Production
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            _isRegister ? 'Créer un compte' : 'Se connecter',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.sapphire,
        ),
      ),
    );
  }

  Widget _buildSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
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
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isRegister ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: !_isRegister
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Se connecter',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !_isRegister ? FontWeight.w800 : FontWeight.w600,
                    color: !_isRegister ? AppColors.primary : const Color(0xFF64748B),
                  ),
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
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isRegister ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _isRegister
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  'Créer un compte',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _isRegister ? FontWeight.w800 : FontWeight.w600,
                    color: _isRegister ? AppColors.primary : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
