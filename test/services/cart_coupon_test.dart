import 'dart:io';

import 'package:alarabi_crystal/shared/models/coupon.dart';
import 'package:alarabi_crystal/shared/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../test_helpers.dart';

void main() {
  final cart = CartService.instance;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cart_test');
    Hive.init(tempDir.path);
    await cart.initForTest();
    cart.resetForTest();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('إضافة منتج جديد للسلة', () async {
    await cart.addItem(makeCartItem('p1', price: 100, quantity: 2));
    expect(cart.items.length, 1);
    expect(cart.items.first.quantity, 2);
    expect(cart.subtotal, 200);
  });

  test('إضافة نفس المنتج ترفع الكمية', () async {
    await cart.addItem(makeCartItem('p1', price: 100, quantity: 1));
    await cart.addItem(makeCartItem('p1', price: 100, quantity: 2));
    expect(cart.items.first.quantity, 3);
  });

  test('تحديث الكمية إلى صفر يزيل المنتج', () async {
    await cart.addItem(makeCartItem('p1', price: 100, quantity: 2));
    await cart.updateQuantity('p1', 0);
    expect(cart.items, isEmpty);
  });

  test('خصم نسبة مئوية من الإجمالي', () async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyCoupon(
      const Coupon(
        code: 'P',
        type: CouponType.percentage,
        discountValue: 10,
      ),
    );
    expect(cart.appliedCouponCode, 'P');
    expect(cart.couponDiscount, 20);
  });

  test('خصم ثابت لا يتجاوز الإجمالي', () async {
    await cart.addItem(makeCartItem('p1', price: 100));
    cart.applyCoupon(
      const Coupon(
        code: 'F',
        type: CouponType.fixed,
        discountValue: 150,
      ),
    );
    expect(cart.couponDiscount, 100);
  });

  test('كوبون شحن مجاني يفعل التوصيل المجاني', () async {
    await cart.addItem(makeCartItem('p1', price: 100));
    cart.applyCoupon(
      const Coupon(
        code: 'S',
        type: CouponType.freeShipping,
        discountValue: 0,
      ),
    );
    expect(cart.freeShippingApplied, isTrue);
    expect(cart.couponDiscount, 0);
  });

  test('إزالة الكوبون يعيد الحساب الطبيعي', () async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyCoupon(
      const Coupon(
        code: 'P',
        type: CouponType.percentage,
        discountValue: 10,
      ),
    );
    expect(cart.couponDiscount, 20);
    cart.clearCoupon();
    expect(cart.appliedCoupon, isNull);
    expect(cart.couponDiscount, 0);
  });

  test('إفراغ السلة يزيل الكوبون', () async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyCoupon(
      const Coupon(
        code: 'P',
        type: CouponType.percentage,
        discountValue: 10,
      ),
    );
    await cart.clear();
    expect(cart.items, isEmpty);
    expect(cart.appliedCoupon, isNull);
  });
}
