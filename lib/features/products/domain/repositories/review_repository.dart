import '../../../../shared/models/review.dart';

/// مستودع تقييمات المنتجات
abstract class ReviewRepository {
  /// بث تقييمات منتج معيّن (الأحدث أولاً)
  Stream<List<Review>> watchReviews(String productId);

  /// إضافة تقييم جديد
  Future<void> addReview(Review review);
}

/// خطأ حفظ مراجعة برسالة عربية قابلة للعرض مباشرة
class ReviewException implements Exception {
  ReviewException(this.message);

  final String message;

  @override
  String toString() => message;
}
