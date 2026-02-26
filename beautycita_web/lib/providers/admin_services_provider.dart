import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beautycita_core/supabase.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

/// A single node in the service catalog tree.
/// Represents a category, subcategory, or individual service item.
@immutable
class ServiceTreeNode {
  final String id;
  final String? parentId;
  final String name;
  final String? description;
  final int level; // 0=category, 1=subcategory, 2=item
  final int sortOrder;
  final double? minPrice;
  final double? maxPrice;
  final int? defaultDurationMinutes;
  final List<ServiceTreeNode> children;

  const ServiceTreeNode({
    required this.id,
    this.parentId,
    required this.name,
    this.description,
    required this.level,
    required this.sortOrder,
    this.minPrice,
    this.maxPrice,
    this.defaultDurationMinutes,
    this.children = const [],
  });

  ServiceTreeNode copyWith({
    String? name,
    String? description,
    int? sortOrder,
    double? minPrice,
    double? maxPrice,
    int? defaultDurationMinutes,
    List<ServiceTreeNode>? children,
  }) {
    return ServiceTreeNode(
      id: id,
      parentId: parentId,
      name: name ?? this.name,
      description: description ?? this.description,
      level: level,
      sortOrder: sortOrder ?? this.sortOrder,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      defaultDurationMinutes:
          defaultDurationMinutes ?? this.defaultDurationMinutes,
      children: children ?? this.children,
    );
  }

  factory ServiceTreeNode.fromJson(Map<String, dynamic> json) {
    return ServiceTreeNode(
      id: json['id'] as String,
      parentId: json['parent_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      level: json['level'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      minPrice: (json['min_price'] as num?)?.toDouble(),
      maxPrice: (json['max_price'] as num?)?.toDouble(),
      defaultDurationMinutes: json['default_duration_minutes'] as int?,
    );
  }

  String get levelLabel => switch (level) {
        0 => 'Categoria',
        1 => 'Subcategoria',
        2 => 'Servicio',
        _ => 'Item',
      };
}

/// Full tree of service categories.
@immutable
class ServiceTree {
  final List<ServiceTreeNode> roots;

  const ServiceTree({required this.roots});

  static const empty = ServiceTree(roots: []);

  /// Flatten all nodes into a searchable list.
  List<ServiceTreeNode> get allNodes {
    final result = <ServiceTreeNode>[];
    void walk(List<ServiceTreeNode> nodes) {
      for (final node in nodes) {
        result.add(node);
        walk(node.children);
      }
    }
    walk(roots);
    return result;
  }

  /// Find a node by ID.
  ServiceTreeNode? findById(String id) {
    ServiceTreeNode? search(List<ServiceTreeNode> nodes) {
      for (final node in nodes) {
        if (node.id == id) return node;
        final found = search(node.children);
        if (found != null) return found;
      }
      return null;
    }
    return search(roots);
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

/// Loads the full service catalog tree.
final serviceTreeProvider = FutureProvider<ServiceTree>((ref) async {
  if (!BCSupabase.isInitialized) return ServiceTree.empty;

  try {
    final data = await BCSupabase.client
        .from(BCTables.serviceCategoriesTree)
        .select()
        .order('sort_order', ascending: true);

    final allNodes =
        (data as List).map((row) => ServiceTreeNode.fromJson(row)).toList();

    // Build tree from flat list
    final nodeMap = <String, ServiceTreeNode>{};
    for (final node in allNodes) {
      nodeMap[node.id] = node;
    }

    final roots = <ServiceTreeNode>[];
    final childrenMap = <String, List<ServiceTreeNode>>{};

    for (final node in allNodes) {
      if (node.parentId == null) {
        roots.add(node);
      } else {
        childrenMap.putIfAbsent(node.parentId!, () => []).add(node);
      }
    }

    // Recursively attach children
    List<ServiceTreeNode> buildChildren(ServiceTreeNode node) {
      final children = childrenMap[node.id] ?? [];
      return [
        for (final child in children)
          child.copyWith(children: buildChildren(child)),
      ];
    }

    final builtRoots = [
      for (final root in roots)
        root.copyWith(children: buildChildren(root)),
    ];

    return ServiceTree(roots: builtRoots);
  } catch (e) {
    debugPrint('Service tree error: $e');
    return ServiceTree.empty;
  }
});

/// Currently selected node ID in the tree.
final selectedServiceNodeProvider = StateProvider<String?>((ref) => null);

/// Expanded node IDs in the tree view.
final expandedServiceNodesProvider =
    StateProvider<Set<String>>((ref) => <String>{});
