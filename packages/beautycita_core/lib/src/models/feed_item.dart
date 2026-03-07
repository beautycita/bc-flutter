class FeedItem {
  final String id;
  final String type; // 'photo' or 'showcase'
  final String businessId;
  final String businessName;
  final String? businessPhotoUrl;
  final String? businessSlug;
  final String? staffName;
  final String? beforeUrl;
  final String afterUrl;
  final String? caption;
  final String? serviceCategory;
  final List<FeedProductTag> productTags;
  final int saveCount;
  final bool isSaved;
  final DateTime createdAt;

  const FeedItem({
    required this.id,
    required this.type,
    required this.businessId,
    required this.businessName,
    this.businessPhotoUrl,
    this.businessSlug,
    this.staffName,
    this.beforeUrl,
    required this.afterUrl,
    this.caption,
    this.serviceCategory,
    this.productTags = const [],
    this.saveCount = 0,
    this.isSaved = false,
    required this.createdAt,
  });

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final rawTags = json['product_tags'];
    final tags = <FeedProductTag>[];
    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is Map<String, dynamic>) {
          tags.add(FeedProductTag.fromJson(t));
        }
      }
    }

    return FeedItem(
      id: json['id'] as String,
      type: json['type'] as String? ?? 'photo',
      businessId: json['business_id'] as String,
      businessName: json['business_name'] as String,
      businessPhotoUrl: json['business_photo_url'] as String?,
      businessSlug: json['business_slug'] as String?,
      staffName: json['staff_name'] as String?,
      beforeUrl: json['before_url'] as String?,
      afterUrl: json['after_url'] as String,
      caption: json['caption'] as String?,
      serviceCategory: json['service_category'] as String?,
      productTags: tags,
      saveCount: json['save_count'] as int? ?? 0,
      isSaved: json['is_saved'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isBeforeAfter => type == 'photo' && beforeUrl != null;
  bool get isShowcase => type == 'showcase';
  bool get hasProducts => productTags.isNotEmpty;
}

class FeedProductTag {
  final String productId;
  final String name;
  final String? brand;
  final double price;
  final String photoUrl;
  final bool inStock;

  const FeedProductTag({
    required this.productId,
    required this.name,
    this.brand,
    required this.price,
    required this.photoUrl,
    this.inStock = true,
  });

  factory FeedProductTag.fromJson(Map<String, dynamic> json) => FeedProductTag(
        productId: json['product_id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        price: (json['price'] as num).toDouble(),
        photoUrl: json['photo_url'] as String,
        inStock: json['in_stock'] as bool? ?? true,
      );
}
