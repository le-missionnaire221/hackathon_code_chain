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
      setState(() => _error = 'Indiquez votre nom complet.');
      return;
    }
    if (phone.length < 9 || password.length < 6) {
      setState(() => _error = 'Téléphone et mot de passe (6 caractères minimum) requis.');
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
        _error = data?['error']?.toString() ?? 'Serveur injoignable. Vérifiez que le backend tourne.';
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
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  BrandingService.localLogoAsset,
                  height: 88,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(
                    BrandingService.appName,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              BrandingService.appName,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            Text(
              _isRegister ? 'Créez votre portefeuille' : 'Connectez-vous à votre compte',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            if (_isRegister) ...[
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                hintText: '77 000 00 00',
                prefixIcon: Icon(Icons.phone_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 18),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isRegister ? 'Créer mon compte' : 'Se connecter'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() {
                        _isRegister = !_isRegister;
                        _error = null;
                      }),
              child: Text(_isRegister ? 'J’ai déjà un compte' : 'Créer un compte'),
            ),
          ],
        ),
      ),
    );
  }
}
