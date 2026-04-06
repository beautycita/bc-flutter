class Staff {
  final String id;
  final String businessId;
  final String firstName;
  final String lastName;
  final String? avatarUrl;
  final String? phone;
  final String position;
  final int experienceYears;
  final double averageRating;
  final int totalReviews;
  final bool isActive;
  final double commissionRate;

  const Staff({
    required this.id,
    required this.businessId,
    required this.firstName,
    required this.lastName,
    this.avatarUrl,
    this.phone,
    this.position = 'stylist',
    this.experienceYears = 0,
    this.averageRating = 0,
    this.totalReviews = 0,
    this.isActive = true,
    this.commissionRate = 0,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory Staff.fromJson(Map<String, dynamic> json) {
    return Staff(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      position: json['position'] as String? ?? 'stylist',
      experienceYears: json['experience_years'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
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
}
