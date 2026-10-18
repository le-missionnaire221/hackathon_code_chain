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
      category: json['category']?.toString() ?? 'Encaissement Marchand POS',
      amountSats: (json['amountSats'] as num?)?.toInt() ?? 0,
      amountFcfa: (json['amountFcfa'] as num?)?.toDouble() ?? 0.0,
      isCredit: json['isCredit'] ?? true,
      date: parsedDate,
      status: json['status']?.toString() ?? 'Confirmé ⚡',
      preimage: json['preimage']?.toString(),
      request: json['request']?.toString(),
      isEscrow: json['isEscrow'] == true,
      escrowStatus: json['escrowStatus']?.toString() ?? 'none',
      releaseCode: json['releaseCode']?.toString(),
    );
  }

  bool get isConfirmed =>
      status.contains('Confirmé') ||
      status.toLowerCase().contains('paid') ||
      status.toLowerCase().contains('payé') ||
      status.toLowerCase().contains('paye') ||
      status.contains('Libéré');

  bool get isLockedInEscrow =>
      isEscrow &&
      (escrowStatus == 'locked' ||
          status.toLowerCase().contains('gardé') ||
          status.toLowerCase().contains('sequest') ||
          status.contains('Séquestré'));
}
