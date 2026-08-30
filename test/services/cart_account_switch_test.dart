// اختبارات إصلاح خلل حرج: كانت السلة تبقى مشتركة بين حسابين مختلفين على
// نفس الجهاز — أي منتج يضيفه حساب يظهر لأي حساب آخر يسجّل دخوله بعده،
// سواء بتبديل الحساب مباشرة أو بإعادة تشغيل التطبيق. راجع الشرح الكامل
// في CartService.setActiveUser.

import 'dart:io';

import 'package:alarabi_crystal/shared/services/cart_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../test_helpers.dart';

void main() {
  final cart = CartService.instance;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cart_switch_test');
    Hive.init(tempDir.path);
    await cart.initForTest();
    cart.resetForTest();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('الخروج ثم دخول حساب آخر يفرّغ سلة الحساب الأول (الخلل المُبلَّغ)', () async {
    await cart.setActiveUser('userA');
    await cart.addItem(makeCartItem('p1'));
    expect(cart.items.length, 1);

    await cart.setActiveUser(null); // تسجيل خروج
    expect(cart.items, isEmpty, reason: 'يجب أن تُفرَّغ السلة فور الخروج');

    await cart.setActiveUser('userB'); // دخول حساب آخر
    expect(cart.items, isEmpty, reason: 'سلة الحساب الأول لا يجب أن تظهر لحساب آخر');
  });

  test('تبديل مباشر بين حسابين بلا مرور بحالة الخروج يفرّغ السلة أيضاً', () async {
    await cart.setActiveUser('userA');
    await cart.addItem(makeCartItem('p1'));

    await cart.setActiveUser('userB'); // تبديل مباشر، بلا null بينهما
    expect(cart.items, isEmpty);
  });

  test('سلة الزائر (بلا حساب) تبقى محلياً وتُرحَّل لأول تسجيل دخول', () async {
    await cart.addItem(makeCartItem('guest-item'));
    expect(cart.items.length, 1);

    await cart.setActiveUser('userA'); // أول دخول فعلي هذه الجلسة
    expect(cart.items.length, 1, reason: 'سلة الزائر يجب أن تُرحَّل لا أن تُمسح');
    expect(cart.items.first.productId, 'guest-item');
  });

  test('بقايا سلة حساب سابق تُكتشف وتُفرَّغ عند إعادة تشغيل التطبيق', () async {
    await cart.setActiveUser('userA');
    await cart.addItem(makeCartItem('p1'));

    // محاكاة إعادة تشغيل حقيقية: تصفير الحالة داخل الذاكرة أولاً (كما
    // يحصل عند إنشاء عملية جديدة)، ثم إعادة فتح الصناديق من القرص —
    // السلة المحفوظة والعلامة المسجَّلة لصاحبها تبقيان كما هما
    cart.resetForTest();
    await cart.initForTest();
    expect(cart.items.length, 1, reason: 'التحميل الأولي من القرص كالمعتاد');

    await cart.setActiveUser('userB'); // مستخدم مختلف يدخل بعد إعادة التشغيل مباشرة
    expect(cart.items, isEmpty, reason: 'يجب اكتشاف أنها سلة حساب سابق لا سلة زائر');
  });

  test('نفس المستخدم يعيد فتح التطبيق فلا تُفرَّغ سلته الخاصة', () async {
    await cart.setActiveUser('userA');
    await cart.addItem(makeCartItem('p1'));

    cart.resetForTest();
    await cart.initForTest();

    await cart.setActiveUser('userA'); // نفس صاحب السلة يدخل من جديد
    expect(cart.items.length, 1, reason: 'سلة المستخدم نفسه لا تُفرَّغ');
  });
}
