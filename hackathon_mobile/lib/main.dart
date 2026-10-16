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
  final String title;
  final String category;
  final int amountSats;
  final double amountFcfa;
  final bool isCredit;
  final DateTime date;
  final String status;
  final String? preimage;
  final String? reference;

  TransactionItem({
    required this.id,
    required this.title,
    required this.category,
    required this.amountSats,
    required this.amountFcfa,
    required this.isCredit,
    required this.date,
    required this.status,
    this.preimage,
    this.reference,
  });
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
  double _balanceFcfa = 145850.0;
  int _balanceSats = 94800;
  static const double satRateInFcfa = 0.65;

  final List<TransactionItem> _transactions = [
    TransactionItem(
      id: 'TX-1092',
      title: 'Vente Boutique Dakar',
      category: 'Commerce Électronique',
      amountSats: 2500,
      amountFcfa: 1625.0,
      isCredit: true,
      date: DateTime.now().subtract(const Duration(minutes: 42)),
      status: 'Confirmé ⚡',
      reference: 'LTG_1729118392100',
      preimage: '8a9b23f6e1d4c7a5028374619bcdef0123456789abcdef0123456789abcdef01',
    ),
    TransactionItem(
      id: 'TX-1091',
      title: 'Café Touba Almadies',
      category: 'Restauration',
      amountSats: 450,
      amountFcfa: 292.5,
      isCredit: false,
      date: DateTime.now().subtract(const Duration(hours: 3)),
      status: 'Confirmé ⚡',
      reference: 'LTG_1729107591022',
    ),
    TransactionItem(
      id: 'TX-1090',
      title: 'Recharge Wave Sénégal',
      category: 'Dépôt Mobile Money',
      amountSats: 20000,
      amountFcfa: 13000.0,
      isCredit: true,
      date: DateTime.now().subtract(const Duration(days: 1)),
      status: 'Confirmé ✅',
      reference: 'WAVE_SN_928174',
    ),
  ];

  void _onPaymentReceived(int sats, String reference, String? preimage, String description) {
    final fcfa = sats * satRateInFcfa;
    setState(() {
      _balanceSats += sats;
      _balanceFcfa += fcfa;
      _transactions.insert(
        0,
        TransactionItem(
          id: 'TX-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
          title: description.isEmpty ? 'Paiement Lightning Reçu' : description,
          category: 'Point de Vente POS',
          amountSats: sats,
          amountFcfa: fcfa,
          isCredit: true,
          date: DateTime.now(),
          status: 'Règlement Réussi ⚡',
          reference: reference,
          preimage: preimage,
        ),
      );
    });
  }

  void _showReceiptModal(TransactionItem tx) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildReceiptSheet(tx),
    );
  }
  void _showQuickSendModal() {
    final recipientController = TextEditingController();
    final amountController = TextEditingController(text: '500');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFEEF4FF), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_upward_rounded, color: Color(0xFF0052FF)),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Envoyer des Satoshis ⚡', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Paiement instantané Lightning Network', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Adresse Lightning ou Facture BOLT11', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: recipientController,
                decoration: InputDecoration(
                  hintText: 'ex: idrissa@blink.sv ou lnbc...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  prefixIcon: const Icon(Icons.qr_code_scanner, color: Color(0xFF0052FF)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Montant en Satoshis', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'SATS ⚡',
                  suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052FF)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Paiement Lightning envoyé avec succès !'), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  child: const Text('CONFIRMER LE TRANSFERT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickRechargeModal() {
    final fcfaController = TextEditingController(text: '5000');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981)),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recharger le Portefeuille', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      Text('Passerelle Wave & Orange Money vers Bitcoin', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.waves, color: Color(0xFF0052FF), size: 28),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Wave / Orange Money Sénégal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Taux : 1 FCFA ≈ 1.54 Sats', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text('Montant en FCFA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              TextField(
                controller: fcfaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  suffixText: 'FCFA',
                  suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0052FF)),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0052FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Recharge validée avec succès !'), backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  child: const Text('CONFIRMER LA RECHARGE WAVE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              ),
            ],
          ),
        ),
      ),
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
          const Text('Reçu Officiel Lightning', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const Text('Règlement irrévocable (Zero-Conf)', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Text(
            '${tx.isCredit ? '+' : '-'}${tx.amountSats} SATS',
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
                _buildReceiptRow('Catégorie', tx.category),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildReceiptRow('Référence', tx.reference ?? 'N/A', isMonospace: true),
                const Divider(height: 16, color: Color(0xFFE2E8F0)),
                _buildReceiptRow('Statut', tx.status),
                if (tx.preimage != null) ...[
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),
                  _buildReceiptRow('Preimage', '${tx.preimage!.substring(0, 16)}...', isMonospace: true),
                ],
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
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('FERMER', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
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
            onPaymentReceived: _onPaymentReceived,
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
          onTap: (index) => setState(() => _currentIndex = index),
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
      child: SingleChildScrollView(
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
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: Color(0xFF10B981), size: 8),
                      SizedBox(width: 6),
                      Text('Nœud Actif ⚡', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

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
                        'SOLDE DU PORTEFEUILLE',
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.8),
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
                  Text(
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
                          _isBalanceVisible ? '≈ $_balanceSats SATS ⚡' : '•••• SATS',
                          style: const TextStyle(color: Color(0xFFFFD166), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('1 BTC ≈ 64.8M FCFA', style: TextStyle(color: Colors.white60, fontSize: 11)),
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
                        icon: Icons.arrow_upward_rounded,
                        label: 'Envoyer',
                        color: Colors.white,
                        onTap: _showQuickSendModal,
                      ),
                      _buildQuickActionButton(
                        icon: Icons.add_circle_outline_rounded,
                        label: 'Recharger',
                        color: Colors.white,
                        onTap: _showQuickRechargeModal,
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

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Color(0xFF0052FF), size: 28),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Moteur Lightning Bitnob', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                        Text('Règlements instantanés & sécurité HMAC-SHA512', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
                const Text('Activité Récente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 2),
                  child: const Text('Tout voir', style: TextStyle(color: Color(0xFF0052FF), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._transactions.take(3).map((tx) => _buildTransactionCard(tx)),
          ],
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
            color: tx.isCredit ? const Color(0xFFE8F5E9) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            tx.isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: tx.isCredit ? const Color(0xFF10B981) : const Color(0xFFEF4444),
          ),
        ),
        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
        subtitle: Text('${tx.category} • ${tx.date.hour.toString().padLeft(2, '0')}:${tx.date.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${tx.isCredit ? '+' : '-'}${tx.amountSats} SATS',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: tx.isCredit ? const Color(0xFF0052FF) : const Color(0xFF0F172A),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historique & Reçus', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Toutes vos transactions signées sur le réseau Lightning', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _transactions.length,
                itemBuilder: (ctx, i) => _buildTransactionCard(_transactions[i]),
              ),
            ),
          ],
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
            const Text('Paramètres & Nœud', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 4),
            const Text('Supervision technique Node.js & Bitnob API', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
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
                  _buildStatusRow('Serveur Express', 'Port 5000 (En ligne 🟢)'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('API Bitnob', 'Sandbox Testnet ⚡'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('Sécurité Webhook', 'HMAC-SHA512 🔒'),
                  const Divider(height: 18, color: Color(0xFFE2E8F0)),
                  _buildStatusRow('Règlement', 'Auto-Settle Validé ✅'),
                ],
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
                  const Text('URL du Backend', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
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
                        },
                      ),
                      ActionChip(
                        label: const Text('Émulateur (10.0.2.2:5000)', style: TextStyle(fontSize: 11)),
                        onPressed: () {
                          urlController.text = 'http://10.0.2.2:5000';
                          setState(() => backendUrl = 'http://10.0.2.2:5000');
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
                    Text('Terminal d\'encaissement Lightning Bitnob', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
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
              hintText: 'ex: Café Almadies, Démo Hackathon...',
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
