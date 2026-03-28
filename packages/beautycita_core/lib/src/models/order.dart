class Order {
  final String id;
  final String buyerId;
  final String businessId;
  final String? productId;
  final String productName;
  final int quantity;
  final double totalAmount;
  final double commissionAmount;
  final String? stripePaymentIntentId;
  final String status;
  final String? trackingNumber;
  final Map<String, dynamic>? shippingAddress;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? refundedAt;
  final DateTime createdAt;

  const Order({
    required this.id,
    required this.buyerId,
    required this.businessId,
    this.productId,
    required this.productName,
    this.quantity = 1,
    required this.totalAmount,
    required this.commissionAmount,
    this.stripePaymentIntentId,
    required this.status,
    this.trackingNumber,
    this.shippingAddress,
    this.shippedAt,
    this.deliveredAt,
    this.refundedAt,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        buyerId: json['buyer_id'] as String,
        businessId: json['business_id'] as String,
        productId: json['product_id'] as String?,
        productName: json['product_name'] as String,
        quantity: json['quantity'] as int? ?? 1,
        totalAmount: (json['total_amount'] as num).toDouble(),
        commissionAmount: (json['commission_amount'] as num).toDouble(),
        stripePaymentIntentId: json['stripe_payment_intent_id'] as String?,
        status: json['status'] as String,
        trackingNumber: json['tracking_number'] as String?,
        shippingAddress: json['shipping_address'] as Map<String, dynamic>?,
        shippedAt: json['shipped_at'] != null
            ? DateTime.parse(json['shipped_at'] as String)
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'] as String)
            : null,
        refundedAt: json['refunded_at'] != null
            ? DateTime.parse(json['refunded_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isPaid => status == 'paid';
  bool get isShipped => status == 'shipped';
  bool get isDelivered => status == 'delivered';
  bool get isRefunded => status == 'refunded';
  bool get isCancelled => status == 'cancelled';
  bool get needsAction => isPaid;

  int get daysSinceOrder =>
      DateTime.now().difference(createdAt).inDays;

  /// Days remaining before the 14-day shipping deadline.
  int get shippingDeadlineDaysLeft =>
      14 - DateTime.now().difference(createdAt).inDays;

  bool get isShippingOverdue => shippingDeadlineDaysLeft < 0;
  bool get isShippingUrgent => shippingDeadlineDaysLeft <= 3 && shippingDeadlineDaysLeft >= 0;
}
