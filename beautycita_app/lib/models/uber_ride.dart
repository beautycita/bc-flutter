class UberRide {
  final String id;
  final String appointmentId;
  final String leg; // 'outbound' | 'return'
  final String? uberRequestId;
  final double? pickupLat;
  final double? pickupLng;
  final String? pickupAddress;
  final double? dropoffLat;
  final double? dropoffLng;
  final String? dropoffAddress;
  final DateTime? scheduledPickupAt;
  final double? estimatedFareMin;
  final double? estimatedFareMax;
  final String currency;
  final String status;

  const UberRide({
    required this.id,
    required this.appointmentId,
    required this.leg,
    this.uberRequestId,
    this.pickupLat,
    this.pickupLng,
    this.pickupAddress,
    this.dropoffLat,
    this.dropoffLng,
    this.dropoffAddress,
    this.scheduledPickupAt,
    this.estimatedFareMin,
    this.estimatedFareMax,
    this.currency = 'MXN',
    required this.status,
  });

  factory UberRide.fromJson(Map<String, dynamic> json) {
    return UberRide(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      leg: json['leg'] as String,
      uberRequestId: json['uber_request_id'] as String?,
      pickupLat: (json['pickup_lat'] as num?)?.toDouble(),
      pickupLng: (json['pickup_lng'] as num?)?.toDouble(),
      pickupAddress: json['pickup_address'] as String?,
      dropoffLat: (json['dropoff_lat'] as num?)?.toDouble(),
      dropoffLng: (json['dropoff_lng'] as num?)?.toDouble(),
      dropoffAddress: json['dropoff_address'] as String?,
      scheduledPickupAt: json['scheduled_pickup_at'] != null
          ? DateTime.parse(json['scheduled_pickup_at'] as String)
          : null,
      estimatedFareMin: (json['estimated_fare_min'] as num?)?.toDouble(),
      estimatedFareMax: (json['estimated_fare_max'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'MXN',
      status: json['status'] as String? ?? 'scheduled',
    );
  }

  String get statusLabel {
    switch (status) {
      case 'scheduled':
        return 'Programado';
      case 'requested':
        return 'Solicitado';
      case 'accepted':
        return 'Aceptado';
      case 'arriving':
        return 'En camino';
      case 'in_progress':
        return 'En curso';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  bool get isActive => status != 'cancelled' && status != 'completed';
}
