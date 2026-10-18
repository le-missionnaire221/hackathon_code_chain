import 'dart:async';
import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/branding_service.dart';
import '../core/services/deep_link_service.dart';
import '../core/services/session.dart';
import '../widgets/buyer_payment_sheet.dart';
import 'auth_screen.dart';
import 'main_navigation_screen.dart';
import 'splash_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;
  StreamSubscription<String>? _linkSub;

  @override
  void initState() {
    super.initState();
    ApiService.onUnauthorized = _handleUnauthorized;
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final startTime = DateTime.now();

    await DeepLinkService.instance.start();
    _linkSub = DeepLinkService.instance.payCodes.listen(_onPayCode);
    await BrandingService.restore();
    await BrandingService.loadFromBackend(AppConstants.productionBackendUrl);
    final ok = await Session.restore();

    // Durée minimale d'affichage du splash screen pour un rendu fluide et pro
    final elapsed = DateTime.now().difference(startTime);
    final remaining = 2300 - elapsed.inMilliseconds;
    if (remaining > 0) {
      await Future.delayed(Duration(milliseconds: remaining));
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _loggedIn = ok;
    });
    if (ok) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingPay());
    }
  }

  void _onPayCode(String code) {
    if (!_loggedIn) return;
    _openPaySheet(code);
  }

  void _openPendingPay() {
    final code = DeepLinkService.instance.takePending();
    if (code != null && code.isNotEmpty) {
      _openPaySheet(code);
    }
  }

  void _openPaySheet(String code) {
    if (!mounted) return;
    BuyerPaymentSheet.show(
      context,
      backendUrl: Session.backendUrl ?? AppConstants.productionBackendUrl,
      initialCode: code,
    );
  }

  Future<void> _handleUnauthorized() async {
    if (!_loggedIn) return;
    await Session.clear();
    if (!mounted) return;
    setState(() => _loggedIn = false);
  }

  Future<void> _logout() async {
    await Session.clear();
    if (!mounted) return;
    setState(() => _loggedIn = false);
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SplashScreen();
    }
    if (!_loggedIn) {
      return AuthScreen(
        onSuccess: () {
          setState(() => _loggedIn = true);
          WidgetsBinding.instance.addPostFrameCallback((_) => _openPendingPay());
        },
      );
    }
    return MainNavigationScreen(onLogout: _logout);
  }
}
