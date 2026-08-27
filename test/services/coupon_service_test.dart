import 'package:alarabi_crystal/shared/models/coupon.dart';
import 'package:alarabi_crystal/shared/services/coupon_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = CouponService.instance;

  group('calculateDiscount', () {
    test('نسبة مئوية مع سقف خصم أقصى', () {
      final coupon = Coupon(
        code: 'P',
        type: CouponType.percentage,
        discountValue: 20,
        maxDiscount: 50,
      );
      expect(service.calculateDiscount(coupon, 100), 20);
      expect(service.calculateDiscount(coupon, 400), 50);
    });

    test('نسبة مئوية دون سقف', () {
      final coupon = Coupon(
        code: 'P',
        type: CouponType.percentage,
        discountValue: 10,
      );
      expect(service.calculateDiscount(coupon, 250), 25);
    });

    test('خصم ثابت لا يتجاوز الإجمالي', () {
      final coupon = Coupon(
        code: 'F',
        type: CouponType.fixed,
        discountValue: 100,
      );
      expect(service.calculateDiscount(coupon, 300), 100);
      expect(service.calculateDiscount(coupon, 50), 50);
    });

    test('الشحن المجاني خصمه صفر', () {
      final coupon = Coupon(
        code: 'S',
        type: CouponType.freeShipping,
        discountValue: 0,
      );
      expect(service.calculateDiscount(coupon, 500), 0);
    });
  });

  group('assertRules (قواعد نقيّة دون اتصال)', () {
    Coupon valid() => Coupon(code: 'OK', type: CouponType.fixed, discountValue: 10);

    test('يقبل كوبوناً صالحاً', () {
      expect(() => service.assertRules(valid(), subtotal: 100), returnsNormally);
    });

    test('يرفض كوبوناً معطّلاً', () {
      final coupon = Coupon(
        code: 'OFF',
        type: CouponType.fixed,
        discountValue: 10,
        isActive: false,
      );
      expect(
        () => service.assertRules(coupon, subtotal: 100),
        throwsA(isA<CouponException>()),
      );
    });

    test('يرفض كوبوناً منتهي الصلاحية', () {
      final coupon = Coupon(
        code: 'EXP',
        type: CouponType.fixed,
        discountValue: 10,
        expiryDate: DateTime(2020, 1, 1),
      );
      expect(
        () => service.assertRules(coupon, subtotal: 100),
        throwsA(isA<CouponException>()),
      );
    });

    test('يرفض كوبوناً مستنفد الاستخدام', () {
      final coupon = Coupon(
        code: 'USED',
        type: CouponType.fixed,
        discountValue: 10,
        usageLimit: 5,
        usedCount: 5,
      );
      expect(
        () => service.assertRules(coupon, subtotal: 100),
        throwsA(isA<CouponException>()),
      );
    });

    test('يرفض الطلب دون الحد الأدنى', () {
      final coupon = Coupon(
        code: 'MIN',
        type: CouponType.fixed,
        discountValue: 10,
        minOrderAmount: 300,
      );
      expect(
        () => service.assertRules(coupon, subtotal: 100),
        throwsA(isA<CouponException>()),
      );
    });

    test('يرفض كوبوناً لا ينطبق على المنتجات/التصنيفات', () {
      final coupon = Coupon(
        code: 'REST',
        type: CouponType.fixed,
        discountValue: 10,
        applicableProductIds: ['p1'],
        applicableCategoryIds: ['c1'],
      );
      expect(
        () => service.assertRules(coupon,
            subtotal: 100, productIds: ['p9'], categoryIds: ['c9']),
        throwsA(isA<CouponException>()),
      );
    });

    test('يقبل كوبوناً ينطبق على أحد المنتجات', () {
      final coupon = Coupon(
        code: 'REST',
        type: CouponType.fixed,
        discountValue: 10,
        applicableProductIds: ['p1'],
      );
      expect(
        () => service.assertRules(coupon,
            subtotal: 100, productIds: ['p1', 'p2'], categoryIds: const []),
        returnsNormally,
      );
    });
  });

  group('validate (البديل التجريبي عند غياب الخادم)', () {
    test('يقبل WELCOME10 فوق الحد الأدنى', () async {
      final coupon = await service.validate('WELCOME10', subtotal: 200);
      expect(coupon.code, 'WELCOME10');
    });

    test('يرفض كوبوناً غير معروف', () async {
      await expectLater(
        service.validate('NOPE', subtotal: 500),
        throwsA(isA<CouponException>()),
      );
    });

    test('يرفض طلباً دون الحد الأدنى', () async {
      await expectLater(
        service.validate('WELCOME10', subtotal: 50),
        throwsA(isA<CouponException>()),
      );
    });
  });

  group('الفئة المستهدفة بالكوبون', () {
    test('الافتراضي: متاح لكل العملاء', () {
      const coupon = Coupon(
        code: 'X',
        type: CouponType.fixed,
        discountValue: 10,
      );
      expect(coupon.audience, CouponAudience.all);
      expect(coupon.minTotalSpent, 0);
    });

    test('تُحفظ الفئة والحد وتُقرأ كما هي (toMap/fromMap)', () {
      const original = Coupon(
        code: 'VIP',
        type: CouponType.percentage,
        discountValue: 15,
        audience: CouponAudience.bigSpenders,
        minTotalSpent: 10000,
      );
      final restored = Coupon.fromMap(original.toMap(), 'VIP');
      expect(restored.audience, CouponAudience.bigSpenders);
      expect(restored.minTotalSpent, 10000);
    });

    test('فئة غير معروفة في البيانات تُعامَل كـ "كل العملاء" لا كخطأ', () {
      final restored = Coupon.fromMap(
        {'type': 'fixed', 'discountValue': 5, 'audience': 'something_new'},
        'Y',
      );
      expect(restored.audience, CouponAudience.all);
    });
  });
}
