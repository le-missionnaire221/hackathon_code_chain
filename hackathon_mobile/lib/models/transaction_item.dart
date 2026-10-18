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
  final bool isEscrow;
  final String escrowStatus; // 'awaiting_lock', 'locked', 'released', 'none'
  final String? releaseCode;

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
    this.isEscrow = false,
    this.escrowStatus = 'none',
    this.releaseCode,
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
      category: json['category']?.toString() ?? 'Paiement Lightning',
      amountSats: (json['amountSats'] as num?)?.toInt() ?? 0,
      amountFcfa: (json['amountFcfa'] as num?)?.toDouble() ?? 0.0,
      isCredit: json['isCredit'] ?? true,
      date: parsedDate,
      status: json['status']?.toString() ?? 'Confirmé',
      preimage: json['preimage']?.toString(),
      request: json['request']?.toString(),
      isEscrow: json['isEscrow'] == true,
      escrowStatus: json['escrowStatus']?.toString() ?? 'none',
      releaseCode: json['releaseCode']?.toString(),
    );
  }

  bool get isConfirmed {
    final s = status.toLowerCase();
    if (isLockedInEscrow) return false;
    return s.contains('confirm') ||
        s.contains('paid') ||
        s.contains('payé') ||
        s.contains('paye') ||
        s.contains('libéré') ||
        s.contains('libere') ||
        s.contains('livré') ||
        s.contains('livre') ||
        s.contains('released');
  }

  bool get isLockedInEscrow {
    final s = status.toLowerCase();
    return isEscrow &&
        (escrowStatus == 'locked' ||
            s.contains('argent gardé') ||
            (s.contains('gardé') && !s.contains('livré')) ||
            s.contains('sequest') ||
            s.contains('séquestré'));
  }
}
