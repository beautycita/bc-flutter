// Factory functions for creating test model instances with sensible defaults.

Map<String, dynamic> bookingJson({
  String id = 'booking-1',
  String userId = 'user-1',
  String businessId = 'biz-1',
  String? serviceId = 'svc-1',
  String serviceName = 'Manicure Gel',
  String? serviceType = 'manicure_gel',
  String status = 'confirmed',
  String startsAt = '2026-03-10T14:00:00Z',
  String? endsAt = '2026-03-10T15:00:00Z',
  double? price = 350.0,
  String? notes,
  String createdAt = '2026-03-05T10:00:00Z',
  String? providerName,
  Map<String, dynamic>? businesses,
  String? transportMode = 'car',
  String? paymentStatus = 'paid',
  String? paymentMethod = 'card',
  double? depositAmount,
  double? isrWithheld,
  double? ivaWithheld,
  double? providerNet,
  String? updatedAt,
  String? staffId,
  String? staffName,
  String? cancellationReason,
}) {
  return {
    'id': id,
    'user_id': userId,
    'business_id': businessId,
    'service_id': serviceId,
    'service_name': serviceName,
    'service_type': serviceType,
    'status': status,
    'starts_at': startsAt,
    'ends_at': endsAt,
    'price': price,
    'notes': notes,
    'created_at': createdAt,
    'provider_name': ?providerName,
    'businesses': ?businesses,
    'transport_mode': transportMode,
    'payment_status': paymentStatus,
    'payment_method': paymentMethod,
    'deposit_amount': depositAmount,
    'isr_withheld': isrWithheld,
    'iva_withheld': ivaWithheld,
    'provider_net': providerNet,
    'updated_at': updatedAt,
    'staff_id': staffId,
    'staff_name': staffName,
    'cancellation_reason': cancellationReason,
  };
}

Map<String, dynamic> chatMessageJson({
  String id = 'msg-1',
  String threadId = 'thread-1',
  String senderType = 'user',
  String? senderId = 'user-1',
  String contentType = 'text',
  String? textContent = 'Hola!',
  String? mediaUrl,
  Map<String, dynamic> metadata = const {},
  String createdAt = '2026-03-05T10:00:00Z',
}) {
  return {
    'id': id,
    'thread_id': threadId,
    'sender_type': senderType,
    'sender_id': senderId,
    'content_type': contentType,
    'text_content': textContent,
    'media_url': mediaUrl,
    'metadata': metadata,
    'created_at': createdAt,
  };
}

Map<String, dynamic> chatThreadJson({
  String id = 'thread-1',
  String userId = 'user-1',
  String contactType = 'aphrodite',
  String? contactId,
  String? contactName,
  String? openaiThreadId,
  String? lastMessageText = 'Hola!',
  String? lastMessageAt = '2026-03-05T10:00:00Z',
  int unreadCount = 0,
  bool pinned = false,
  String createdAt = '2026-03-05T09:00:00Z',
}) {
  return {
    'id': id,
    'user_id': userId,
    'contact_type': contactType,
    'contact_id': contactId,
    'contact_name': contactName,
    'openai_thread_id': openaiThreadId,
    'last_message_text': lastMessageText,
    'last_message_at': lastMessageAt,
    'unread_count': unreadCount,
    'pinned': pinned,
    'created_at': createdAt,
  };
}

Map<String, dynamic> followUpQuestionJson({
  String id = 'fq-1',
  String serviceType = 'manicure_gel',
  int questionOrder = 1,
  String questionKey = 'nail_shape',
  String questionTextEs = 'Que forma de uña prefieres?',
  String answerType = 'visual_cards',
  List<Map<String, dynamic>>? options,
  bool isRequired = true,
}) {
  return {
    'id': id,
    'service_type': serviceType,
    'question_order': questionOrder,
    'question_key': questionKey,
    'question_text_es': questionTextEs,
    'answer_type': answerType,
    'options': options ??
        [
          {
            'label_es': 'Almendra',
            'label_en': 'Almond',
            'value': 'almond',
            'image_url': null,
          },
          {
            'label_es': 'Cuadrada',
            'label_en': 'Square',
            'value': 'square',
            'image_url': null,
          },
        ],
    'is_required': isRequired,
  };
}

