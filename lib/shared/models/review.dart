/// مراجعة المنتج
class Review {
  const Review({
    required this.id,
    required this.userId,
    required this.productId,
    required this.rating,
    required this.comment,
    this.userName = '',
    this.userAvatar,
    this.images = const [],
    this.createdAt,
    this.isVerified = false,
  });

  final String id;
  final String userId;
  final String productId;
  final double rating;
  final String comment;
  final String userName;
  final String? userAvatar;
  final List<String> images;
  final DateTime? createdAt;
  final bool isVerified;

  factory Review.fromMap(Map<String, dynamic> map, String id) {
    return Review(
      id: id,
      userId: map['userId'] as String? ?? '',
      productId: map['productId'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String? ?? '',
      userName: map['userName'] as String? ?? '',
      userAvatar: map['userAvatar'] as String?,
      images: (map['images'] as List?)?.cast<String>() ?? const [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      isVerified: map['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'productId': productId,
      'rating': rating,
      'comment': comment,
      'userName': userName,
      'userAvatar': userAvatar,
      'images': images,
      'createdAt': createdAt?.toIso8601String(),
      'isVerified': isVerified,
    };
  }
}
