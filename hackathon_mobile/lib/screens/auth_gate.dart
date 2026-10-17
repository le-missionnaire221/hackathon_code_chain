import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/services/api_service.dart';
import '../core/services/session.dart';
import 'auth_screen.dart';
import 'main_navigation_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  bool _loggedIn = false;

  @override
  void initState() {
    super.initState();
    ApiService.onUnauthorized = _handleUnauthorized;
    _restore();
  }

  Future<void> _restore() async {
    final ok = await Session.restore();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _loggedIn = ok;
    });
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
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (!_loggedIn) {
      return AuthScreen(onSuccess: () => setState(() => _loggedIn = true));
    }
    return MainNavigationScreen(onLogout: _logout);
  }
}
