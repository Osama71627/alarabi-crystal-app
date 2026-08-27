/// حسابات إجماليات الطلب (منتجات + شحن - خصم)
/// فئة نقية قابلة للاختبار دون اتصال
class OrderTotals {
  OrderTotals._();

  /// الحد الذي يصبح الشحن عنده مجانياً
  static const double freeShippingThreshold = 500;

  /// رسوم الشحن الثابتة
  static const double shippingFee = 25;

  /// رسوم الشحن: مجاني فوق الحد أو عند كوبون شحن مجاني
  static double shippingFeeFor({
    required double subtotal,
    required bool freeShippingApplied,
  }) {
    if (subtotal >= freeShippingThreshold || freeShippingApplied) return 0;
    return shippingFee;
  }

  /// الإجمالي النهائي = المنتجات + الشحن - الخصم
  static double total({
    required double subtotal,
    required double discount,
    required double shippingFee,
  }) {
    final value = subtotal - discount + shippingFee;
    return value < 0 ? 0 : value;
  }
}
