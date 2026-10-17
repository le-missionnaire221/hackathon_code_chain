import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class Session {
  static String? token;
  static String? phone;
  static String? fullName;
  static String? role;
  static String? backendUrl;

  static String get displayName {
    final name = (fullName ?? '').trim();
    if (name.isNotEmpty) return name;
    if (phone != null && phone!.isNotEmpty) return '+$phone';
    return 'Compte PayChain';
  }

  static Future<bool> restore() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    phone = prefs.getString('phone');
    fullName = prefs.getString('fullName');
    role = prefs.getString('role');
    backendUrl = prefs.getString('backendUrl');
    ApiService.token = token;
    return token != null && token!.isNotEmpty;
  }

  static Future<void> save({
    required String token,
    required String phone,
    required String fullName,
    required String role,
    String? backendUrl,
  }) async {
    Session.token = token;
    Session.phone = phone;
    Session.fullName = fullName;
    Session.role = role;
    if (backendUrl != null && backendUrl.isNotEmpty) Session.backendUrl = backendUrl;
    ApiService.token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('phone', phone);
    await prefs.setString('fullName', fullName);
    await prefs.setString('role', role);
    if (Session.backendUrl != null) {
      await prefs.setString('backendUrl', Session.backendUrl!);
    }
  }

  static Future<void> rememberBackend(String url) async {
    backendUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backendUrl', url);
  }

  static Future<void> clear() async {
    token = null;
    phone = null;
    fullName = null;
    role = null;
    ApiService.token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('phone');
    await prefs.remove('fullName');
    await prefs.remove('role');
  }
}
