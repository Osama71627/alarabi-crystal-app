import 'package:alarabi_crystal/shared/models/cart_item.dart';
import 'package:alarabi_crystal/shared/models/order.dart';
import 'package:alarabi_crystal/shared/services/order_api.dart';
import 'package:alarabi_crystal/shared/services/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// عميل خادم وهمي: يحدّد كل اختبار سلوكه (نجاح / رفض نهائي / عطل مؤقت)
class _FakeOrderApi extends OrderApi {
  _FakeOrderApi({this.result, this.error});

  final Order? result;
  final Object? error;
  int calls = 0;

  @override
  Future<Order> createOrder({
    required String checkoutId,
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    String? couponCode,
    String? shippingAddress,
    String notes = '',
    int pointsToRedeem = 0,
  }) async {
    calls += 1;
    final failure = error;
    if (failure != null) throw failure;
    return result!;
  }
}

final _items = [
  const CartItem(
    productId: 'p1',
    name: 'كأس',
    price: 100,
    image: '',
    quantity: 1,
    stock: 5,
  ),
];

Future<Order> submit() => OrderService.instance.submitOrder(
      checkoutId: 'checkout-abc-0001',
      items: _items,
      paymentMethod: PaymentMethod.cod,
    );

void main() {
  final service = OrderService.instance;
  final serverOrder = Order(
    id: 'srv-1',
    userId: 'uid-1',
    items: _items,
    total: 125,
  );

  tearDown(() {
    // إعادة العميل الحقيقي حتى لا يتسرّب الوهمي لاختبارات أخرى
    service.orderApi = OrderApi();
  });

  test('النجاح يأتي من الخادم مباشرة — لا يوجد أي مسار محلي بديل', () async {
    final api = _FakeOrderApi(result: serverOrder);
    service.orderApi = api;

    final order = await submit();

    expect(order.id, 'srv-1');
    expect(order.total, 125);
    expect(api.calls, 1);
  });

  test('رفض الخادم النهائي (400) يُعرض للعميل كما هو، بلا أي مسار بديل', () async {
    service.orderApi = _FakeOrderApi(
      error: OrderApiException(
        message: 'الكمية المتوفرة من "كأس" غير كافية حالياً',
        code: 'insufficient_stock',
        statusCode: 400,
      ),
    );

    await expectLater(
      submit(),
      throwsA(isA<OrderException>().having(
        (e) => e.message,
        'message',
        contains('غير كافية'),
      )),
    );
  });

  test('خطأ هوية 401 يُعرض كما هو، بلا أي مسار بديل', () async {
    service.orderApi = _FakeOrderApi(
      error: OrderApiException(
        message: 'انتهت صلاحية الجلسة، سجّل الدخول من جديد',
        code: 'unauthorized',
        statusCode: 401,
      ),
    );

    await expectLater(
      submit(),
      throwsA(isA<OrderException>().having(
        (e) => e.message,
        'message',
        contains('انتهت صلاحية'),
      )),
    );
  });

  test('409 (تعارض/ازدحام) يُعرض كخطأ نهائي، بلا أي مسار بديل', () async {
    service.orderApi = _FakeOrderApi(
      error: OrderApiException(
        message: 'ازدحام مؤقت، حاول مرة أخرى',
        code: 'conflict',
        statusCode: 409,
      ),
    );

    await expectLater(submit(), throwsA(isA<OrderException>()));
  });

  test('عطل تقني مؤقت (شبكة/5xx) يُعرض كرسالة واضحة تسمح بإعادة المحاولة، ولا يُنشئ أي طلب محلي', () async {
    final api = _FakeOrderApi(error: OrderApiUnavailable('connectionError'));
    service.orderApi = api;

    await expectLater(
      submit(),
      throwsA(isA<OrderException>().having(
        (e) => e.message,
        'message',
        contains('تعذر الاتصال بالخادم'),
      )),
    );
    // نداء واحد فقط — لا محاولة تلقائية إضافية ولا مسار محلي يُنفَّذ خلفياً
    expect(api.calls, 1);
  });

  test('إعادة المحاولة اليدوية بنفس checkoutId بعد عطل مؤقت تنادي الخادم مرة أخرى بنفس المعرّف', () async {
    final failing = _FakeOrderApi(error: OrderApiUnavailable('timeout'));
    service.orderApi = failing;
    await expectLater(submit(), throwsA(isA<OrderException>()));

    // المستخدم يضغط "إعادة المحاولة" — الشاشة تعيد استخدام نفس checkoutId
    // (حقل final)، والخادم هذه المرة ينجح
    final succeeding = _FakeOrderApi(result: serverOrder);
    service.orderApi = succeeding;
    final order = await submit();

    expect(order.id, 'srv-1');
    expect(succeeding.calls, 1);
  });
}
