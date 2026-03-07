class Product {
  final String id;
  final String businessId;
  final String name;
  final String? brand;
  final double price;
  final String photoUrl;
  final String category;
  final String? description;
  final bool inStock;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    required this.id,
    required this.businessId,
    required this.name,
    this.brand,
    required this.price,
    required this.photoUrl,
    required this.category,
    this.description,
    this.inStock = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        price: (json['price'] as num).toDouble(),
        photoUrl: json['photo_url'] as String,
        category: json['category'] as String,
        description: json['description'] as String?,
        inStock: json['in_stock'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'business_id': businessId,
        'name': name,
        'brand': brand,
        'price': price,
        'photo_url': photoUrl,
        'category': category,
        'description': description,
        'in_stock': inStock,
      };

  Product copyWith({
    String? name,
    String? brand,
    double? price,
    String? photoUrl,
    String? category,
    String? description,
    bool? inStock,
  }) =>
      Product(
        id: id,
        businessId: businessId,
        name: name ?? this.name,
        brand: brand ?? this.brand,
        price: price ?? this.price,
        photoUrl: photoUrl ?? this.photoUrl,
        category: category ?? this.category,
        description: description ?? this.description,
        inStock: inStock ?? this.inStock,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static const categories = <String, String>{
    'perfume': 'Perfume',
    'lipstick': 'Labiales y Gloss',
    'powder': 'Polvos',
    'serums': 'Serums y Esencias',
    'cleansers': 'Limpiadores Faciales',
    'shampoo': 'Shampoo y Acondicionador',
    'scrubs': 'Exfoliantes',
    'moisturisers': 'Cremas y Brumas',
    'body_wash': 'Jabon y Gel de Ducha',
    'foundation': 'Base y Corrector',
  };
}
