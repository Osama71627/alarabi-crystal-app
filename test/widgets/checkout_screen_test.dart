import 'package:alarabi_crystal/features/cart/presentation/pages/checkout_screen.dart';
import 'package:alarabi_crystal/shared/models/coupon.dart';
import 'package:alarabi_crystal/shared/services/cart_service.dart';
import 'package:alarabi_crystal/shared/services/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  final cart = CartService.instance;

  setUp(() {
    cart.resetForTest();
  });

  Future<void> pumpCheckout(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: CheckoutScreen()));
    await tester.pumpAndSettle();
  }

  Finder paymentOption(String title) => find.widgetWithText(ListTile, title);

  Future<void> scrollTo(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
  }

  testWidgets('يعرض حقول عنوان التوصيل وطرق الدفع', (tester) async {
    await cart.addItem(makeCartItem('p1', price: 100));
    await pumpCheckout(tester);

    // حقول العنوان الأربعة (حقل الملاحظات خارج نافذة العرض)
    expect(find.byType(TextField), findsNWidgets(4));

    // الدفع عند الاستلام محدد افتراضياً
    expect(paymentOption('الدفع عند الاستلام'), findsOneWidget);
    expect(
      find.descendant(
        of: paymentOption('الدفع عند الاستلام'),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );

    // طريقة الدفع الأخرى (التحويل البنكي) تظهر عند التمرير
    await scrollTo(tester, 'التحويل البنكي');
    expect(paymentOption('التحويل البنكي'), findsOneWidget);

    // حقل الملاحظات يظهر عند التمرير
    await scrollTo(tester, 'ملاحظات على الطلب');
    expect(find.textContaining('أي ملاحظات'), findsOneWidget);
  });

  testWidgets('اختيار طريقة الدفع يحدّث الاختيار', (tester) async {
    await cart.addItem(makeCartItem('p1', price: 100));
    await pumpCheckout(tester);

    await scrollTo(tester, 'التحويل البنكي');
    await tester.tap(paymentOption('التحويل البنكي'));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: paymentOption('التحويل البنكي'),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: paymentOption('الدفع عند الاستلام'),
        matching: find.byIcon(Icons.radio_button_checked),
      ),
      findsNothing,
    );
  });

  testWidgets('ملخص الطلب: منتجات + شحن', (tester) async {
    await cart.addItem(makeCartItem('p1', price: 100));
    await cart.addItem(makeCartItem('p2', price: 200));
    await pumpCheckout(tester);

    // subtotal 300 < 500 → شحن 25 → الإجمالي 325
    await scrollTo(tester, 'الإجمالي الفرعي');
    expect(find.text('الإجمالي الفرعي'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(300)), findsWidgets);
    expect(find.text('الشحن'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(25)), findsWidgets);
    expect(find.text('الإجمالي'), findsWidgets);
    expect(find.text(CurrencyFormatter.format(325)), findsWidgets);

    // زر التأكيد يعرض الإجمالي
    expect(
      find.text('تأكيد • ${CurrencyFormatter.format(325)}'),
      findsOneWidget,
    );
  });

  testWidgets('شحن مجاني عند تجاوز 500 ر.س', (tester) async {
    await cart.addItem(makeCartItem('p1', price: 600));
    await pumpCheckout(tester);

    await scrollTo(tester, 'شحن مجاني');
    expect(find.text('شحن مجاني'), findsOneWidget);
    expect(find.text('الإجمالي'), findsWidgets);
    expect(find.text(CurrencyFormatter.format(600)), findsWidgets);
  });

  testWidgets('الخصم يُطرح من الإجمالي مع رسوم الشحن', (tester) async {
    await cart.addItem(makeCartItem('p1', price: 200));
    cart.applyCoupon(
      const Coupon(
        code: 'T',
        type: CouponType.percentage,
        discountValue: 10,
      ),
    );
    await pumpCheckout(tester);

    // 200 - 20 + 25 = 205
    await scrollTo(tester, 'الخصم (T)');
    expect(find.textContaining('-${CurrencyFormatter.format(20)}'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(205)), findsWidgets);
    expect(
      find.text('تأكيد • ${CurrencyFormatter.format(205)}'),
      findsOneWidget,
    );
  });
}
