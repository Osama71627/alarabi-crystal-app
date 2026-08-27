import 'package:alarabi_crystal/shared/models/offer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Offer model', () {
    test('isValid يعود true لعرض نشط بلا حدود زمنية', () {
      final offer = const Offer(id: 'o1', title: 'عرض', type: OfferType.flash);
      expect(offer.isValid, isTrue);
    });

    test('isValid يعود false لعرض معطل', () {
      final offer = const Offer(
        id: 'o1',
        title: 'عرض',
        type: OfferType.flash,
        isActive: false,
      );
      expect(offer.isValid, isFalse);
    });

    test('isValid يعود false بعد تاريخ الانتهاء', () {
      final offer = Offer(
        id: 'o1',
        title: 'عرض',
        type: OfferType.flash,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(offer.isValid, isFalse);
    });

    test('isValid يعود false قبل تاريخ البدء', () {
      final offer = Offer(
        id: 'o1',
        title: 'عرض',
        type: OfferType.flash,
        startDate: DateTime.now().add(const Duration(days: 1)),
      );
      expect(offer.isValid, isFalse);
    });

    test('isValid يعود false عند استنفاد حد الاستخدام', () {
      final offer = const Offer(
        id: 'o1',
        title: 'عرض',
        type: OfferType.flash,
        usageLimit: 5,
        usedCount: 5,
      );
      expect(offer.isValid, isFalse);
    });

    test('isFlash يعود true لعروض الفلاش فقط', () {
      expect(
        const Offer(id: 'o1', title: 'x', type: OfferType.flash).isFlash,
        isTrue,
      );
      expect(
        const Offer(id: 'o1', title: 'x', type: OfferType.fixed).isFlash,
        isFalse,
      );
    });

    test('remainingTime يعيد المدة المتبقية للعرض المحدود', () {
      final offer = Offer(
        id: 'o1',
        title: 'عرض',
        type: OfferType.flash,
        endDate: DateTime.now().add(const Duration(hours: 5)),
      );
      final remaining = offer.remainingTime!;
      // ليس inHours == 5 بالضبط: أي أجزاء ثانية تمرّ بين إنشاء العرض وقراءة
      // المدة تجعلها 4:59:59.99 فيصبح inHours == 4 والاختبار يفشل عشوائياً
      // حسب حمل الجهاز. نتحقق من نافذة دقيقة واحدة حول الخمس ساعات.
      expect(remaining.inMinutes, closeTo(300, 1));
    });

    test('badgeLabel حسب النوع', () {
      expect(
        const Offer(
          id: 'o1',
          title: 'x',
          type: OfferType.percentage,
          discountValue: 25,
        ).badgeLabel,
        '-25%',
      );
      expect(
        const Offer(
          id: 'o1',
          title: 'x',
          type: OfferType.bundle,
          buyQuantity: 2,
          getQuantity: 1,
        ).badgeLabel,
        '2+1',
      );
    });

    test('fromMap/toMap يعيدان نفس القيم', () {
      final offer = Offer(
        id: 'o1',
        title: 'عرض الفلاش',
        description: 'وصف',
        type: OfferType.flash,
        discountValue: 40,
        applicableType: OfferApplicableType.category,
        applicableIds: const ['cat_italian_crystal'],
        minPurchase: 200,
        maxDiscount: 500,
        endDate: DateTime(2026, 12, 31),
        displayOrder: 2,
      );
      final restored = Offer.fromMap(offer.toMap(), 'o1');
      expect(restored.id, offer.id);
      expect(restored.title, offer.title);
      expect(restored.type, offer.type);
      expect(restored.discountValue, offer.discountValue);
      expect(restored.applicableIds, offer.applicableIds);
      expect(restored.minPurchase, offer.minPurchase);
      expect(restored.maxDiscount, offer.maxDiscount);
      expect(restored.endDate, offer.endDate);
      expect(restored.displayOrder, offer.displayOrder);
    });

    test('fromMap يتحمل الحقول الناقصة بقيم افتراضية', () {
      final offer = Offer.fromMap(const {'title': 'x'}, 'o1');
      expect(offer.type, OfferType.percentage);
      expect(offer.applicableType, OfferApplicableType.all);
      expect(offer.discountValue, 0);
      expect(offer.isActive, isTrue);
    });
  });
}
