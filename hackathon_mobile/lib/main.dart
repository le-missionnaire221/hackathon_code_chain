import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const CodeChainFintechApp());
}

class TransactionItem {
  final String id;
  final String reference;
  final String title;
  final String category;
  final int amountSats;
  final double amountFcfa;
  final bool isCredit;
  final DateTime date;
  final String status;
  final String? preimage;
  final String? request;

  TransactionItem({
    required this.id,
    required this.reference,
    required this.title,
    required this.category,
    required this.amountSats,
    required this.amountFcfa,
    required this.isCredit,
    required this.date,
    required this.status,
    this.preimage,
    this.request,
  });

  factory TransactionItem.fromJson(Map<String, dynamic> json) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(json['date'] ?? '');
    } catch (_) {
      parsedDate = DateTime.now();
    }

    return TransactionItem(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? 'N/A',
      title: json['title']?.toString() ?? 'Paiement Lightning',
      category: json['category']?.toString() ?? 'Encaissement Marchand POS',
      amountSats: (json['amountSats'] as num?)?.toInt() ?? 0,
      amountFcfa: (json['amountFcfa'] as num?)?.toDouble() ?? 0.0,
      isCredit: json['isCredit'] ?? true,
      date: parsedDate,
      status: json['status']?.toString() ?? 'Confirmé ⚡',
      preimage: json['preimage']?.toString(),
      request: json['request']?.toString(),
    );
  }
}

