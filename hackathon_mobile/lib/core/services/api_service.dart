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
  static String? token;
  static void Function()? onUnauthorized;

  static Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  static void _guard(http.Response res) {
    if (res.statusCode == 401) onUnauthorized?.call();
  }

  static Future<Map<String, dynamic>?> login(
    String backendUrl, {
    required String phone,
    required String password,
  }) {
    return _postAuth('$backendUrl/auth/login', {'phone': phone, 'password': password});
  }

  static Future<Map<String, dynamic>?> register(
    String backendUrl, {
    required String phone,
    required String password,
    required String fullName,
  }) {
    return _postAuth('$backendUrl/auth/register', {
      'phone': phone,
      'password': password,
      'fullName': fullName,
    });
  }

  static Future<Map<String, dynamic>?> _postAuth(String url, Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse(url),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  static Future<WalletResponse?> getWalletData(String backendUrl) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/wallet'), headers: _headers);
      _guard(res);
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
        headers: _headers,
        body: jsonEncode({
          'amount': amount,
          'description': description.trim().isEmpty ? 'Paiement Démo' : description.trim(),
          'isEscrow': isEscrow,
        }),
      );
      _guard(res);
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getInvoiceStatus(
    String backendUrl,
    String reference,
  ) async {
    try {
      final res = await http.get(
        Uri.parse('$backendUrl/invoice/$reference/status'),
        headers: _headers,
      );
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
        headers: _headers,
        body: jsonEncode({'code': code}),
      );
      _guard(res);
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> lookupInvoice(String backendUrl, String code) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/invoice/lookup'),
        headers: _headers,
        body: jsonEncode({'code': code}),
      );
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> payInvoice(
    String backendUrl,
    String reference,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/invoice/$reference/pay'),
        headers: _headers,
      );
      _guard(res);
      final data = jsonDecode(res.body);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
    } catch (_) {
      return null;
    }
    return null;
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
