import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/category.dart';
import '../data/categories.dart';

final categoriesProvider = Provider<List<ServiceCategory>>((ref) => allCategories);
