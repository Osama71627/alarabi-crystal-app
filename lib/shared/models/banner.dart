/// البانر الإعلاني
class Banner {
  const Banner({
    required this.id,
    required this.title,
    this.image = '',
    this.description = '',
    this.linkType = BannerLinkType.none,
    this.linkTarget,
    this.isActive = true,
    this.displayOrder = 0,
    this.bgColorHex,
    this.createdAt,
  });

  final String id;
  final String title;
  final String image;
  final String description;
  final BannerLinkType linkType;
  final String? linkTarget; // معرّف المنتج/الفئة/العرض حسب linkType
  final bool isActive;
  final int displayOrder;
  final String? bgColorHex; // لون خلفية البانر بصيغة hex
  final DateTime? createdAt;

  factory Banner.fromMap(Map<String, dynamic> map, String id) {
    return Banner(
      id: id,
      title: map['title'] as String? ?? '',
      image: map['image'] as String? ?? '',
      description: map['description'] as String? ?? '',
      linkType: _linkTypeFromString(map['linkType'] as String? ?? 'none'),
      linkTarget: map['linkTarget'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      bgColorHex: map['bgColorHex'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'image': image,
      'description': description,
      'linkType': linkType.name,
      'linkTarget': linkTarget,
      'isActive': isActive,
      'displayOrder': displayOrder,
      'bgColorHex': bgColorHex,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static BannerLinkType _linkTypeFromString(String value) {
    return BannerLinkType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => BannerLinkType.none,
    );
  }
}

/// وجهة الرابط عند النقر على البانر
enum BannerLinkType { none, product, category, offer }
