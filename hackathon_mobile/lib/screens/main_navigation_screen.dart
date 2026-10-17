import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../core/services/api_service.dart';
import '../models/transaction_item.dart';
import 'wallet_tab.dart';
import 'pos_tab.dart';
import 'history_tab.dart';
import 'settings_tab.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String backendUrl = AppConstants.initialBackendUrl;

  bool _isBalanceVisible = true;
  bool _isLoadingWallet = false;
  int _balanceSats = 0;
  double _balanceFcfa = 0.0;
  int _btcPriceFcfa = 64850000;
  int _paidInvoicesCount = 0;
  int _totalInvoicesCount = 0;

  List<TransactionItem> _transactions = [];
  String? _backendPingLatency;
  bool _isBackendOnline = false;

  @override
  void initState() {
    super.initState();
    _fetchRealWalletData();
    _testBackendPing();
  }

  Future<void> _fetchRealWalletData() async {
    setState(() => _isLoadingWallet = true);
    final wallet = await ApiService.getWalletData(backendUrl);
    if (wallet != null) {
      setState(() {
        _balanceSats = wallet.balanceSats;
        _balanceFcfa = wallet.balanceFcfa;
        _btcPriceFcfa = wallet.btcPriceFcfa;
        _paidInvoicesCount = wallet.paidInvoicesCount;
        _totalInvoicesCount = wallet.totalInvoices;
        _transactions = wallet.transactions;
        _isLoadingWallet = false;
        _isBackendOnline = true;
      });
      return;
    }

    setState(() {
      _isLoadingWallet = false;
    });
  }

  Future<void> _testBackendPing() async {
    final latency = await ApiService.pingBackend(backendUrl);
    setState(() {
      if (latency != null) {
        _backendPingLatency = latency;
        _isBackendOnline = true;
      } else {
        _backendPingLatency = 'Inaccessible';
        _isBackendOnline = false;
      }
    });
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
            btcPriceFcfa: _btcPriceFcfa,
            paidInvoicesCount: _paidInvoicesCount,
            totalInvoicesCount: _totalInvoicesCount,
            isBalanceVisible: _isBalanceVisible,
            isLoading: _isLoadingWallet,
            isBackendOnline: _isBackendOnline,
            transactions: _transactions,
            onToggleBalanceVisibility: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
            onRefresh: _fetchRealWalletData,
            onNavigateToPos: () => setState(() => _currentIndex = 1),
            onNavigateToHistory: () => setState(() => _currentIndex = 2),
          ),
          PosTab(
            backendUrl: backendUrl,
            onPaymentReceived: (sats, ref, preimage, desc) {
              _fetchRealWalletData();
            },
          ),
          HistoryTab(
            transactions: _transactions,
            onRefresh: _fetchRealWalletData,
          ),
          SettingsTab(
            backendUrl: backendUrl,
            isBackendOnline: _isBackendOnline,
            backendPingLatency: _backendPingLatency,
            onBackendUrlChanged: (newUrl) {
              setState(() => backendUrl = newUrl);
              _testBackendPing();
              _fetchRealWalletData();
            },
            onTestPing: () async {
              await _testBackendPing();
              await _fetchRealWalletData();
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() => _currentIndex = index);
            if (index == 0 || index == 2) {
              _fetchRealWalletData();
            }
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Portefeuille',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bolt_outlined),
              activeIcon: Icon(Icons.bolt_rounded),
              label: 'Encaisser ⚡',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long_rounded),
              label: 'Reçus',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.tune_outlined),
              activeIcon: Icon(Icons.tune_rounded),
              label: 'Réglages',
            ),
          ],
        ),
      ),
    );
  }
}