Map<String, dynamic> feedItemJson({
  String id = 'feed-1',
  String type = 'photo',
  String businessId = 'biz-1',
  String businessName = 'Salon Rosa',
  String? businessPhotoUrl = 'https://example.com/biz.jpg',
  String? businessSlug = 'salon-rosa',
  String? staffName = 'Maria',
  String? beforeUrl = 'https://example.com/before.jpg',
  String afterUrl = 'https://example.com/after.jpg',
  String? caption = 'Transformacion increible',
  String? serviceCategory = 'hair',
  List<Map<String, dynamic>>? productTags,
  int saveCount = 5,
  bool isSaved = false,
  String createdAt = '2026-03-10T10:00:00Z',
}) {
  return {
    'id': id,
    'type': type,
    'business_id': businessId,
    'business_name': businessName,
    'business_photo_url': businessPhotoUrl,
    'business_slug': businessSlug,
    'staff_name': staffName,
    'before_url': beforeUrl,
    'after_url': afterUrl,
    'caption': caption,
    'service_category': serviceCategory,
    'product_tags': productTags,
    'save_count': saveCount,
    'is_saved': isSaved,
    'created_at': createdAt,
  };
}

Map<String, dynamic> feedProductTagJson({
  String productId = 'prod-1',
  String name = 'Kerastase Elixir',
  String? brand = 'Kerastase',
  double price = 890.0,
  String photoUrl = 'https://example.com/product.jpg',
  bool inStock = true,
}) {
  return {
    'product_id': productId,
    'name': name,
    'brand': brand,
    'price': price,
    'photo_url': photoUrl,
    'in_stock': inStock,
  };
}

Map<String, dynamic> providerJson({
  String id = 'biz-1',
  String name = 'Salon Rosa',
  String? phone = '3221234567',
  String? whatsapp = '523221234567',
  String? address = 'Av. Mexico 123',
  String city = 'Puerto Vallarta',
  String state = 'Jalisco',
  double? lat = 20.6534,
  double? lng = -105.2253,
  String? photoUrl,
  double? averageRating = 4.5,
  int totalReviews = 42,
  String? businessCategory = 'salon',
  List<String>? serviceCategories,
  Map<String, dynamic>? hours,
  bool isVerified = true,
}) {
  return {
    'id': id,
    'name': name,
    'phone': phone,
    'whatsapp': whatsapp,
    'address': address,
    'city': city,
    'state': state,
    'lat': lat,
    'lng': lng,
    'photo_url': photoUrl,
    'average_rating': averageRating,
    'total_reviews': totalReviews,
    'business_category': businessCategory,
    'service_categories': serviceCategories ?? ['nails', 'hair'],
    'hours': hours,
    'is_verified': isVerified,
  };
}

Map<String, dynamic> orderJson({
  String id = 'order-1',
  String buyerId = 'user-1',
  String businessId = 'biz-1',
  String? productId = 'prod-1',
  String productName = 'Shampoo Hidratante',
  int? quantity = 2,
  double totalAmount = 450.0,
  double commissionAmount = 45.0,
  String? stripePaymentIntentId = 'pi_abc123',
  String status = 'paid',
  String? trackingNumber,
  Map<String, dynamic>? shippingAddress,
  String? shippedAt,
  String? deliveredAt,
  String? refundedAt,
  String createdAt = '2026-03-10T10:00:00Z',
}) {
  return {
    'id': id,
    'buyer_id': buyerId,
    'business_id': businessId,
    'product_id': productId,
    'product_name': productName,
    'quantity': quantity,
    'total_amount': totalAmount,
    'commission_amount': commissionAmount,
    'stripe_payment_intent_id': stripePaymentIntentId,
    'status': status,
    'tracking_number': trackingNumber,
    'shipping_address': shippingAddress,
    'shipped_at': shippedAt,
    'delivered_at': deliveredAt,
    'refunded_at': refundedAt,
    'created_at': createdAt,
  };
}

Map<String, dynamic> paymentJson({
  String id = 'pay-1',
  String appointmentId = 'booking-1',
  String? businessId = 'biz-1',
  double amount = 350.0,
  String? method = 'card',
  String? status = 'completed',
  String createdAt = '2026-03-10T14:00:00Z',
  String? refundedAt,
  String? refundReason,
  Map<String, dynamic>? metadata,
}) {
  return {
    'id': id,
    'appointment_id': appointmentId,
    'business_id': businessId,
    'amount': amount,
    'method': method,
    'status': status,
    'created_at': createdAt,
    'refunded_at': refundedAt,
    'refund_reason': refundReason,
    'metadata': metadata,
  };
}

