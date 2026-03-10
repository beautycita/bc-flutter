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
  double? depositAmount,
  String? updatedAt,
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
    'deposit_amount': depositAmount,
    'updated_at': updatedAt,
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
