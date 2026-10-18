import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/branding_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _dropController;
  late final Animation<Offset> _dropAnimation;
  late final Animation<double> _fadeAnimation;

  Timer? _typewriterTimer;
  String _displayedText = '';
  final String _targetText = BrandingService.appName.isNotEmpty ? BrandingService.appName : 'RAK TAK CASH';
  bool _showSubtitle = false;

  @override
  void initState() {
    super.initState();

    // 1. Animation du logo qui tombe du haut avec rebond réaliste
    _dropController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _dropAnimation = Tween<Offset>(
      begin: const Offset(0, -3.5), // Tombe depuis le haut
      end: Offset.zero,             // Atterrit au centre
    ).animate(
      CurvedAnimation(
        parent: _dropController,
        curve: Curves.bounceOut,    // Rebondissement à l'arrivée
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _dropController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _dropController.forward();

    // 2. Déclenchement de l'affichage lettre par lettre rapide
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _startTypewriter();
    });
  }

  void _startTypewriter() {
    int index = 0;
    _typewriterTimer = Timer.periodic(const Duration(milliseconds: 55), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < _targetText.length) {
        index++;
        setState(() {
          _displayedText = _targetText.substring(0, index);
        });
      } else {
        timer.cancel();
        setState(() {
          _showSubtitle = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _dropController.dispose();
    _typewriterTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox.expand(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),

              // Logo qui tombe avec rebond
              SlideTransition(
                position: _dropAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Image.asset(
                    'assets/logo_final.png',
                    height: 125,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Image.asset(
                      BrandingService.localLogoAsset,
                      height: 125,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.account_balance_wallet_rounded,
                        size: 80,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 22),

              // Nom affiché lettre par lettre de façon rapide
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(
                    _displayedText,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: AppColors.sapphire,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Sous-titre en fondu doux
              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _showSubtitle ? 1.0 : 0.0,
                child: const Text(
                  'Paiements Lightning & Séquestre WhatsApp',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Spinner discret en bas
              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _showSubtitle ? 1.0 : 0.0,
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              AnimatedOpacity(
                duration: const Duration(milliseconds: 350),
                opacity: _showSubtitle ? 1.0 : 0.0,
                child: const Text(
                  '⚡ Dakar 2026',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
