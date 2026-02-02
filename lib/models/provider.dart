class Provider {
  final String id;
  final String name;
  final String? phone;
  final String? whatsapp;
  final String? address;
  final String city;
  final String state;
  final double? lat;
  final double? lng;
  final String? photoUrl;
  final double? rating;
  final int reviewsCount;
  final String? businessCategory;
  final List<String> serviceCategories;
  final Map<String, dynamic>? hours;
  final String? website;
  final String? facebookUrl;
  final String? instagramHandle;
  final bool isVerified;

  const Provider({
    required this.id,
    required this.name,
    this.phone,
    this.whatsapp,
    this.address,
    required this.city,
    required this.state,
    this.lat,
    this.lng,
    this.photoUrl,
    this.rating,
    this.reviewsCount = 0,
    this.businessCategory,
    this.serviceCategories = const [],
    this.hours,
    this.website,
    this.facebookUrl,
    this.instagramHandle,
    this.isVerified = false,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String? ?? 'Guadalajara',
      state: json['state'] as String? ?? 'Jalisco',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      rating: (json['average_rating'] as num?)?.toDouble(),
      reviewsCount: (json['total_reviews'] as num?)?.toInt() ?? 0,
      businessCategory: json['business_category'] as String?,
      serviceCategories: (json['service_categories'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      hours: json['hours'] as Map<String, dynamic>?,
      website: json['website'] as String?,
      facebookUrl: json['facebook_url'] as String?,
      instagramHandle: json['instagram_handle'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
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
      'average_rating': rating,
      'total_reviews': reviewsCount,
      'business_category': businessCategory,
      'service_categories': serviceCategories,
      'hours': hours,
      'website': website,
      'facebook_url': facebookUrl,
      'instagram_handle': instagramHandle,
      'is_verified': isVerified,
    };
  }
}

class ProviderService {
  final String id;
  final String providerId;
  final String category;
  final String subcategory;
  final String serviceName;
  final double? priceMin;
  final double? priceMax;
  final int durationMinutes;

  const ProviderService({
    required this.id,
    required this.providerId,
    required this.category,
    required this.subcategory,
    required this.serviceName,
    this.priceMin,
    this.priceMax,
    required this.durationMinutes,
  });

  factory ProviderService.fromJson(Map<String, dynamic> json) {
    return ProviderService(
      id: json['id'] as String,
      providerId: json['business_id'] as String,
      category: json['category'] as String? ?? '',
      subcategory: json['subcategory'] as String? ?? '',
      serviceName: json['name'] as String,
      priceMin: (json['price'] as num?)?.toDouble(),
      priceMax: null,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'business_id': providerId,
      'category': category,
      'subcategory': subcategory,
      'name': serviceName,
      'price': priceMin,
      'duration_minutes': durationMinutes,
    };
  }
}
