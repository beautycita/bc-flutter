class Booking {
  final String id;
  final String userId;
  final String providerId;
  final String? providerServiceId;
  final String serviceName;
  final String category;
  final String status;
  final DateTime scheduledAt;
  final int durationMinutes;
  final double? price;
  final String? notes;
  final DateTime createdAt;
  final String? providerName;

  const Booking({
    required this.id,
    required this.userId,
    required this.providerId,
    this.providerServiceId,
    required this.serviceName,
    required this.category,
    required this.status,
    required this.scheduledAt,
    required this.durationMinutes,
    this.price,
    this.notes,
    required this.createdAt,
    this.providerName,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Handle joined provider name from nested object or flat field
    String? providerName;
    if (json['providers'] != null && json['providers'] is Map) {
      providerName = json['providers']['name'] as String?;
    } else {
      providerName = json['provider_name'] as String?;
    }

    return Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      providerId: json['provider_id'] as String,
      providerServiceId: json['provider_service_id'] as String?,
      serviceName: json['service_name'] as String,
      category: json['category'] as String,
      status: json['status'] as String,
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: (json['duration_minutes'] as num).toInt(),
      price: (json['price'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      providerName: providerName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'provider_id': providerId,
      'provider_service_id': providerServiceId,
      'service_name': serviceName,
      'category': category,
      'status': status,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'price': price,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
