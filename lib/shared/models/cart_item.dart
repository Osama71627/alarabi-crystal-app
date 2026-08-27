/// عنصر في السلة
class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.image,
    this.quantity = 1,
    this.stock = 0,
    this.discountPrice,
    this.categoryId,
  });

  final String productId;
  final String name;
  final double price;
  final String image;
  final int quantity;
  final int stock;
  final double? discountPrice;
  final String? categoryId;

  /// سعر الوحدة الفعلي
  double get unitPrice => discountPrice ?? price;

  /// السعر الإجمالي لهذا العنصر
  double get totalPrice => unitPrice * quantity;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'price': price,
      'image': image,
      'quantity': quantity,
      'stock': stock,
      'discountPrice': discountPrice,
      'categoryId': categoryId,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      productId: map['productId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      image: map['image'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      discountPrice: (map['discountPrice'] as num?)?.toDouble(),
      categoryId: map['categoryId'] as String?,
    );
  }

  CartItem copyWith({int? quantity, double? discountPrice, int? stock}) {
    return CartItem(
      productId: productId,
      name: name,
      price: price,
      image: image,
      quantity: quantity ?? this.quantity,
      stock: stock ?? this.stock,
      discountPrice: discountPrice ?? this.discountPrice,
      categoryId: categoryId,
    );
  }
}
