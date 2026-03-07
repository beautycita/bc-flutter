class ProductShowcase {
  final String id;
  final String businessId;
  final String productId;
  final String? caption;
  final DateTime createdAt;

  const ProductShowcase({
    required this.id,
    required this.businessId,
    required this.productId,
    this.caption,
    required this.createdAt,
  });

  factory ProductShowcase.fromJson(Map<String, dynamic> json) =>
      ProductShowcase(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        productId: json['product_id'] as String,
        caption: json['caption'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'product_id': productId,
        'caption': caption,
      };
}
