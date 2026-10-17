/// Formatage centralisé des montants, dates et identifiants.
class Formatters {
  Formatters._();

  /// 1495 -> "1 495" (espace insécable pour éviter les retours à la ligne).
  static String thousands(num value) {
    final negative = value < 0;
    final digits = value.abs().round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remaining = digits.length - i;
      buffer.write(digits[i]);
      if (remaining > 1 && remaining % 3 == 1) buffer.write('\u00A0');
    }
    return negative ? '-$buffer' : buffer.toString();
  }

  static String fcfa(num value) => '${thousands(value)}\u00A0FCFA';

  static String sats(num value) => '${thousands(value)}\u00A0SATS';

  /// 64 850 000 -> "64,9M FCFA"
  static String compactFcfa(num value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceAll('.', ',')}M\u00A0FCFA';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1).replaceAll('.', ',')}k\u00A0FCFA';
    }
    return fcfa(value);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String dateShort(DateTime date) {
    final d = date.toLocal();
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  static String dateTime(DateTime date) {
    final d = date.toLocal();
    return '${dateShort(d)} à ${_two(d.hour)}:${_two(d.minute)}';
  }

  /// "À l'instant", "Il y a 5 min", "Hier", ...
  static String relative(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.isNegative || diff.inSeconds < 60) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} j';
    return dateShort(date);
  }

  /// 01a14ab9-97c2-77c2-af12 -> "01a14ab9…af12"
  static String shortHash(String value, {int head = 8, int tail = 6}) {
    if (value.length <= head + tail + 1) return value;
    return '${value.substring(0, head)}…${value.substring(value.length - tail)}';
  }

  /// 75 secondes -> "01:15"
  static String elapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${_two(minutes)}:${_two(seconds)}';
  }
}
