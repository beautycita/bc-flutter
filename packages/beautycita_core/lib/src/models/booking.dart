class Booking {
  final String id;
  final String userId;
  final String businessId;
  final String? serviceId;
  final String serviceName;
  final String? serviceType;
  final String status;
  final DateTime scheduledAt;
  final DateTime? endsAt;
  final int durationMinutes;
  final double? price;
  final String? notes;
  final DateTime createdAt;
  final String? providerName;
  final String? businessPhone;
  final double? businessLat;
  final double? businessLng;
  final String? businessAddress;
  final String? transportMode;
  final String? paymentStatus;
  final String? paymentMethod;
  final double? depositAmount;
  final double? isrWithheld;
  final double? ivaWithheld;
  final double? providerNet;
  final DateTime? updatedAt;

  const Booking({
    required this.id,
    required this.userId,
    required this.businessId,
    this.serviceId,
    required this.serviceName,
    this.serviceType,
    required this.status,
    required this.scheduledAt,
    this.endsAt,
    required this.durationMinutes,
    this.price,
    this.notes,
    required this.createdAt,
    this.providerName,
    this.businessPhone,
    this.businessLat,
    this.businessLng,
    this.businessAddress,
    this.transportMode,
    this.paymentStatus,
    this.paymentMethod,
    this.depositAmount,
    this.isrWithheld,
    this.ivaWithheld,
    this.providerNet,
    this.updatedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    // Handle joined business data from nested object or flat fields
    String? providerName;
    String? businessPhone;
    double? businessLat;
    double? businessLng;
    String? businessAddress;
    if (json['businesses'] != null && json['businesses'] is Map) {
      final biz = json['businesses'] as Map<String, dynamic>;
      providerName = biz['name'] as String?;
      businessPhone = biz['phone'] as String?;
      businessLat = (biz['lat'] as num?)?.toDouble();
      businessLng = (biz['lng'] as num?)?.toDouble();
      businessAddress = biz['address'] as String?;
    } else {
      providerName = json['provider_name'] as String?;
      businessPhone = json['business_phone'] as String?;
    }

    final startsAt = DateTime.parse(json['starts_at'] as String);
    final endsAt = json['ends_at'] != null
        ? DateTime.parse(json['ends_at'] as String)
        : null;
    final duration = endsAt != null
        ? endsAt.difference(startsAt).inMinutes
        : 60;

    return Booking(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      businessId: json['business_id'] as String,
      serviceId: json['service_id'] as String?,
      serviceName: json['service_name'] as String,
      serviceType: json['service_type'] as String?,
      status: json['status'] as String,
      scheduledAt: startsAt,
      endsAt: endsAt,
      durationMinutes: duration,
      price: (json['price'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      providerName: providerName,
      businessPhone: businessPhone,
      businessLat: businessLat,
      businessLng: businessLng,
      businessAddress: businessAddress,
      transportMode: json['transport_mode'] as String?,
      paymentStatus: json['payment_status'] as String?,
      paymentMethod: json['payment_method'] as String?,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
      isrWithheld: (json['isr_withheld'] as num?)?.toDouble(),
      ivaWithheld: (json['iva_withheld'] as num?)?.toDouble(),
      providerNet: (json['provider_net'] as num?)?.toDouble(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'business_id': businessId,
      'service_id': serviceId,
      'service_name': serviceName,
      'service_type': serviceType,
      'status': status,
      'starts_at': scheduledAt.toIso8601String(),
      'ends_at': (endsAt ?? scheduledAt.add(Duration(minutes: durationMinutes)))
          .toIso8601String(),
      'price': price,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'transport_mode': transportMode,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'deposit_amount': depositAmount,
      'isr_withheld': isrWithheld,
      'iva_withheld': ivaWithheld,
      'provider_net': providerNet,
    };
  }

  Booking copyWith({
    String? status,
    String? notes,
    String? transportMode,
    String? paymentStatus,
    String? paymentMethod,
  }) {
    return Booking(
      id: id,
      userId: userId,
      businessId: businessId,
      serviceId: serviceId,
      serviceName: serviceName,
      serviceType: serviceType,
      status: status ?? this.status,
      scheduledAt: scheduledAt,
      endsAt: endsAt,
      durationMinutes: durationMinutes,
      price: price,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      providerName: providerName,
      businessPhone: businessPhone,
      businessLat: businessLat,
      businessLng: businessLng,
      businessAddress: businessAddress,
      transportMode: transportMode ?? this.transportMode,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      depositAmount: depositAmount,
      isrWithheld: isrWithheld,
      ivaWithheld: ivaWithheld,
      providerNet: providerNet,
      updatedAt: updatedAt,
    );
  }
}
