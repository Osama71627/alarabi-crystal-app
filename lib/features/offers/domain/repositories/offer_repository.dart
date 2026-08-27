import '../../../../shared/models/offer.dart';

/// واجهة مستودع العروض
abstract class OfferRepository {
  /// جلب العروض النشطة والسارية
  Future<List<Offer>> getActiveOffers();

  /// جلب جميع العروض (للوحة الإدارة)
  Future<List<Offer>> getAllOffers();

  /// بث جميع العروض (محدث تلقائياً - للوحة الإدارة)
  Stream<List<Offer>> watchOffers();

  /// إضافة عرض جديد
  Future<void> addOffer(Offer offer);

  /// تحديث عرض موجود
  Future<void> updateOffer(Offer offer);

  /// حذف عرض
  Future<void> deleteOffer(String id);
}