class CodeChainFintechApp extends StatelessWidget {
  const CodeChainFintechApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Code & Chain - Lightning Fintech',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0052FF),
          secondary: Color(0xFF00D2FF),
          surface: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0F172A),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  String backendUrl = kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';

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
    try {
      final res = await http.get(Uri.parse('$backendUrl/wallet'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final txList = (data['transactions'] as List? ?? [])
              .map((item) => TransactionItem.fromJson(item))
              .toList();

          setState(() {
            _balanceSats = (data['balanceSats'] as num?)?.toInt() ?? 0;
            _balanceFcfa = (data['balanceFcfa'] as num?)?.toDouble() ?? 0.0;
            _btcPriceFcfa = (data['btcPriceFcfa'] as num?)?.toInt() ?? 64850000;
            _paidInvoicesCount = (data['paidInvoicesCount'] as num?)?.toInt() ?? 0;
            _totalInvoicesCount = (data['totalInvoicesCount'] as num?)?.toInt() ?? 0;
            _transactions = txList;
            _isLoadingWallet = false;
            _isBackendOnline = true;
          });
          return;
        }
      }
    } catch (_) {}

    setState(() {
      _isLoadingWallet = false;
    });
  }

  Future<void> _testBackendPing() async {
    final sw = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse('$backendUrl/health'));
      sw.stop();
      if (res.statusCode == 200) {
        setState(() {
          _backendPingLatency = '${sw.elapsedMilliseconds} ms';
          _isBackendOnline = true;
        });
        return;
      }
    } catch (_) {}
    setState(() {
      _backendPingLatency = 'Inaccessible';
      _isBackendOnline = false;
    });
  }
  void _showBlinkAddressModal() {
    const lightningAddress = 'le-missionnaire221@blink.sv';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(color: Color(0xFFEEF4FF), shape: BoxShape.circle),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF0052FF), size: 30),
            ),
            const SizedBox(height: 12),
            const Text('Votre Adresse Lightning Réelle', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const Text('Recevez des Satoshis directement sur votre portefeuille Blink', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: QrImageView(
                data: 'lightning:$lightningAddress',
                version: QrVersions.auto,
                size: 180,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0052FF)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0A2540)),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(lightningAddress, style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052FF), fontSize: 13)),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0052FF)),
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: lightningAddress));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adresse Lightning copiée !'), backgroundColor: Color(0xFF0052FF)),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0052FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReceiptModal(TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildReceiptSheet(tx),
    );
  }

  Widget _buildReceiptSheet(TransactionItem tx) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(color: Color(0xFFEEF4FF), shape: BoxShape.circle),
            child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF0052FF), size: 30),
          ),
          const SizedBox(height: 12),
          const Text('Reçu Réel Lightning Bitnob', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          Text(tx.status, style: const TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text(
            '+${tx.amountSats} SATS',
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0052FF)),
          ),
          Text('≈ ${tx.amountFcfa.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                _buildReceiptRow('Description', tx.title),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildReceiptRow('Référence', tx.reference, isMonospace: true),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildReceiptRow('Identifiant Bitnob', tx.id.length > 14 ? '${tx.id.substring(0, 14)}...' : tx.id, isMonospace: true),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildReceiptRow('Horodatage', tx.date.toString().substring(0, 16)),
                if (tx.preimage != null && tx.preimage!.isNotEmpty) ...[
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Preimage (Preuve)', '${tx.preimage!.substring(0, 14)}...', isMonospace: true),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (tx.request != null && tx.request!.isNotEmpty)
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF0052FF)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.copy_rounded, size: 16, color: Color(0xFF0052FF)),
                    label: const Text('Copier BOLT11', style: TextStyle(color: Color(0xFF0052FF), fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: tx.request!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Facture BOLT11 copiée !'), backgroundColor: Color(0xFF0052FF)),
                      );
                    },
                  ),
                ),
              if (tx.request != null && tx.request!.isNotEmpty) const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isMonospace = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
            fontFamily: isMonospace ? 'monospace' : null,
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildWalletTab(),
          LightningPosScreen(
            backendUrl: backendUrl,
            onPaymentReceived: (sats, ref, preimage, desc) {
              _fetchRealWalletData();
            },
          ),
          _buildHistoryTab(),
          _buildSettingsTab(),
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
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0052FF),
          unselectedItemColor: const Color(0xFF94A3B8),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
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

  Widget _buildWalletTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchRealWalletData,
        color: const Color(0xFF0052FF),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF0052FF), Color(0xFF0A2540)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: Text('IC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Idrissa Coulibaly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                          Text('Code & Chain Dakar 🇸🇳', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isBackendOnline ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: (_isBackendOnline ? const Color(0xFF10B981) : Colors.red).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, color: _isBackendOnline ? const Color(0xFF10B981) : Colors.red, size: 8),
                        const SizedBox(width: 6),
                        Text(
                          _isBackendOnline ? 'Bitnob Actif ⚡' : 'Hors Ligne',
                          style: TextStyle(color: _isBackendOnline ? const Color(0xFF10B981) : Colors.red, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),

              // CARTE DU SOLDE EN DIRECT BITNOB
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0052FF), Color(0xFF003BB5), Color(0xFF0A2540)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0052FF).withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'SOLDE RÉEL BITNOB (TESTNET)',
                          style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _isBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: Colors.white70,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _isBalanceVisible = !_isBalanceVisible),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoadingWallet
                        ? const SizedBox(
                            height: 38,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                            ),
                          )
                        : Text(
                            _isBalanceVisible ? '${_balanceFcfa.toStringAsFixed(0)} FCFA' : '•••••••• FCFA',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                          ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                          child: Text(
                            _isBalanceVisible ? '$_balanceSats SATS ⚡' : '•••• SATS',
                            style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('1 BTC ≈ ${(_btcPriceFcfa / 1000000).toStringAsFixed(1)}M FCFA', style: const TextStyle(color: Colors.white60, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildQuickActionButton(
                          icon: Icons.bolt_rounded,
                          label: 'Encaisser',
                          color: const Color(0xFFFFD166),
                          onTap: () => setState(() => _currentIndex = 1),
                        ),
                        _buildQuickActionButton(
                          icon: Icons.sync_rounded,
                          label: 'Actualiser',
                          color: Colors.white,
                          onTap: _fetchRealWalletData,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.qr_code_rounded,
                          label: 'Adresse Blink',
                          color: Colors.white,
                          onTap: _showBlinkAddressModal,
                        ),
                        _buildQuickActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: 'Reçus',
                          color: Colors.white,
                          onTap: () => setState(() => _currentIndex = 2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // BANNIÈRE RÉELLE HACKATHON
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_rounded, color: Color(0xFF0052FF), size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Règlement Réel Bitnob', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                          Text('$_paidInvoicesCount / $_totalInvoicesCount factures Lightning réglées avec Preimage', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Dernières Factures Bitnob', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 2),
                    child: const Text('Tout voir', style: TextStyle(color: Color(0xFF0052FF), fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              if (_transactions.isEmpty && !_isLoadingWallet)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Center(
                    child: Text('Aucune facture générée pour le moment.\nAllez dans "Encaisser ⚡" pour créer votre premier paiement !',
                        textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  ),
                )
              else
                ..._transactions.take(4).map((tx) => _buildTransactionCard(tx)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
  Widget _buildTransactionCard(TransactionItem tx) {
    final isConfirmed = tx.status.contains('Confirmé') || tx.status.contains('paid');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        onTap: () => _showReceiptModal(tx),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isConfirmed ? const Color(0xFFE8F5E9) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isConfirmed ? Icons.bolt_rounded : Icons.access_time_rounded,
            color: isConfirmed ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
          ),
        ),
        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
        subtitle: Text('${tx.reference} • ${tx.status}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '+${tx.amountSats} SATS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: isConfirmed ? const Color(0xFF0052FF) : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text('≈ ${tx.amountFcfa.toStringAsFixed(0)} FCFA', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _fetchRealWalletData,
        color: const Color(0xFF0052FF),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Historique Réel Bitnob', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Factures Lightning enregistrées dans votre Sandbox', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF0052FF)),
                    onPressed: _fetchRealWalletData,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_transactions.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('Aucune transaction trouvée sur l\'API Bitnob.', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: _transactions.length,
                    itemBuilder: (ctx, i) => _buildTransactionCard(_transactions[i]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    final urlController = TextEditingController(text: backendUrl);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Supervision & Nœud', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Vérification en direct de la connectivité Express et Bitnob', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildStatusRow('Serveur Express', _isBackendOnline ? 'En ligne 🟢' : 'Inaccessible 🔴'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('Latence Ping Backend', _backendPingLatency ?? 'Calcul en cours...'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('Moteur API Bitnob', 'Sandbox Testnet ⚡'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('Sécurité Webhook', 'HMAC-SHA512 🔒'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('Règlement Automatique', 'Auto-Settle Activé ✅'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0052FF)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.network_check_rounded, color: Color(0xFF0052FF)),
                label: const Text('Tester la Connectivité en Direct', style: TextStyle(color: Color(0xFF0052FF), fontWeight: FontWeight.bold)),
                onPressed: () async {
                  await _testBackendPing();
                  await _fetchRealWalletData();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Test réussi : Latence $_backendPingLatency'), backgroundColor: const Color(0xFF0052FF)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('URL du Serveur Backend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  TextField(
                    controller: urlController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Color(0xFF0052FF)),
                        onPressed: () {
                          setState(() => backendUrl = urlController.text.trim());
                          _testBackendPing();
                          _fetchRealWalletData();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('URL enregistrée : $backendUrl'), backgroundColor: const Color(0xFF0052FF)));
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      ActionChip(
                        label: const Text('Web (localhost:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          urlController.text = 'http://localhost:5000';
                          setState(() => backendUrl = 'http://localhost:5000');
                          _testBackendPing();
                          _fetchRealWalletData();
                        },
                      ),
                      ActionChip(
                        label: const Text('Émulateur (10.0.2.2:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          urlController.text = 'http://10.0.2.2:5000';
                          setState(() => backendUrl = 'http://10.0.2.2:5000');
                          _testBackendPing();
                          _fetchRealWalletData();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF4FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF0052FF).withValues(alpha: 0.2)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Code & Chain Dakar 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0052FF))),
                  SizedBox(height: 4),
                  Text('Application Fintech développée par Idrissa Coulibaly (@le-missionnaire221) avec Bitnob API & Flutter.', style: TextStyle(fontSize: 12, color: Color(0xFF334155))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      ],
    );
  }
}
class LightningPosScreen extends StatefulWidget {
  final String backendUrl;
  final Function(int sats, String reference, String? preimage, String description) onPaymentReceived;

  const LightningPosScreen({
    super.key,
    required this.backendUrl,
    required this.onPaymentReceived,
  });

  @override
  State<LightningPosScreen> createState() => _LightningPosScreenState();
}

class _LightningPosScreenState extends State<LightningPosScreen> {
  final TextEditingController _amountController = TextEditingController(text: '100');
  final TextEditingController _descController = TextEditingController(text: 'Paiement Démo Hackathon');

  bool _isLoading = false;
  String? _bolt11Invoice;
  String? _invoiceReference;
  String? _preimage;
  bool _isPaid = false;
  Timer? _statusTimer;

  static const double satRateInFcfa = 0.65;

  @override
  void dispose() {
    _statusTimer?.cancel();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createInvoice() async {
    final amount = int.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      _showSnackbar('Veuillez entrer un montant valide supérieur à 0.', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _bolt11Invoice = null;
      _invoiceReference = null;
      _isPaid = false;
      _preimage = null;
    });

    try {
      final res = await http.post(
        Uri.parse('${widget.backendUrl}/invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'description': _descController.text.trim().isEmpty ? 'Paiement Démo' : _descController.text.trim(),
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200 && data['data'] != null && data['data']['request'] != null) {
        setState(() {
          _bolt11Invoice = data['data']['request'];
          _invoiceReference = data['reference'];
          _isLoading = false;
        });

        _startPolling(data['reference']);
      } else {
        setState(() => _isLoading = false);
        _showSnackbar('Erreur Bitnob : ${data['error'] ?? data['message'] ?? 'Inconnue'}', Colors.red);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Impossible de joindre le backend (${widget.backendUrl}).', Colors.red);
    }
  }

  void _startPolling(String reference) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final res = await http.get(Uri.parse('${widget.backendUrl}/invoice/$reference/status'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'paid') {
            timer.cancel();
            setState(() {
              _isPaid = true;
              _preimage = data['preimage'];
            });
            final sats = int.tryParse(_amountController.text) ?? 100;
            widget.onPaymentReceived(sats, reference, data['preimage'], _descController.text);
          }
        }
      } catch (_) {}
    });
  }

  void _showSnackbar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sats = int.tryParse(_amountController.text) ?? 0;
    final fcfa = sats * satRateInFcfa;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Point de Vente ⚡', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text('Génération de vraie facture Lightning BOLT11 Bitnob', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Mode Caisse', style: TextStyle(color: Color(0xFF0052FF), fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (_isPaid)
              _buildSuccessCard()
            else if (_bolt11Invoice != null)
              _buildInvoiceCard()
            else
              _buildGeneratorCard(fcfa),
          ],
        ),
      ),
    );
  }
  Widget _buildGeneratorCard(double fcfa) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0052FF).withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MONTANT À ENCAISSER', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 0.5)),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0052FF)),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: '0'),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0052FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('SATS ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text('≈ ${fcfa.toStringAsFixed(0)} FCFA (Taux de conversion instantané)', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 18),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['50', '100', '500', '1000', '5000'].map((sats) {
              return InkWell(
                onTap: () {
                  setState(() => _amountController.text = sats);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0052FF).withValues(alpha: 0.15)),
                  ),
                  child: Text('+$sats sats', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0052FF))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          const Text('Description de la vente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText: 'ex: Démo Jury Hackathon Dakar...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _isLoading ? null : _createInvoice,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.bolt_rounded, color: Color(0xFFFFD166), size: 22),
                        SizedBox(width: 8),
                        Text('GÉNÉRER LE QR CODE LIGHTNING', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF0052FF).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF0052FF).withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_amountController.text} SATS', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0052FF))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B))),
                    SizedBox(width: 6),
                    Text('En attente ⚡', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_descController.text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            ),
            child: QrImageView(
              data: _bolt11Invoice!,
              version: QrVersions.auto,
              size: 230,
              eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF0052FF)),
              dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF0A2540)),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF0052FF), width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.copy_rounded, size: 18, color: Color(0xFF0052FF)),
              label: const Text('Copier l\'Invoice BOLT11', style: TextStyle(color: Color(0xFF0052FF), fontWeight: FontWeight.bold)),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _bolt11Invoice!));
                _showSnackbar('Facture Lightning copiée dans le presse-papier !', const Color(0xFF0052FF));
              },
            ),
          ),
          const SizedBox(height: 14),

          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0052FF))),
              SizedBox(width: 8),
              Text('Règlement sur le réseau Lightning en cours...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 10),

          TextButton(
            onPressed: () {
              _statusTimer?.cancel();
              setState(() {
                _bolt11Invoice = null;
                _invoiceReference = null;
                _preimage = null;
              });
            },
            child: const Text('Annuler et revenir', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981), width: 2),
        boxShadow: [
          BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: const Center(
              child: Icon(Icons.check_circle_rounded, size: 52, color: Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Paiement Reçu !',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 6),
          Text(
            '${_amountController.text} Satoshis confirmés sur Lightning Network ⚡',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          if (_preimage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preimage (Preuve cryptographique) :', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SelectableText(
                    _preimage!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF0052FF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('Référence : $_invoiceReference', style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052FF),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                setState(() {
                  _bolt11Invoice = null;
                  _invoiceReference = null;
                  _isPaid = false;
                  _preimage = null;
                });
              },
              child: const Text('NOUVEL ENCAISSEMENT ⚡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}
