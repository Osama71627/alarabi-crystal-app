/// فئة المنتج
class Category {
  const Category({
    required this.id,
    required this.name,
    required this.image,
    this.parentId,
    this.order = 0,
    this.icon = '',
    this.description = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final String image;
  final String? parentId;
  final int order;
  final String icon;
  final String description;
  final bool isActive;

  factory Category.fromMap(Map<String, dynamic> map, String id) {
    return Category(
      id: id,
      name: map['name'] as String? ?? '',
      image: map['image'] as String? ?? '',
      parentId: map['parentId'] as String?,
      order: (map['order'] as num?)?.toInt() ?? 0,
      icon: map['icon'] as String? ?? '',
      description: map['description'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'image': image,
      'parentId': parentId,
      'order': order,
      'icon': icon,
      'description': description,
      'isActive': isActive,
    };
  }
}