Map<String, dynamic> productJson({
  String id = 'prod-1',
  String businessId = 'biz-1',
  String name = 'Shampoo Hidratante',
  String? brand = 'Kerastase',
  double price = 450.0,
  String photoUrl = 'https://example.com/shampoo.jpg',
  String category = 'shampoo',
  String? description = 'Shampoo para cabello seco',
  bool? inStock = true,
  String createdAt = '2026-03-01T10:00:00Z',
  String updatedAt = '2026-03-05T10:00:00Z',
}) {
  return {
    'id': id,
    'business_id': businessId,
    'name': name,
    'brand': brand,
    'price': price,
    'photo_url': photoUrl,
    'category': category,
    'description': description,
    'in_stock': inStock,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

Map<String, dynamic> productShowcaseJson({
  String id = 'showcase-1',
  String businessId = 'biz-1',
  String productId = 'prod-1',
  String? caption = 'Nuevo en stock!',
  String createdAt = '2026-03-10T10:00:00Z',
}) {
  return {
    'id': id,
    'business_id': businessId,
    'product_id': productId,
    'caption': caption,
    'created_at': createdAt,
  };
}

Map<String, dynamic> profileJson({
  String id = 'user-1',
  String? fullName = 'Ana Garcia',
  String? username = 'anaGarcia',
  String? phone = '3221234567',
  String? avatarUrl,
  double? saldo = 100.0,
  String? role = 'customer',
}) {
  return {
    'id': id,
    'full_name': fullName,
    'username': username,
    'phone': phone,
    'avatar_url': avatarUrl,
    'saldo': saldo,
    'role': role,
  };
}

Map<String, dynamic> staffJson({
  String id = 'staff-1',
  String businessId = 'biz-1',
  String? firstName = 'Maria',
  String? lastName = 'Lopez',
  String? avatarUrl,
  String? phone,
  String? position = 'stylist',
  int? experienceYears = 5,
  double? averageRating = 4.8,
  int? totalReviews = 20,
  bool? isActive = true,
  double? commissionRate = 0.3,
}) {
  return {
    'id': id,
    'business_id': businessId,
    'first_name': firstName,
    'last_name': lastName,
    'avatar_url': avatarUrl,
    'phone': phone,
    'position': position,
    'experience_years': experienceYears,
    'average_rating': averageRating,
    'total_reviews': totalReviews,
    'is_active': isActive,
    'commission_rate': commissionRate,
  };
}

Map<String, dynamic> uberRideJson({
  String id = 'ride-1',
  String appointmentId = 'booking-1',
  String leg = 'outbound',
  String? uberRequestId,
  double? pickupLat = 20.6534,
  double? pickupLng = -105.2253,
  String? pickupAddress = 'Av. Mexico 123',
  double? dropoffLat = 20.6600,
  double? dropoffLng = -105.2300,
  String? dropoffAddress = 'Salon Rosa, Calle Flores 45',
  String? scheduledPickupAt = '2026-03-10T13:30:00Z',
  double? estimatedFareMin = 45.0,
  double? estimatedFareMax = 65.0,
  String? currency = 'MXN',
  String? status = 'scheduled',
}) {
  return {
    'id': id,
    'appointment_id': appointmentId,
    'leg': leg,
    'uber_request_id': uberRequestId,
    'pickup_lat': pickupLat,
    'pickup_lng': pickupLng,
    'pickup_address': pickupAddress,
    'dropoff_lat': dropoffLat,
    'dropoff_lng': dropoffLng,
    'dropoff_address': dropoffAddress,
    'scheduled_pickup_at': scheduledPickupAt,
    'estimated_fare_min': estimatedFareMin,
    'estimated_fare_max': estimatedFareMax,
    'currency': currency,
    'status': status,
  };
}

Map<String, dynamic> curateResponseJson({
  int resultCount = 3,
}) {
  return {
    'booking_window': {
      'primary_date': '2026-03-10',
      'primary_time': '14:00',
      'window_start': '2026-03-10T13:00:00Z',
      'window_end': '2026-03-10T17:00:00Z',
    },
    'results': List.generate(resultCount, (i) => resultCardJson(rank: i + 1)),
  };
}

Map<String, dynamic> resultCardJson({
  int rank = 1,
  double score = 0.85,
  String businessId = 'biz-1',
  String businessName = 'Salon Rosa',
}) {
  return {
    'rank': rank,
    'score': score,
    'business': {
      'id': businessId,
      'name': businessName,
      'photo_url': null,
      'address': 'Av. Mexico 123',
      'lat': 20.6534,
      'lng': -105.2253,
      'whatsapp': null,
    },
    'staff': {
      'id': 'staff-$rank',
      'name': 'Maria $rank',
      'avatar_url': null,
      'experience_years': 5,
      'rating': 4.8,
      'total_reviews': 20,
    },
    'service': {
      'id': 'svc-$rank',
      'name': 'Manicure Gel',
      'price': 350.0,
      'duration_minutes': 60,
      'currency': 'MXN',
    },
    'slot': {
      'starts_at': '2026-03-10T14:00:00Z',
      'ends_at': '2026-03-10T15:00:00Z',
    },
    'transport': {
      'mode': 'car',
      'duration_min': 15,
      'distance_km': 5.2,
      'traffic_level': 'moderate',
    },
    'review_snippet': null,
    'badges': ['top_rated'],
    'area_avg_price': 300.0,
    'scoring_breakdown': {
      'proximity': 0.8,
      'availability': 0.9,
      'rating': 0.85,
      'price': 0.7,
      'portfolio': 0.6,
    },
  };
}
