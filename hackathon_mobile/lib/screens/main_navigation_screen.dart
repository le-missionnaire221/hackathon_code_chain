import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../core/services/branding_service.dart';
import '../core/services/session.dart';
import '../core/utils/formatters.dart';
import '../models/transaction_item.dart';
import 'wallet_tab.dart';
import 'pos_tab.dart';
import 'history_tab.dart';
import 'settings_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  final Future<void> Function() onLogout;

  const MainNavigationScreen({super.key, required this.onLogout});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  String backendUrl = AppConstants.productionBackendUrl;
  Timer? _walletPollTimer;

  bool _isBalanceVisible = true;
  bool _isLoadingWallet = false;
  int _balanceSats = 0;
  double _balanceFcfa = 0.0;
  int _escrowSats = 0;
  double _escrowFcfa = 0.0;
  int _escrowInvoicesCount = 0;
  int _btcPriceFcfa = 64850000;
  int _paidInvoicesCount = 0;
  int _totalInvoicesCount = 0;

  List<TransactionItem> _transactions = [];
  String? _backendPingLatency;
  bool _isBackendOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchRealWalletData();
    _testBackendPing();
    _walletPollTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted || _currentIndex != 0) return;
      _fetchRealWalletData(silent: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _walletPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchRealWalletData(silent: true);
    }
  }

  Future<void> _fetchRealWalletData({bool silent = false}) async {
    if (_isLoadingWallet) return;
    if (!silent) setState(() => _isLoadingWallet = true);
    final wallet = await ApiService.getWalletData(backendUrl);
    if (!mounted) return;

    setState(() {
      if (!silent) _isLoadingWallet = false;
      if (wallet != null) {
        _balanceSats = wallet.balanceSats;
        _balanceFcfa = wallet.balanceFcfa;
        _escrowSats = wallet.escrowSats;
        _escrowFcfa = wallet.escrowFcfa;
        _escrowInvoicesCount = wallet.escrowInvoicesCount;
        _btcPriceFcfa = wallet.btcPriceFcfa;
        _paidInvoicesCount = wallet.paidInvoicesCount;
        _totalInvoicesCount = wallet.totalInvoices;
        _transactions = wallet.transactions;
        _isBackendOnline = true;
      } else if (!silent) {
        _isLoadingWallet = false;
      }
    });
  }

  Future<void> _testBackendPing() async {
    final latency = await ApiService.pingBackend(backendUrl);
    if (!mounted) return;
    setState(() {
      _backendPingLatency = latency ?? 'Inaccessible';
      _isBackendOnline = latency != null;
    });
  }

  void _goTo(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
    if (index == 0 || index == 2 || index == 3) _fetchRealWalletData();
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.isEmpty) return 'RT';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'.toUpperCase();
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter de votre compte ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Déconnexion', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Image.asset('assets/logo_final.png', height: 28, errorBuilder: (_, __, ___) => const Icon(Icons.bolt_rounded)),
            const SizedBox(width: 8),
            Text(BrandingService.appName, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Passerelle de paiements Lightning Network & Séquestre WhatsApp pour les commerçants et acheteurs d\'Afrique de l\'Ouest.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text('⚡ Zéro commission bancaire (0%)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Text('🛡️ Séquestre bilatéral anti-arnaque', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const Text('🇸🇳 Conçu pour Dakar 2026', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            Text('Version 1.0.0 • ${AppConstants.developerName}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // Barre en haut (AppBar) avec Logo au milieu et Menu à gauche
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: AppColors.sapphire, size: 28),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Menu',
          ),
        ),
        title: Image.asset(
          'assets/logo_final.png',
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Image.asset(
            BrandingService.localLogoAsset,
            height: 38,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Text(
              BrandingService.appName,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
                color: AppColors.sapphire,
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.sapphire, size: 22),
            onPressed: () {
              HapticFeedback.lightImpact();
              _fetchRealWalletData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚡ Données actualisées'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            tooltip: 'Actualiser',
          ),
          const SizedBox(width: 4),
        ],
      ),

      // Menu latéral (Drawer)
      drawer: _buildDrawer(context),

      body: IndexedStack(
        index: _currentIndex,
        children: [
          WalletTab(
            balanceSats: _balanceSats,
            balanceFcfa: _balanceFcfa,
            escrowSats: _escrowSats,
            escrowFcfa: _escrowFcfa,
            escrowInvoicesCount: _escrowInvoicesCount,
            btcPriceFcfa: _btcPriceFcfa,
            paidInvoicesCount: _paidInvoicesCount,
            totalInvoicesCount: _totalInvoicesCount,
            isBalanceVisible: _isBalanceVisible,
            isLoading: _isLoadingWallet,
            isBackendOnline: _isBackendOnline,
            accountName: Session.displayName,
            transactions: _transactions,
            onToggleBalanceVisibility: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
            onRefresh: _fetchRealWalletData,
            onNavigateToPos: () => _goTo(1),
            onNavigateToHistory: () => _goTo(2),
            backendUrl: backendUrl,
          ),
          PosTab(
            backendUrl: backendUrl,
            onPaymentReceived: (sats, ref, preimage, desc) {
              _fetchRealWalletData();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Commande enregistrée : +${Formatters.sats(sats)} ($desc)'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
          HistoryTab(
            transactions: _transactions,
            isLoading: _isLoadingWallet,
            onRefresh: _fetchRealWalletData,
            onNavigateToPos: () => _goTo(1),
          ),
          SettingsTab(
            isBackendOnline: _isBackendOnline,
            backendPingLatency: _backendPingLatency,
            onTestPing: () async {
              await _testBackendPing();
              await _fetchRealWalletData();
            },
            accountName: Session.displayName,
            accountPhone: Session.phone ?? '',
            onLogout: widget.onLogout,
            balanceSats: _balanceSats,
            balanceFcfa: _balanceFcfa,
            escrowSats: _escrowSats,
            paidCount: _transactions.where((tx) => tx.isConfirmed && !tx.isCredit).length,
            receivedCount: _transactions.where((tx) => tx.isConfirmed && tx.isCredit).length,
            totalTransactions: _transactions.length,
            backendUrl: backendUrl,
            onRefresh: _fetchRealWalletData,
          ),
        ],
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _goTo,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Accueil',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale_rounded),
              label: 'Encaisser',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Reçus',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            // En-tête profil dans le menu
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.avatarGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      _initials(Session.displayName),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          Session.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.sapphire),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '+${Session.phone ?? ''}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text(
                            '● Compte Actif',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.successDark),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Liste de navigation
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.account_balance_wallet_rounded,
                    title: 'Accueil (Portefeuille)',
                    isSelected: _currentIndex == 0,
                    onTap: () {
                      Navigator.pop(context);
                      _goTo(0);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.point_of_sale_rounded,
                    title: 'Encaisser (TPE & Séquestre)',
                    isSelected: _currentIndex == 1,
                    onTap: () {
                      Navigator.pop(context);
                      _goTo(1);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.receipt_long_rounded,
                    title: 'Reçus & Historique',
                    isSelected: _currentIndex == 2,
                    onTap: () {
                      Navigator.pop(context);
                      _goTo(2);
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.person_rounded,
                    title: 'Mon Profil & Paramètres',
                    isSelected: _currentIndex == 3,
                    onTap: () {
                      Navigator.pop(context);
                      _goTo(3);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Divider(color: Color(0xFFE2E8F0)),
                  ),

                  _buildDrawerItem(
                    icon: Icons.sync_rounded,
                    title: 'Actualiser les soldes',
                    onTap: () {
                      Navigator.pop(context);
                      _fetchRealWalletData();
                    },
                  ),
                  _buildDrawerItem(
                    icon: Icons.info_outline_rounded,
                    title: 'À propos de l\'application',
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutDialog(context);
                    },
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Divider(color: Color(0xFFE2E8F0)),
                  ),

                  _buildDrawerItem(
                    icon: Icons.logout_rounded,
                    title: 'Déconnexion',
                    titleColor: AppColors.error,
                    iconColor: AppColors.error,
                    onTap: () {
                      Navigator.pop(context);
                      _confirmLogout(context);
                    },
                  ),
                ],
              ),
            ),

            // Footer de version
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${BrandingService.appName} v1.0.0',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Code & Chain Dakar 2026',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isSelected = false,
    Color? iconColor,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFEEF4FF) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? AppColors.primary : (iconColor ?? AppColors.textSecondary),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? AppColors.primary : (titleColor ?? AppColors.textPrimary),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
