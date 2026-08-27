import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/models/review.dart';
import '../../../../shared/services/review_api.dart';
import '../../domain/repositories/review_repository.dart' show ReviewException, ReviewRepository;

/// مستودع التقييمات — القراءة مباشرة من Firestore (عامة، بلا قيد)، والكتابة
/// (إنشاء/تعديل) عبر الخادم الموثوق حصراً (push-server/api/review.js).
///
/// ⚠️ قواعد Firestore تمنع أي كتابة مباشرة من العميل على مجموعة reviews
/// (`allow write: if false`) — الخادم وحده يكتب المراجعة ويعيد حساب
/// rating/reviewCount للمنتج ذرّياً، بامتيازات حساب خدمة تتجاوز القواعد.
/// هذا يغلق الثغرة القديمة (M2): لم يكن أي طرف يعيد حساب هذين الحقلين قط.
class FirestoreReviewRepository implements ReviewRepository {
  FirestoreReviewRepository({ReviewApi? reviewApi})
      : _reviewApi = reviewApi ?? ReviewApi();

  final ReviewApi _reviewApi;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reviews =>
      _firestore.collection('reviews');

  /// حدّ أعلى مقصود (المرحلة 13 — M6): منتج شهير بمراجعات كثيرة كان
  /// يحمّلها كلها دفعة واحدة بلا سقف. سخي بما يكفي لأي منتج فعلي حالياً.
  static const int _reviewsLimit = 200;

  @override
  Stream<List<Review>> watchReviews(String productId) {
    return _reviews
        .where('productId', isEqualTo: productId)
        .orderBy('createdAt', descending: true)
        .limit(_reviewsLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Review.fromMap(doc.data(), doc.id))
            .toList());
  }

  @override
  Future<void> addReview(Review review) async {
    try {
      await _reviewApi.upsert(
        productId: review.productId,
        rating: review.rating,
        comment: review.comment,
        userName: review.userName,
        images: review.images,
      );
    } on ReviewApiException catch (e) {
      throw ReviewException(e.message);
    } on ReviewApiUnavailable catch (_) {
      throw ReviewException('تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى');
    }
  }
}
