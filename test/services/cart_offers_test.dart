import 'dart:io';

import 'package:alarabi_crystal/shared/models/offer.dart';
import 'package:alarabi_crystal/shared/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../test_helpers.dart';

void main() {
  final cart = CartService.instance;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cart_offer_test');
    Hive.init(tempDir.path);
    await cart.initForTest();
    cart.resetForTest();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('تطبيق عرض نسبة مئوية يحسب الخصم', () async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyOffer(
      makeOffer('o1', type: OfferType.percentage, discountValue: 10),
    );
    expect(cart.appliedOffer, isNotNull);
    expect(cart.offerDiscount, 20);
  });

  test('تطبيق عرض فلاش بحد زمني يعمل أثناء صلاحيته', () async {
    await cart.addItem(makeCartItem('p1', price: 300));
    cart.applyOffer(
      makeOffer(
        'o1',
        type: OfferType.flash,
        discountValue: 40,
        endDate: DateTime.now().add(const Duration(hours: 5)),
      ),
    );
    expect(cart.offerDiscount, 120);
  });

  test('عرض منتهي لا يعطي خصماً', () async {
    await cart.addItem(makeCartItem('p1', price: 300));
    cart.applyOffer(
      makeOffer(
        'o1',
        type: OfferType.flash,
        discountValue: 40,
        endDate: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    );
    expect(cart.offerDiscount, 0);
  });

  test('الحد الأدنى للشراء يمنع الخصم', () async {
    await cart.addItem(makeCartItem('p1', price: 100));
    cart.applyOffer(
      makeOffer(
        'o1',
        type: OfferType.fixed,
        discountValue: 50,
        minPurchase: 300,
      ),
    );
    expect(cart.offerDiscount, 0);
  });

  test('عرض مجمع يحسب القطع المجانية من عناصر السلة', () async {
    await cart.addItem(
      makeCartItem('p1', price: 100, quantity: 4, categoryId: 'cat_vases'),
    );
    cart.applyOffer(
      makeOffer(
        'o1',
        type: OfferType.bundle,
        buyQuantity: 2,
        getQuantity: 1,
        applicableType: OfferApplicableType.category,
        applicableIds: const ['cat_vases'],
      ),
    );
    expect(cart.offerDiscount, 200);
  });

  test('إزالة العرض يعيد الحساب الطبيعي', () async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyOffer(
      makeOffer('o1', type: OfferType.percentage, discountValue: 10),
    );
    expect(cart.offerDiscount, 20);
    cart.removeAppliedOffer();
    expect(cart.appliedOffer, isNull);
    expect(cart.offerDiscount, 0);
  });

  test('إفراغ السلة يزيل العرض المطبق', () async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyOffer(
      makeOffer('o1', type: OfferType.percentage, discountValue: 10),
    );
    await cart.clear();
    expect(cart.items, isEmpty);
    expect(cart.appliedOffer, isNull);
    expect(cart.offerDiscount, 0);
  });

  test('خصم العرض يتحدّث مع تغيير محتويات السلة', () async {
    cart.applyOffer(
      makeOffer('o1', type: OfferType.percentage, discountValue: 10),
    );
    await cart.addItem(makeCartItem('p1', price: 100));
    expect(cart.offerDiscount, 10);
    await cart.addItem(makeCartItem('p2', price: 300));
    expect(cart.offerDiscount, 40);
  });
}
