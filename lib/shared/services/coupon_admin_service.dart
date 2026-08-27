import 'package:cloud_firestore/cloud_firestore.dart';

import '../../l10n/app_strings.dart';
import '../models/coupon.dart';
import 'push_trigger_service.dart';

/// إدارة الكوبونات من لوحة التحكم (إنشاء/تعديل/حذف) — القراءة والتحقق
/// أثناء الشراء يتمّان في [CouponService]. الكتابة هنا مقصورة على المدير
/// بقواعد Firestore، والعميل لا يقدر إلا زيادة usedCount عند استخدامه.
class CouponAdminService {
  CouponAdminService._internal();
  static final CouponAdminService instance = CouponAdminService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _coupons =>
      _firestore.collection('coupons');

  /// بث كل الكوبونات (معرّف المستند هو رمز الكوبون نفسه)
  Stream<List<Coupon>> watchCoupons() {
    return _coupons.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Coupon.fromMap(doc.data(), doc.id))
              .toList()
            ..sort((a, b) => a.code.compareTo(b.code)),
        );
  }

  /// إنشاء/تعديل كوبون — الرمز يُخزَّن دائماً بحروف كبيرة ليطابق البحث
  /// الذي يجريه [CouponService] عند تطبيق الكوبون في السلة
  Future<void> saveCoupon(Coupon coupon) async {
    final code = coupon.code.trim().toUpperCase();
    if (code.isEmpty) throw ArgumentError('code required');
    await _coupons.doc(code).set(_sanitize(coupon.toMap()), SetOptions(merge: true));
  }

  Future<void> deleteCoupon(String code) async {
    await _coupons.doc(code.trim().toUpperCase()).delete();
  }

  /// إشعار الفئة المستهدفة بالكوبون الجديد.
  ///
  /// - [CouponAudience.all]: بثّ عام لكل المشتركين (رسالة واحدة).
  /// - الفئات الأخرى: نحدّد العملاء المطابقين من طلباتهم الفعلية ثم نرسل
  ///   لكل واحد إشعاراً موجَّهاً — لأن البثّ العام سيزعج من لا يستحق الكوبون
  ///   ولن يستطيع استخدامه أصلاً (التحقق يمنعه في [CouponService]).
  Future<void> notifyAudience(Coupon coupon) async {
    final title = AppStrings.couponNotifTitle;
    final body = AppStrings.couponNotifBody.replaceFirst('{code}', coupon.code);

    if (coupon.audience == CouponAudience.all) {
      await PushTriggerService.instance.notify(title: title, body: body);
      return;
    }

    final userIds = await _matchingUserIds(coupon);
    for (final uid in userIds) {
      await PushTriggerService.instance.notify(
        title: title,
        body: body,
        userId: uid,
      );
    }
  }

  /// سقف الفحص عند تحديد الفئة المستهدفة — بلا سقف كانت الدالة تقرأ **كل**
  /// المستخدمين و**كل** الطلبات في كل مرة يُحفظ كوبون، وهذا ينمو بلا حدود
  /// مع نمو المتجر (تكلفة قراءات + احتمال نفاد الذاكرة).
  static const int _scanLimit = 1000;

  /// معرّفات العملاء المطابقين لفئة الكوبون، محسوبة من مجموعة الطلبات
  Future<List<String>> _matchingUserIds(Coupon coupon) async {
    final users = await _firestore.collection('users').limit(_scanLimit).get();
    final orders = await _firestore.collection('orders').limit(_scanLimit).get();

    // إجمالي مشتريات كل عميل
    final spentByUser = <String, double>{};
    for (final doc in orders.docs) {
      final data = doc.data();
      final uid = data['userId'] as String? ?? '';
      if (uid.isEmpty) continue;
      spentByUser[uid] =
          (spentByUser[uid] ?? 0) + ((data['total'] as num?)?.toDouble() ?? 0);
    }

    final result = <String>[];
    for (final doc in users.docs) {
      final uid = doc.id;
      final spent = spentByUser[uid] ?? 0;
      final matches = switch (coupon.audience) {
        CouponAudience.newCustomers => !spentByUser.containsKey(uid),
        CouponAudience.bigSpenders => spent >= coupon.minTotalSpent,
        CouponAudience.all => true,
      };
      if (matches) result.add(uid);
    }
    return result;
  }

  /// Firestore لا يقبل قيم null
  Map<String, dynamic> _sanitize(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) result[key] = value;
    });
    return result;
  }
}
