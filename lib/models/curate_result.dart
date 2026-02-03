// Models for the curate-results edge function (intelligent booking engine).

class CurateRequest {
  final String serviceType;
  final String? userId;
  final LatLng location;
  final String transportMode; // "car" | "uber" | "transit"
  final Map<String, String>? followUpAnswers;
  final OverrideWindow? overrideWindow;
  final String? priceComfort;
  final double? qualitySpeed;
  final double? exploreLoyalty;

  const CurateRequest({
    required this.serviceType,
    this.userId,
    required this.location,
    required this.transportMode,
    this.followUpAnswers,
    this.overrideWindow,
    this.priceComfort,
    this.qualitySpeed,
    this.exploreLoyalty,
  });

  Map<String, dynamic> toJson() => {
        'service_type': serviceType,
        'user_id': userId,
        'location': {'lat': location.lat, 'lng': location.lng},
        'transport_mode': transportMode,
        if (followUpAnswers != null) 'follow_up_answers': followUpAnswers,
        if (overrideWindow != null) 'override_window': overrideWindow!.toJson(),
        if (priceComfort != null) 'price_comfort': priceComfort,
        if (qualitySpeed != null) 'quality_speed': qualitySpeed,
        if (exploreLoyalty != null) 'explore_loyalty': exploreLoyalty,
      };
}

class OverrideWindow {
  final String range; // "today" | "tomorrow" | "this_week" | "next_week"
  final String? timeOfDay; // "morning" | "afternoon" | "evening"
  final String? specificDate; // ISO date

  const OverrideWindow({
    required this.range,
    this.timeOfDay,
    this.specificDate,
  });

  Map<String, dynamic> toJson() => {
        'range': range,
        'time_of_day': timeOfDay,
        'specific_date': specificDate,
      };
}

class LatLng {
  final double lat;
  final double lng;

  const LatLng({required this.lat, required this.lng});
}

class CurateResponse {
  final BookingWindowInfo bookingWindow;
  final List<ResultCard> results;

  const CurateResponse({
    required this.bookingWindow,
    required this.results,
  });

