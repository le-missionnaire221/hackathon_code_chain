import 'dart:async';
import 'package:app_links/app_links.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final _appLinks = AppLinks();
  final _controller = StreamController<String>.broadcast();
  StreamSubscription<Uri>? _sub;
  String? pendingPayCode;
  bool _started = false;

  Stream<String> get payCodes => _controller.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      final initial = await _appLinks.getInitialLink();
      _handleUri(initial);
    } catch (_) {}
    _sub = _appLinks.uriLinkStream.listen(_handleUri, onError: (_) {});
  }

  void _handleUri(Uri? uri) {
    if (uri == null) return;
    final code = extractPayCode(uri.toString());
    if (code == null || code.isEmpty) return;
    pendingPayCode = code;
    _controller.add(code);
  }

  static String? extractPayCode(String raw) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    if (lower.startsWith('paychain://pay/')) {
      return text.substring('paychain://pay/'.length).split('?').first.split('#').first.trim();
    }
    if (text.contains('/pay/')) {
      return text.split('/pay/').last.split('?').first.split('#').first.trim();
    }
    return null;
  }

  String? takePending() {
    final value = pendingPayCode;
    pendingPayCode = null;
    return value;
  }

  void dispose() {
    _sub?.cancel();
    _controller.close();
  }
}
