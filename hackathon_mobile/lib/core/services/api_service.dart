import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/transaction_item.dart';

class WalletResponse {
  final int balanceSats;
  final double balanceFcfa;
  final int escrowSats;
  final double escrowFcfa;
  final int escrowInvoicesCount;
  final int btcPriceFcfa;
  final int totalInvoices;
  final int paidInvoicesCount;
  final List<TransactionItem> transactions;

  WalletResponse({
    required this.balanceSats,
    required this.balanceFcfa,
    required this.escrowSats,
    required this.escrowFcfa,
    required this.escrowInvoicesCount,
    required this.btcPriceFcfa,
    required this.totalInvoices,
    required this.paidInvoicesCount,
    required this.transactions,
  });
}

class ApiService {
  static Future<WalletResponse?> getWalletData(String backendUrl) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/wallet'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final txList = (data['transactions'] as List? ?? [])
              .map((item) => TransactionItem.fromJson(item))
              .toList();

          return WalletResponse(
            balanceSats: (data['balanceSats'] as num?)?.toInt() ?? 0,
            balanceFcfa: (data['balanceFcfa'] as num?)?.toDouble() ?? 0.0,
            escrowSats: (data['escrowSats'] as num?)?.toInt() ?? 0,
            escrowFcfa: (data['escrowFcfa'] as num?)?.toDouble() ?? 0.0,
            escrowInvoicesCount: (data['escrowInvoicesCount'] as num?)?.toInt() ?? 0,
            btcPriceFcfa: (data['btcPriceFcfa'] as num?)?.toInt() ?? 64850000,
            totalInvoices: (data['totalInvoices'] as num?)?.toInt() ?? 0,
            paidInvoicesCount: (data['paidInvoicesCount'] as num?)?.toInt() ?? 0,
            transactions: txList,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> createInvoice(
    String backendUrl, {
    required int amount,
    required String description,
    bool isEscrow = false,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/invoice'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'amount': amount,
          'description': description.trim().isEmpty ? 'Paiement Démo' : description.trim(),
          'isEscrow': isEscrow,
        }),
      );
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getInvoiceStatus(
    String backendUrl,
    String reference,
  ) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/invoice/$reference/status'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> releaseEscrow(
    String backendUrl,
    String reference,
    String code,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/invoice/$reference/release'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'code': code}),
      );
      return jsonDecode(res.body);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> pingBackend(String backendUrl) async {
    final sw = Stopwatch()..start();
    try {
      final res = await http.get(Uri.parse('$backendUrl/health'));
      sw.stop();
      if (res.statusCode == 200) {
        return '${sw.elapsedMilliseconds} ms';
      }
    } catch (_) {}
    return null;
  }
}
