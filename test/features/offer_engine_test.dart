import 'package:alarabi_crystal/shared/models/offer.dart';
import 'package:alarabi_crystal/shared/services/offer_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('OfferEngine.isApplicable', () {
    test('نوع all ينطبق على أي سلة', () {
      final offer = makeOffer('o1', applicableType: OfferApplicableType.all);
      expect(
        OfferEngine.isApplicable(offer, productIds: const ['p1'], categoryIds: const []),
        isTrue,
      );
    });

    test('نوع product ينطبق عند وجود المنتج المحدد', () {
      final offer = makeOffer(
        'o1',
        applicableType: OfferApplicableType.product,
        applicableIds: const ['p2'],
      );
      expect(
        OfferEngine.isApplicable(offer, productIds: const ['p1', 'p2'], categoryIds: const []),
        isTrue,
      );
      expect(
        OfferEngine.isApplicable(offer, productIds: const ['p1'], categoryIds: const []),
        isFalse,
      );
    });

    test('نوع category ينطبق عند وجود الفئة المحددة', () {
      final offer = makeOffer(
        'o1',
        applicableType: OfferApplicableType.category,
        applicableIds: const ['cat_italian_crystal'],
      );
      expect(
        OfferEngine.isApplicable(
          offer,
          productIds: const ['p1'],
          categoryIds: const ['cat_italian_crystal'],
        ),
        isTrue,
      );
    });

    test('عرض منتهي غير قابل للتطبيق', () {
      final offer = makeOffer(
        'o1',
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(
        OfferEngine.isApplicable(offer, productIds: const ['p1'], categoryIds: const []),
        isFalse,
      );
    });
  });

  group('OfferEngine.discountFor', () {
    test('نسبة مئوية تحسب من الإجمالي', () {
      final offer = makeOffer('o1', type: OfferType.percentage, discountValue: 10);
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 400,
        productIds: const ['p1'],
        categoryIds: const ['cat-1'],
        items: [makeCartItem('p1', price: 100, quantity: 4, categoryId: 'cat-1')],
      );
      expect(discount, 40);
    });

    test('نسبة مئوية تتقيد بأقصى خصم', () {
      final offer = makeOffer(
        'o1',
        type: OfferType.percentage,
        discountValue: 25,
        maxDiscount: 30,
      );
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 400,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100, quantity: 4)],
      );
      expect(discount, 30);
    });

    test('خصم ثابت يعيد قيمته ولا يتجاوز الإجمالي', () {
      final offer = makeOffer('o1', type: OfferType.fixed, discountValue: 50);
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 100,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100)],
      );
      expect(discount, 50);
    });

    test('خصم ثابت يتقيد بالإجمالي', () {
      final offer = makeOffer('o1', type: OfferType.fixed, discountValue: 200);
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 100,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100)],
      );
      expect(discount, 100);
    });

    test('عرض مجمع: اشترِ 2 واحصل على 1', () {
      final offer = makeOffer(
        'o1',
        type: OfferType.bundle,
        buyQuantity: 2,
        getQuantity: 1,
        applicableType: OfferApplicableType.product,
        applicableIds: const ['p1'],
      );
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 400,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100, quantity: 4)],
      );
      // 4 ÷ 2 = مجموعتان → قطعتان مجانيتان × 100
      expect(discount, 200);
    });

    test('عرض مجمع بلا كمية كافية يعيد صفراً', () {
      final offer = makeOffer(
        'o1',
        type: OfferType.bundle,
        buyQuantity: 3,
        getQuantity: 1,
        applicableType: OfferApplicableType.product,
        applicableIds: const ['p1'],
      );
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 200,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100, quantity: 2)],
      );
      expect(discount, 0);
    });

    test('عرض الأعضاء يتطلب تفعيل عضوية', () {
      final offer = makeOffer('o1', type: OfferType.member, discountValue: 10);
      final items = [makeCartItem('p1', price: 100, quantity: 2)];

      final withoutMember = OfferEngine.discountFor(
        offer,
        subtotal: 200,
        productIds: const ['p1'],
        categoryIds: const [],
        items: items,
        memberEligible: false,
      );
      expect(withoutMember, 0);

      final withMember = OfferEngine.discountFor(
        offer,
        subtotal: 200,
        productIds: const ['p1'],
        categoryIds: const [],
        items: items,
        memberEligible: true,
      );
      expect(withMember, 20);
    });

    test('الحد الأدنى للشراء يمنع الخصم عند عدم تحققه', () {
      final offer = makeOffer(
        'o1',
        type: OfferType.fixed,
        discountValue: 50,
        minPurchase: 300,
      );
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: 100,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100)],
      );
      expect(discount, 0);
    });
  });

  group('OfferEngine.bestOffer', () {
    test('يختار العرض الأعلى خصماً', () {
      final offers = [
        makeOffer('fixed', type: OfferType.fixed, discountValue: 30),
        makeOffer('percent', type: OfferType.percentage, discountValue: 25),
      ];
      final result = OfferEngine.bestOffer(
        offers,
        subtotal: 200,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 200)],
      );
      expect(result, isNotNull);
      expect(result!.offer.id, 'percent');
      expect(result.discount, 50);
    });

    test('يعيد null عندما لا ينطبق أي عرض', () {
      final offers = [
        makeOffer(
          'o1',
          type: OfferType.fixed,
          discountValue: 30,
          minPurchase: 1000,
        ),
      ];
      final result = OfferEngine.bestOffer(
        offers,
        subtotal: 100,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 100)],
      );
      expect(result, isNull);
    });

    test('يتجاهل عروض الأعضاء دون عضوية في الاختيار', () {
      final offers = [
        makeOffer('member', type: OfferType.member, discountValue: 50),
        makeOffer('fixed', type: OfferType.fixed, discountValue: 20),
      ];
      final result = OfferEngine.bestOffer(
        offers,
        subtotal: 200,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 200)],
        memberEligible: false,
      );
      expect(result!.offer.id, 'fixed');

      final withMember = OfferEngine.bestOffer(
        offers,
        subtotal: 200,
        productIds: const ['p1'],
        categoryIds: const [],
        items: [makeCartItem('p1', price: 200)],
        memberEligible: true,
      );
      expect(withMember!.offer.id, 'member');
    });
  });
}
