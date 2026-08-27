import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/cart_item.dart';
import '../models/order.dart';
import 'order_api.dart';

/// خطأ إنشاء طلب برسالة عربية قابلة للعرض مباشرة
class OrderException implements Exception {
  OrderException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// خدمة الطلبات.
///
/// إنشاء الطلب مصدره الوحيد الخادم الموثوق (push-server/api/order.js):
/// يتحقق من هوية العميل عبر توقيع Firebase، يقرأ الأسعار والمخزون والكوبون
/// والعروض من Firestore طازجة، يحسب كل مبلغ بنفسه، ثم يحجز المخزون ويستهلك
/// الكوبون وينشئ الطلب ذرّياً بامتيازات حساب خدمة.
///
/// ⚠️ لا يوجد مسار محلي بديل لإنشاء الطلب (أُزيل في المرحلة 11 بعد تشديد
/// قواعد Firestore التي تمنع الآن أي إنشاء طلب أو تعديل مخزون/كوبون من
/// العميل مباشرة — `orders create: if false`). فشل الاتصال بالخادم يُعرض
/// للعميل كخطأ صريح يسمح بإعادة المحاولة بنفس معرّف محاولة الدفع، لا
/// بإنشاء طلب محلي غير آمن.
class OrderService {
  OrderService._internal();
  static final OrderService instance = OrderService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  /// عميل الخادم الموثوق — قابل للاستبدال في الاختبارات
  OrderApi orderApi = OrderApi();

  /// إنشاء الطلب عبر الخادم الموثوق.
  ///
  /// [checkoutId] معرّف محاولة الدفع: يُولَّد مرة واحدة لكل محاولة ويُعاد
  /// إرساله كما هو في أي إعادة محاولة (بعد عطل شبكة أو خطأ خادم)، فيمنع
  /// الخادم إنشاء طلب مكرر أو خصم المخزون مرتين. لا تُولّد معرّفاً جديداً
  /// عند إعادة المحاولة لنفس عملية الدفع.
  ///
  /// ترمي [OrderException] في كل الحالات — سواء رفض نهائي من الخادم
  /// (مخزون غير كافٍ، كوبون منتهٍ) أو عطل تقني (شبكة/خادم) — بحيث تُعرض
  /// رسالة واضحة للعميل ويقرر هو إعادة المحاولة، لا التطبيق صامتاً.
  Future<Order> submitOrder({
    required String checkoutId,
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    String? couponCode,
    String? shippingAddress,
    String notes = '',
    int pointsToRedeem = 0,
  }) async {
    try {
      return await orderApi.createOrder(
        checkoutId: checkoutId,
        items: items,
        paymentMethod: paymentMethod,
        couponCode: couponCode,
        shippingAddress: shippingAddress,
        notes: notes,
        pointsToRedeem: pointsToRedeem,
      );
    } on OrderApiException catch (e) {
      throw OrderException(e.message);
    } on OrderApiUnavailable catch (_) {
      throw OrderException(
        'تعذر الاتصال بالخادم، تحقق من الإنترنت وحاول مرة أخرى',
      );
    }
  }

  /// بث طلبات مستخدم معين (محدث تلقائياً).
  ///
  /// حدّ أعلى مقصود (المرحلة 13 — M6): سخي بما يكفي لتاريخ مشتريات أي
  /// عميل فعلي، ويمنع نمو التكلفة بلا سقف لعميل نادر بحجم طلبات ضخم جداً.
  Stream<List<Order>> watchOrders(String userId, {int limit = 100}) {
    return _orders
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Order.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// بث أحدث الطلبات (للوحة الإدارة).
  ///
  /// بحدّ أعلى مقصود: بثّ المجموعة كاملة يعني تحميل كل طلبات المتجر
  /// والاستماع لتغيّراتها باستمرار — تكلفة قراءات وذاكرة تنمو بلا سقف مع
  /// نمو المتجر. الإدارة تحتاج الأحدث عملياً.
  Stream<List<Order>> watchAllOrders({int limit = 300}) {
    return _orders
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Order.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// تحديث حالة الطلب (ورقم التتبع وشركة الشحن) — للوحة الإدارة
  Future<void> updateOrder(
    String orderId, {
    OrderStatus? status,
    String? trackingNumber,
    String? carrier,
  }) async {
    final data = <String, dynamic>{};
    if (status != null) data['status'] = status.name;
    if (trackingNumber != null) {
      data['trackingNumber'] = trackingNumber.trim().toUpperCase();
    }
    if (carrier != null) data['carrier'] = carrier;
    data['updatedAt'] = DateTime.now().toIso8601String();
    await _orders.doc(orderId).update(data);
  }

  /// بث طلب واحد (محدَّث لحظياً) — يُستخدم بشاشة تفاصيل الطلب عند العميل
  /// حتى تظهر تغييرات الإدارة على الحالة فوراً بلا إعادة فتح الشاشة
  Stream<Order?> watchOrder(String orderId) {
    return _orders.doc(orderId).snapshots().map(
          (doc) => doc.exists ? Order.fromMap(doc.data()!, doc.id) : null,
        );
  }

  /// جلب طلب محدد بالمعرف
  Future<Order?> getOrder(String orderId) async {
    try {
      final doc = await _orders.doc(orderId).get();
      if (!doc.exists) return null;
      return Order.fromMap(doc.data()!, doc.id);
    } catch (_) {
      return null;
    }
  }

  /// البحث عن طلب برقم التتبع (متاح للضيوف أيضاً)
  Future<Order?> getOrderByTrackingNumber(String trackingNumber) async {
    final normalized = trackingNumber.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    try {
      final query = await _orders
          .where('trackingNumber', isEqualTo: normalized)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return Order.fromMap(query.docs.first.data(), query.docs.first.id);
    } catch (_) {
      return null;
    }
  }
}
