/// Modelo de una solicitud de reembolso tal como la devuelve la API (camelCase).
class Reimbursement {
  const Reimbursement({
    required this.id,
    required this.employeeName,
    required this.amount,
    required this.category,
    required this.description,
    required this.status,
    required this.rejectionReason,
    required this.createdAtUtc,
    required this.decidedAtUtc,
  });

  final int id;
  final String employeeName;
  final num amount;
  final String category;
  final String description;
  final String status;
  final String? rejectionReason;
  final DateTime createdAtUtc;
  final DateTime? decidedAtUtc;

  factory Reimbursement.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) =>
        raw == null ? null : DateTime.tryParse(raw)?.toLocal();

    return Reimbursement(
      id: (json['id'] as num?)?.toInt() ?? 0,
      employeeName: json['employeeName'] as String? ?? '',
      amount: json['amount'] as num? ?? 0,
      category: json['category'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'Pending',
      rejectionReason: json['rejectionReason'] as String?,
      createdAtUtc: parseDate(json['createdAtUtc'] as String?) ?? DateTime.now(),
      decidedAtUtc: parseDate(json['decidedAtUtc'] as String?),
    );
  }

  bool get isPending => status == 'Pending';
  bool get isApproved => status == 'Approved';
  bool get isRejected => status == 'Rejected';

  String get statusLabel => switch (status) {
        'Approved' => 'Aprobada',
        'Rejected' => 'Rechazada',
        _ => 'Pendiente',
      };

  /// Monto en pesos colombianos con separador de miles: `$650.000 COP`.
  String get formattedAmount {
    final digits = amount.round().abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
      buffer.write(digits[i]);
    }
    final sign = amount < 0 ? '-' : '';
    return '\$$sign$buffer COP';
  }
}
