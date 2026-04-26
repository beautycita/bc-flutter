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
  final String fulfillmentMethod;
  final String? trackingNumber;
  final Map<String, dynamic>? shippingAddress;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;
  final DateTime? pickedUpAt;
  final DateTime? pickupQrExpiresAt;
  final DateTime? claimWindowEndsAt;
  final DateTime? completedAt;
  final DateTime? refundedAt;
  final String? refundReason;
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
    this.fulfillmentMethod = 'ship',
    this.trackingNumber,
    this.shippingAddress,
    this.shippedAt,
    this.deliveredAt,
    this.pickedUpAt,
    this.pickupQrExpiresAt,
    this.claimWindowEndsAt,
    this.completedAt,
    this.refundedAt,
    this.refundReason,
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
        fulfillmentMethod:
            (json['fulfillment_method'] as String?) ?? 'ship',
        trackingNumber: json['tracking_number'] as String?,
        shippingAddress: json['shipping_address'] as Map<String, dynamic>?,
        shippedAt: json['shipped_at'] != null
            ? DateTime.parse(json['shipped_at'] as String)
            : null,
        deliveredAt: json['delivered_at'] != null
            ? DateTime.parse(json['delivered_at'] as String)
            : null,
        pickedUpAt: json['picked_up_at'] != null
            ? DateTime.parse(json['picked_up_at'] as String)
            : null,
        pickupQrExpiresAt: json['pickup_qr_expires_at'] != null
            ? DateTime.parse(json['pickup_qr_expires_at'] as String)
            : null,
        claimWindowEndsAt: json['claim_window_ends_at'] != null
            ? DateTime.parse(json['claim_window_ends_at'] as String)
            : null,
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        refundedAt: json['refunded_at'] != null
            ? DateTime.parse(json['refunded_at'] as String)
            : null,
        refundReason: json['refund_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  bool get isPaid => status == 'paid';
  bool get isAwaitingPickup => status == 'awaiting_pickup';
  bool get isShipped => status == 'shipped';
  bool get isDelivered => status == 'delivered';
  bool get isCompleted => status == 'completed';
  bool get isRefunded => status == 'refunded';
  bool get isCancelled => status == 'cancelled';
  bool get isPickup => fulfillmentMethod == 'pickup';
  bool get needsAction => isPaid || isAwaitingPickup;

  int get daysSinceOrder => DateTime.now().difference(createdAt).inDays;
  int? get daysSinceShipped =>
      shippedAt == null ? null : DateTime.now().difference(shippedAt!).inDays;

  // Legacy getters kept for the salon orders screen's deadline-bar UI.
  // The new POS-completion flow replaces auto-refund-at-D14 with the
  // ship-tracking-nudge cron (D3/D5/D7/D10/D13). The "deadline" UI now
  // surfaces nudge urgency, not a hard cutoff.
  int get shippingDeadlineDaysLeft =>
      14 - DateTime.now().difference(createdAt).inDays;
  bool get isShippingOverdue => shippingDeadlineDaysLeft < 0;
  bool get isShippingUrgent =>
      shippingDeadlineDaysLeft <= 3 && shippingDeadlineDaysLeft >= 0;

  /// True iff the buyer's claim window is still open. Drives the
  /// "Reportar problema" CTA in Pedidos.
  bool get claimWindowOpen {
    if (isCompleted || isRefunded || isCancelled) return false;
    if (claimWindowEndsAt == null) {
      // legacy / shipped-not-yet-window-set: fall through to original heuristic
      if (isAwaitingPickup) return true;
      if (isDelivered) return true;
      if (isShipped) {
        final d = daysSinceShipped;
        return d != null && d >= 10;
      }
      return false;
    }
    return DateTime.now().isBefore(claimWindowEndsAt!);
  }

  /// Buyer dispute eligibility — drives whether the "Reportar problema" UI
  /// renders on the Pedidos card.
  bool canDispute() {
    if (!claimWindowOpen) return false;
    return isShipped || isDelivered || isAwaitingPickup;
  }

  /// Hours remaining on the pickup QR's validity (null if not pickup or no QR).
  Duration? get pickupQrTimeLeft {
    if (pickupQrExpiresAt == null) return null;
    final left = pickupQrExpiresAt!.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}
