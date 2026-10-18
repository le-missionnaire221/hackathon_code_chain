import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Nom + logo dynamiques (admin dashboard). Fallback local RAK TAK CASH.
class BrandingService {
  static String appName = AppConstants.defaultAppName;
  static String? logoUrl;
  static const String localLogoAsset = AppConstants.defaultLogoAsset;

  static String absoluteLogoUrl(String backendUrl) {
    final url = logoUrl;
    if (url == null || url.isEmpty) return '';
    if (url.startsWith('http')) return url;
    final base = backendUrl.endsWith('/') ? backendUrl.substring(0, backendUrl.length - 1) : backendUrl;
    return '$base$url';
  }

  static Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    appName = prefs.getString('brand_app_name') ?? AppConstants.defaultAppName;
    logoUrl = prefs.getString('brand_logo_url');
  }

  static Future<void> loadFromBackend(String backendUrl) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/branding')).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body);
      if (data is! Map) return;
      final name = data['appName']?.toString().trim();
      final logo = data['logoUrl']?.toString().trim();
      if (name != null && name.isNotEmpty) appName = name;
      if (logo != null && logo.isNotEmpty) logoUrl = logo;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('brand_app_name', appName);
      if (logoUrl != null) await prefs.setString('brand_logo_url', logoUrl!);
    } catch (_) {
      // garde le cache / défaut
    }
  }
}
