class PortfolioPhoto {
  final String id;
  final String businessId;
  final String? staffId;
  final String? beforeUrl;
  final String afterUrl;
  final String photoType; // 'before_after' or 'after_only'
  final String? serviceCategory;
  final String? caption;
  final Map<String, dynamic>? productTags;
  final int sortOrder;
  final bool isVisible;
  final DateTime createdAt;

  const PortfolioPhoto({
    required this.id,
    required this.businessId,
    this.staffId,
    this.beforeUrl,
    required this.afterUrl,
    required this.photoType,
    this.serviceCategory,
    this.caption,
    this.productTags,
    this.sortOrder = 0,
    this.isVisible = true,
    required this.createdAt,
  });

  factory PortfolioPhoto.fromJson(Map<String, dynamic> json) => PortfolioPhoto(
    id: json['id'] as String,
    businessId: json['business_id'] as String,
    staffId: json['staff_id'] as String?,
    beforeUrl: json['before_url'] as String?,
    afterUrl: json['after_url'] as String,
    photoType: json['photo_type'] as String? ?? 'after_only',
    serviceCategory: json['service_category'] as String?,
    caption: json['caption'] as String?,
    productTags: json['product_tags'] as Map<String, dynamic>?,
    sortOrder: json['sort_order'] as int? ?? 0,
    isVisible: json['is_visible'] as bool? ?? true,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  // Omits id and created_at — those are DB-generated.
  Map<String, dynamic> toJson() => {
    'business_id': businessId,
    'staff_id': staffId,
    'before_url': beforeUrl,
    'after_url': afterUrl,
    'photo_type': photoType,
    'service_category': serviceCategory,
    'caption': caption,
    'product_tags': productTags,
    'sort_order': sortOrder,
    'is_visible': isVisible,
  };
}
