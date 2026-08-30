import '../../../../shared/models/banner.dart';

/// واجهة مستودع بانرات الصفحة الرئيسية
abstract class BannerRepository {
  /// جلب البانرات المفعّلة، مرتّبة حسب ترتيب العرض
  Future<List<Banner>> getBanners();
}
