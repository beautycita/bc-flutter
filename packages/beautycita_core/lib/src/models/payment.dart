class Payment {
  final String id;
  final String appointmentId;
  final String? businessId;
  final double amount;
  final String method;
  final String status;
  final DateTime createdAt;
  final DateTime? refundedAt;
  final String? refundReason;
  final Map<String, dynamic>? metadata;

  const Payment({
    required this.id,
    required this.appointmentId,
    this.businessId,
    required this.amount,
    required this.method,
    required this.status,
    required this.createdAt,
    this.refundedAt,
    this.refundReason,
    this.metadata,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      businessId: json['business_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      method: json['method'] as String? ?? 'unknown',
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
      refundedAt: json['refunded_at'] != null
          ? DateTime.parse(json['refunded_at'] as String)
          : null,
      refundReason: json['refund_reason'] as String?,
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'appointment_id': appointmentId,
      'business_id': businessId,
      'amount': amount,
      'method': method,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'refunded_at': refundedAt?.toIso8601String(),
      'refund_reason': refundReason,
      'metadata': metadata,
    };
  }
}
