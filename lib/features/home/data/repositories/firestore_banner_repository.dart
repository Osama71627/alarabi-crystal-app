import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/banner.dart';
import '../../domain/repositories/banner_repository.dart';

/// مستودع بانرات عبر Firestore — يديره المدير من لوحة التحكم (تطبيق فلاتر
/// أو لوحة الويب)، ويظهر لكل المستخدمين فور نشره بلا حاجة لتحديث التطبيق.
/// يعود للبيانات التجريبية إن كانت القاعدة فارغة أو تعذر الاتصال، حتى
/// تبقى الشاشة الرئيسية معروضة دائماً ولو لم يُضِف المدير أي بانر بعد.
class FirestoreBannerRepository implements BannerRepository {
  FirestoreBannerRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _banners =>
      _firestore.collection('banners');

  @override
  Future<List<Banner>> getBanners() async {
    try {
      final snapshot = await _banners.get();
      final banners = snapshot.docs
          .map((doc) => Banner.fromMap(doc.data(), doc.id))
          .where((b) => b.isActive)
          .toList()
        ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      if (banners.isEmpty) return DemoData.banners;
      return banners;
    } catch (_) {
      return DemoData.banners;
    }
  }
}
