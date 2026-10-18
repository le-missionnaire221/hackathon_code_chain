import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/app_colors.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
}
