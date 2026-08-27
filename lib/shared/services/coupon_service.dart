import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/coupon.dart';

/// خطأ كوبون برسالة عربية قابلة للعرض مباشرة
class CouponException implements Exception {
  CouponException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// خدمة الكوبونات - التحقق والخصم والاستهلاك عبر Firestore
/// مع كوبونات تجريبية محلية عند تعذر الاتصال أو خلو قاعدة البيانات
class CouponService {
  CouponService._internal();
  static final CouponService instance = CouponService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// كوبونات تجريبية تُستخدم كبديل عند عدم وجود كوبونات في الخادم
  static final List<Coupon> _demoCoupons = [
    Coupon(
      code: 'WELCOME10',
      type: CouponType.percentage,
      discountValue: 10,
      minOrderAmount: 100,
      maxDiscount: 100,
    ),
    Coupon(
      code: 'SAVE50',
      type: CouponType.fixed,
      discountValue: 50,
      minOrderAmount: 300,
    ),
    Coupon(
      code: 'FREESHIP',
      type: CouponType.freeShipping,
      discountValue: 0,
      minOrderAmount: 150,
    ),
  ];

  /// جلب كوبون من المصدر (Firestore ثم بديل تجريبي)
  Future<Coupon?> _fetchCoupon(String code) async {
    try {
      final doc = await _firestore.collection('coupons').doc(code).get();
      if (doc.exists) return Coupon.fromMap(doc.data()!, doc.id);
    } catch (_) {
      // بلا اتصال: نستخدم البديل التجريبي
    }
    for (final coupon in _demoCoupons) {
      if (coupon.code == code) return coupon;
    }
    return null;
  }

  /// التحقق من الكوبون وتطبيقه على السلة
  ///
  /// يرمي [CouponException] برسالة واضحة إن لم يكن الكوبون صالحاً
  Future<Coupon> validate(
    String code, {
    required double subtotal,
    List<String> productIds = const [],
    List<String> categoryIds = const [],
    String? userId,
  }) async {
    final coupon = await _fetchCoupon(code.trim().toUpperCase());
    if (coupon == null) throw CouponException('كوبون غير صالح');

    _assertRules(
      coupon,
      subtotal: subtotal,
      productIds: productIds,
      categoryIds: categoryIds,
    );
    if (coupon.perUserLimit != null && userId != null) {
      final usedByUser = await _countUserUsage(coupon.code, userId);
      if (usedByUser >= coupon.perUserLimit!) {
        throw CouponException('لقد استخدمت هذا الكوبون مسبقاً');
      }
    }
    await _assertAudience(coupon, userId);
    return coupon;
  }

  /// التحقق أن العميل ضمن الفئة المستهدفة بالكوبون (عملاء جدد / كبار
  /// المشترين) — يُحسب من طلباته الفعلية في Firestore
  Future<void> _assertAudience(Coupon coupon, String? userId) async {
    if (coupon.audience == CouponAudience.all) return;
    if (userId == null) {
      throw CouponException('هذا الكوبون يتطلب تسجيل الدخول');
    }

    final List<QueryDocumentSnapshot<Map<String, dynamic>>> orders;
    try {
      final snapshot = await _firestore
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      orders = snapshot.docs;
    } catch (_) {
      // تعذّر التحقق (بلا اتصال): لا نمنع العميل بسبب عطل تقني
      return;
    }

    switch (coupon.audience) {
      case CouponAudience.newCustomers:
        if (orders.isNotEmpty) {
          throw CouponException('هذا الكوبون مخصص للعملاء الجدد فقط');
        }
      case CouponAudience.bigSpenders:
        final total = orders.fold<double>(
          0,
          (acc, doc) => acc + ((doc.data()['total'] as num?)?.toDouble() ?? 0),
        );
        if (total < coupon.minTotalSpent) {
          throw CouponException(
            'هذا الكوبون لعملاء تجاوزت مشترياتهم '
            '${coupon.minTotalSpent.toStringAsFixed(0)} ر.س',
          );
        }
      case CouponAudience.all:
        break;
    }
  }

  /// قواعد التحقق النقية (تُختبر وحدها دون اتصال)
  @visibleForTesting
  void assertRules(
    Coupon coupon, {
    required double subtotal,
    List<String> productIds = const [],
    List<String> categoryIds = const [],
  }) =>
      _assertRules(coupon, subtotal: subtotal, productIds: productIds, categoryIds: categoryIds);

  void _assertRules(
    Coupon coupon, {
    required double subtotal,
    required List<String> productIds,
    required List<String> categoryIds,
  }) {
    if (!coupon.isActive) throw CouponException('هذا الكوبون معطّل');
    if (coupon.expiryDate != null &&
        DateTime.now().isAfter(coupon.expiryDate!)) {
      throw CouponException('انتهت صلاحية هذا الكوبون');
    }
    if (coupon.usageLimit != null && coupon.usedCount >= coupon.usageLimit!) {
      throw CouponException('تم استنفاد عدد استخدامات هذا الكوبون');
    }
    if (subtotal < coupon.minOrderAmount) {
      throw CouponException(
        'الحد الأدنى للطلب بهذا الكوبون ${coupon.minOrderAmount.toStringAsFixed(0)} ر.س',
      );
    }
    if (!_isApplicable(coupon,
        productIds: productIds, categoryIds: categoryIds)) {
      throw CouponException('هذا الكوبون لا ينطبق على منتجاتك الحالية');
    }
  }

  /// هل ينطبق الكوبون على منتجات السلة؟
  bool _isApplicable(
    Coupon coupon, {
    required List<String> productIds,
    required List<String> categoryIds,
  }) {
    if (coupon.applicableProductIds.isEmpty &&
        coupon.applicableCategoryIds.isEmpty) {
      return true;
    }
    final hasProduct = coupon.applicableProductIds
        .any((id) => productIds.contains(id));
    final hasCategory = coupon.applicableCategoryIds
        .any((id) => categoryIds.contains(id));
    return hasProduct || hasCategory;
  }

  /// حساب قيمة الخصم النقدي من الكوبون
  double calculateDiscount(Coupon coupon, double subtotal) {
    switch (coupon.type) {
      case CouponType.percentage:
        var amount = subtotal * coupon.discountValue / 100;
        if (coupon.maxDiscount != null && amount > coupon.maxDiscount!) {
          amount = coupon.maxDiscount!;
        }
        return amount;
      case CouponType.fixed:
        return coupon.discountValue.clamp(0, subtotal);
      case CouponType.freeShipping:
        return 0;
    }
  }

  // استهلاك الكوبون (usedCount/usedBy) لا يُكتب من العميل إطلاقاً — قواعد
  // Firestore تمنع ذلك (allow write: if isAdmin() فقط). الاستهلاك الفعلي
  // يتم حصراً داخل push-server/api/order.js بامتيازات حساب خدمة، بعد
  // إعادة التحقق من كل شروط الكوبون على الخادم، منعاً للتلاعب بعدد
  // الاستخدامات.

  Future<int> _countUserUsage(String code, String userId) async {
    try {
      final doc = await _firestore.collection('coupons').doc(code).get();
      final usedBy = (doc.data()?['usedBy'] as List?)?.cast<String>() ?? [];
      return usedBy.where((uid) => uid == userId).length;
    } catch (_) {
      return 0;
    }
  }
}