  factory CurateResponse.fromJson(Map<String, dynamic> json) {
    return CurateResponse(
      bookingWindow: BookingWindowInfo.fromJson(
        json['booking_window'] as Map<String, dynamic>,
      ),
      results: (json['results'] as List<dynamic>)
          .map((r) => ResultCard.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

class BookingWindowInfo {
  final String primaryDate;
  final String primaryTime;
  final String windowStart;
  final String windowEnd;

  const BookingWindowInfo({
    required this.primaryDate,
    required this.primaryTime,
    required this.windowStart,
    required this.windowEnd,
  });

  factory BookingWindowInfo.fromJson(Map<String, dynamic> json) {
    return BookingWindowInfo(
      primaryDate: json['primary_date'] as String,
      primaryTime: json['primary_time'] as String,
      windowStart: json['window_start'] as String,
      windowEnd: json['window_end'] as String,
    );
  }
}

class ResultCard {
  final int rank;
  final double score;
  final BusinessInfo business;
  final StaffInfo staff;
  final ServiceInfo service;
  final SlotInfo slot;
  final TransportInfo transport;
  final ReviewSnippet? reviewSnippet;
  final List<String> badges;
  final double areaAvgPrice;
  final ScoringBreakdown scoringBreakdown;

  const ResultCard({
    required this.rank,
    required this.score,
    required this.business,
    required this.staff,
    required this.service,
    required this.slot,
    required this.transport,
    this.reviewSnippet,
    required this.badges,
    required this.areaAvgPrice,
    required this.scoringBreakdown,
  });

  factory ResultCard.fromJson(Map<String, dynamic> json) {
    return ResultCard(
      rank: json['rank'] as int,
      score: (json['score'] as num).toDouble(),
      business: BusinessInfo.fromJson(json['business'] as Map<String, dynamic>),
      staff: StaffInfo.fromJson(json['staff'] as Map<String, dynamic>),
      service: ServiceInfo.fromJson(json['service'] as Map<String, dynamic>),
      slot: SlotInfo.fromJson(json['slot'] as Map<String, dynamic>),
      transport:
          TransportInfo.fromJson(json['transport'] as Map<String, dynamic>),
      reviewSnippet: json['review_snippet'] != null
          ? ReviewSnippet.fromJson(
              json['review_snippet'] as Map<String, dynamic>)
          : null,
      badges: (json['badges'] as List<dynamic>).cast<String>(),
      areaAvgPrice: (json['area_avg_price'] as num).toDouble(),
      scoringBreakdown: ScoringBreakdown.fromJson(
        json['scoring_breakdown'] as Map<String, dynamic>,
      ),
    );
  }
}

class BusinessInfo {
  final String id;
  final String name;
  final String? photoUrl;
  final String? address;
  final double lat;
  final double lng;
  final String? whatsapp;

  const BusinessInfo({
    required this.id,
    required this.name,
    this.photoUrl,
    this.address,
    required this.lat,
    required this.lng,
    this.whatsapp,
  });

  factory BusinessInfo.fromJson(Map<String, dynamic> json) {
    return BusinessInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      photoUrl: json['photo_url'] as String?,
      address: json['address'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      whatsapp: json['whatsapp'] as String?,
    );
  }
}

class StaffInfo {
  final String id;
  final String name;
  final String? avatarUrl;
  final int? experienceYears;
  final double rating;
  final int totalReviews;

  const StaffInfo({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.experienceYears,
    required this.rating,
    required this.totalReviews,
  });

  factory StaffInfo.fromJson(Map<String, dynamic> json) {
    return StaffInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      experienceYears: json['experience_years'] as int?,
      rating: (json['rating'] as num).toDouble(),
      totalReviews: json['total_reviews'] as int,
    );
  }
}

class ServiceInfo {
  final String id;
  final String name;
  final double price;
  final int durationMinutes;
  final String currency;

  const ServiceInfo({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
    required this.currency,
  });

  factory ServiceInfo.fromJson(Map<String, dynamic> json) {
    return ServiceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      durationMinutes: json['duration_minutes'] as int,
      currency: json['currency'] as String,
    );
  }
}

class SlotInfo {
  final String startsAt;
  final String endsAt;

  const SlotInfo({required this.startsAt, required this.endsAt});

  DateTime get startTime => DateTime.parse(startsAt);
  DateTime get endTime => DateTime.parse(endsAt);

  factory SlotInfo.fromJson(Map<String, dynamic> json) {
    return SlotInfo(
      startsAt: json['starts_at'] as String,
      endsAt: json['ends_at'] as String,
    );
  }
}

class TransportInfo {
  final String mode;
  final int durationMin;
  final double distanceKm;
  final String trafficLevel;
  final double? uberEstimateMin;
  final double? uberEstimateMax;
  final String? transitSummary;
  final int? transitStops;

  const TransportInfo({
    required this.mode,
    required this.durationMin,
    required this.distanceKm,
    required this.trafficLevel,
    this.uberEstimateMin,
    this.uberEstimateMax,
    this.transitSummary,
    this.transitStops,
  });

  factory TransportInfo.fromJson(Map<String, dynamic> json) {
    return TransportInfo(
      mode: json['mode'] as String,
      durationMin: json['duration_min'] as int,
      distanceKm: (json['distance_km'] as num).toDouble(),
      trafficLevel: json['traffic_level'] as String,
      uberEstimateMin: (json['uber_estimate_min'] as num?)?.toDouble(),
      uberEstimateMax: (json['uber_estimate_max'] as num?)?.toDouble(),
      transitSummary: json['transit_summary'] as String?,
      transitStops: json['transit_stops'] as int?,
    );
  }
}

class ReviewSnippet {
  final String text;
  final String? authorName;
  final int? daysAgo;
  final int? rating;
  final double? qualityScore;

  const ReviewSnippet({
    required this.text,
    this.authorName,
    this.daysAgo,
    this.rating,
    this.qualityScore,
  });

  /// True when this is a fallback snippet (no matching review found).
  bool get isFallback => authorName == null;

  factory ReviewSnippet.fromJson(Map<String, dynamic> json) {
    return ReviewSnippet(
      text: json['text'] as String,
      authorName: json['author_name'] as String?,
      daysAgo: json['days_ago'] as int?,
      rating: json['rating'] as int?,
      qualityScore: (json['quality_score'] as num?)?.toDouble(),
    );
  }
}

class ScoringBreakdown {
  final double proximity;
  final double availability;
  final double rating;
  final double price;
  final double portfolio;

  const ScoringBreakdown({
    required this.proximity,
    required this.availability,
    required this.rating,
    required this.price,
    required this.portfolio,
  });

  factory ScoringBreakdown.fromJson(Map<String, dynamic> json) {
    return ScoringBreakdown(
      proximity: (json['proximity'] as num).toDouble(),
      availability: (json['availability'] as num).toDouble(),
      rating: (json['rating'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      portfolio: (json['portfolio'] as num).toDouble(),
    );
  }
}
