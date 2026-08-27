/// المنتج
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.categoryId,
    this.discountPrice,
    this.stock = 0,
    this.rating = 0,
    this.reviewCount = 0,
    this.specifications = const {},
    this.isFeatured = false,
    this.sku = '',
    this.brand = '',
    this.weight,
    this.createdAt,
    this.views = 0,
    this.soldCount = 0,
  });

  final String id;
  final String name;
  final String description;
  final double price;
  final double? discountPrice;
  final List<String> images;
  final String categoryId;
  final int stock;
  final double rating;
  final int reviewCount;
  final Map<String, String> specifications;
  final bool isFeatured;
  final String sku;
  final String brand;
  final double? weight;
  final DateTime? createdAt;
  final int views;
  final int soldCount;

  /// السعر الفعلي بعد الخصم
  double get effectivePrice => discountPrice ?? price;

  /// نسبة الخصم
  double get discountPercentage {
    if (discountPrice == null || discountPrice! >= price) return 0;
    return ((price - discountPrice!) / price * 100).roundToDouble();
  }

  /// هل يوجد خصم؟
  bool get hasDiscount => discountPrice != null && discountPrice! < price;

  /// هل المنتج متوفر؟
  bool get isInStock => stock > 0;

  /// هل الكمية محدودة؟
  bool get isLowStock => stock > 0 && stock <= 5;

  factory Product.fromMap(Map<String, dynamic> map, String id) {
    return Product(
      id: id,
      name: map['name'] as String? ?? '',
      description: map['description'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      discountPrice: (map['discountPrice'] as num?)?.toDouble(),
      images: (map['images'] as List?)?.cast<String>() ?? const [],
      categoryId: map['categoryId'] as String? ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: (map['reviewCount'] as num?)?.toInt() ?? 0,
      specifications:
          (map['specifications'] as Map?)?.cast<String, String>() ?? const {},
      isFeatured: map['isFeatured'] as bool? ?? false,
      sku: map['sku'] as String? ?? '',
      brand: map['brand'] as String? ?? '',
      weight: (map['weight'] as num?)?.toDouble(),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      views: (map['views'] as num?)?.toInt() ?? 0,
      soldCount: (map['soldCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'discountPrice': discountPrice,
      'images': images,
      'categoryId': categoryId,
      'stock': stock,
      'rating': rating,
      'reviewCount': reviewCount,
      'specifications': specifications,
      'isFeatured': isFeatured,
      'sku': sku,
      'brand': brand,
      'weight': weight,
      'createdAt': createdAt?.toIso8601String(),
      'views': views,
      'soldCount': soldCount,
    };
  }
}
