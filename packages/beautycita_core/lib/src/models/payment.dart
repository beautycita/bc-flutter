class Payment {
  final String id;
  final String appointmentId;
  final double amount;
  final String method;
  final String status;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.appointmentId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      method: json['method'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'amount': amount,
      'method': method,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
