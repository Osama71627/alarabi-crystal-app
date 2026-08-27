import 'package:alarabi_crystal/shared/models/order.dart';
import 'package:alarabi_crystal/shared/services/order_totals.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('OrderTotals: الشحن', () {
    test('أقل من 500 ر.س يفرض رسوم شحن ثابتة', () {
      expect(
        OrderTotals.shippingFeeFor(subtotal: 499, freeShippingApplied: false),
        OrderTotals.shippingFee,
      );
    });

    test('عند 500 ر.س فما فوق يكون الشحن مجانياً', () {
      expect(
        OrderTotals.shippingFeeFor(subtotal: 500, freeShippingApplied: false),
        0,
      );
      expect(
        OrderTotals.shippingFeeFor(subtotal: 1200, freeShippingApplied: false),
        0,
      );
    });

    test('كوبون الشحن المجاني يلغي الرسوم حتى دون الحد', () {
      expect(
        OrderTotals.shippingFeeFor(subtotal: 200, freeShippingApplied: true),
        0,
      );
    });
  });

  group('OrderTotals: الإجمالي', () {
    test('الإجمالي = المنتجات + الشحن - الخصم', () {
      expect(
        OrderTotals.total(subtotal: 300, discount: 50, shippingFee: 25),
        275,
      );
    });

    test('لا ينزل الإجمالي تحت الصفر عند خصم أكبر من المنتجات', () {
      expect(
        OrderTotals.total(subtotal: 100, discount: 200, shippingFee: 0),
        0,
      );
    });

    test('خمسة مئة بدون خصم = المنتجات + الشحن', () {
      expect(
        OrderTotals.total(subtotal: 600, discount: 0, shippingFee: 0),
        600,
      );
    });
  });

  group('نموذج الطلب', () {
    test('toMap/fromMap يحافظ على العنوان وطريقة الدفع والخصم', () {
      final order = Order(
        id: 'ORD123',
        userId: 'u1',
        items: [makeCartItem('p1', price: 100, quantity: 2)],
        total: 275,
        paymentMethod: PaymentMethod.bankTransfer,
        shippingAddress: 'أحمد - 0500000000 - الشارع - الرياض',
        shippingFee: 25,
        discountAmount: 50,
        couponCode: 'SAVE50',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );

      final restored = Order.fromMap(order.toMap(), 'ORD123');

      expect(restored.id, 'ORD123');
      expect(restored.userId, 'u1');
      expect(restored.paymentMethod, PaymentMethod.bankTransfer);
      expect(restored.shippingAddress, 'أحمد - 0500000000 - الشارع - الرياض');
      expect(restored.shippingFee, 25);
      expect(restored.discountAmount, 50);
      expect(restored.couponCode, 'SAVE50');
      expect(restored.total, 275);
      expect(restored.items.single.productId, 'p1');
      expect(restored.items.single.quantity, 2);
    });

    test('subtotal يُحسب من العناصر', () {
      final order = Order(
        id: 'O1',
        userId: 'u1',
        items: [makeCartItem('p1', price: 100, quantity: 3)],
        total: 300,
      );
      expect(order.subtotal, 300);
    });

    test('الحقول الغائبة تتصرف بأمان', () {
      final order = Order.fromMap(const {}, 'EMPTY');
      expect(order.id, 'EMPTY');
      expect(order.status, OrderStatus.pending);
      expect(order.paymentMethod, PaymentMethod.cod);
      expect(order.total, 0);
      expect(order.items, isEmpty);
    });
  });
}
