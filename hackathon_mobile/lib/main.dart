import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  runApp(const CodeChainApp());
}

class CodeChainApp extends StatelessWidget {
  const CodeChainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Code & Chain Dakar 2026',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0E14),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFF7931A), // Bitcoin Gold
          secondary: Color(0xFF10B981), // Emerald Green
          surface: Color(0xFF161B26),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B26),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const LightningPaymentScreen(),
    );
  }
}

class LightningPaymentScreen extends StatefulWidget {
  const LightningPaymentScreen({super.key});

  @override
  State<LightningPaymentScreen> createState() => _LightningPaymentScreenState();
}

class _LightningPaymentScreenState extends State<LightningPaymentScreen> {
  String backendUrl = kIsWeb ? 'http://localhost:5000' : 'http://10.0.2.2:5000';
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _amountController = TextEditingController(text: '100');
  final TextEditingController _descController = TextEditingController(text: 'Paiement Démo Hackathon');

  bool _isLoading = false;
  String? _bolt11Invoice;
  String? _invoiceReference;
  String? _preimage;
  bool _isPaid = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _urlController.text = backendUrl;
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _amountController.dispose();
    _descController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  // 1. Créer l'invoice Lightning via notre Backend Node.js
  Future<void> _createInvoice() async {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackbar('Veuillez entrer un montant valide (en Satoshis)', Colors.red);
      return;
    }

    setState(() {
      _isLoading = true;
      _isPaid = false;
      _bolt11Invoice = null;
      _invoiceReference = null;
      _preimage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$backendUrl/invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'description': _descController.text.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && (data['data']?['request'] != null || data['request'] != null)) {
        final bolt11 = data['data']?['request'] ?? data['request'];
        final ref = data['reference'] ?? data['data']?['reference'];

        setState(() {
          _bolt11Invoice = bolt11;
          _invoiceReference = ref;
          _isLoading = false;
        });

        if (ref != null) {
          _startStatusPolling(ref);
        }
      } else {
        final errMsg = data['error'] ?? data['detail'] ?? data['message'] ?? 'Erreur serveur: ${response.statusCode}';
        throw Exception(errMsg);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackbar('Impossible de contacter le serveur backend: $e', Colors.red);
    }
  }

  // 2. Vérifier en temps réel le règlement de la facture par Bitnob
  void _startStatusPolling(String reference) {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final res = await http.get(Uri.parse('$backendUrl/invoice/$reference/status'));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          if (data['status'] == 'paid') {
            timer.cancel();
            setState(() {
              _isPaid = true;
              _preimage = data['preimage'];
            });
            HapticFeedback.heavyImpact();
            _showSnackbar('🎉 Paiement Lightning confirmé avec succès !', const Color(0xFF10B981));
          }
        }
      } catch (_) {}
    });
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161B26),
        title: const Text('Configuration Backend Node.js'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adresse du serveur Express :',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                hintText: 'ex: http://localhost:5000 ou http://10.0.2.2:5000',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF7931A)),
            onPressed: () {
              setState(() {
                backendUrl = _urlController.text.trim();
              });
              Navigator.pop(ctx);
              _showSnackbar('URL mise à jour : $backendUrl', Colors.orange);
            },
            child: const Text('Sauvegarder'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.bolt, color: Color(0xFFF7931A), size: 28),
            SizedBox(width: 8),
            Text('Code & Chain 2026', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuration Backend',
            onPressed: _showConfigDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B26),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Backend: $backendUrl',
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Text('Bitnob Testnet', style: TextStyle(fontSize: 11, color: Color(0xFFF7931A))),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (_isPaid) ...[
              _buildSuccessCard(),
            ] else if (_bolt11Invoice != null) ...[
              _buildInvoiceCard(),
            ] else ...[
              _buildFormCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Créer un Paiement Lightning',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('Montant (en Satoshis)', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF7931A)),
            decoration: InputDecoration(
              suffixText: 'SATS ⚡',
              suffixStyle: const TextStyle(color: Color(0xFFF7931A), fontWeight: FontWeight.bold),
              filled: true,
              fillColor: const Color(0xFF0B0E14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [100, 500, 1000, 2100].map((sats) {
              return InkWell(
                onTap: () => setState(() => _amountController.text = sats.toString()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B0E14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text('+$sats', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Description', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            controller: _descController,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0B0E14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isLoading ? null : _createInvoice,
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black))
                  : const Text(
                      'GÉNÉRER LE QR CODE ⚡',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_amountController.text} SATS',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF7931A)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x33FFA500),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('En attente ⏳', style: TextStyle(color: Colors.orange, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(_descController.text, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),

          // QR Code Lightning BOLT11
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: QrImageView(
              data: _bolt11Invoice!,
              version: QrVersions.auto,
              size: 240,
            ),
          ),
          const SizedBox(height: 16),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFF7931A)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.copy, size: 18, color: Color(0xFFF7931A)),
            label: const Text('Copier l\'Invoice Lightning (BOLT11)', style: TextStyle(color: Color(0xFFF7931A))),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _bolt11Invoice!));
              _showSnackbar('Invoice copiée dans le presse-papier !', Colors.orange);
            },
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange)),
              SizedBox(width: 10),
              Text('Règlement sur le réseau Lightning en cours...', style: TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 16),

          TextButton(
            onPressed: () {
              _statusTimer?.cancel();
              setState(() {
                _bolt11Invoice = null;
                _invoiceReference = null;
                _preimage = null;
              });
            },
            child: const Text('Annuler et revenir', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF161B26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981), width: 2),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, size: 48, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text(
            'Paiement Reçu !',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            '${_amountController.text} Satoshis confirmés sur Lightning Network ⚡',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (_preimage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B0E14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Preimage (Preuve de règlement Lightning) :', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _preimage!,
                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFFF7931A)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Référence : $_invoiceReference',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF7931A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _bolt11Invoice = null;
                  _invoiceReference = null;
                  _isPaid = false;
                  _preimage = null;
                });
              },
              child: const Text('NOUVEAU PAIEMENT', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}
