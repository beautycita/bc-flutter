import 'dart:ui' show Color;

class ServiceCategory {
  final String id;
  final String nameEs;
  final String icon;
  final Color color;
  final List<ServiceSubcategory> subcategories;

  const ServiceCategory({
    required this.id,
    required this.nameEs,
    required this.icon,
    required this.color,
    required this.subcategories,
  });
}

class ServiceSubcategory {
  final String id;
  final String categoryId;
  final String nameEs;
  final List<ServiceItem>? items;

  const ServiceSubcategory({
    required this.id,
    required this.categoryId,
    required this.nameEs,
    this.items,
  });
}

class ServiceItem {
  final String id;
  final String subcategoryId;
  final String nameEs;
  final String serviceType;

  const ServiceItem({
    required this.id,
    required this.subcategoryId,
    required this.nameEs,
    required this.serviceType,
  });
}
