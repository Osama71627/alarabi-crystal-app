import 'dart:convert';
import 'dart:typed_data';

import 'package:alarabi_crystal/shared/models/cart_item.dart';
import 'package:alarabi_crystal/shared/models/order.dart';
import 'package:alarabi_crystal/shared/services/order_api.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

/// محوّل شبكة وهمي: يسجّل ما أُرسل فعلاً ويعيد رداً محدَّداً — يسمح باختبار
/// طبقة الشبكة الحقيقية (بما فيها تصنيف أخطاء Dio) دون أي اتصال
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.statusCode = 200, this.body = const {}});

  int statusCode;
  Map<String, dynamic> body;

  /// يُضبط في الاختبارات التي تحاكي عطلاً في الشبكة قبل وصول أي رد
  DioException? throwError;

  RequestOptions? lastRequest;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    lastBody = options.data is Map
        ? Map<String, dynamic>.from(options.data as Map)
        : null;

    final error = throwError;
    if (error != null) throw error;

    return ResponseBody.fromString(
      jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

OrderApi _buildApi(_FakeAdapter adapter, {String? token = 'valid-id-token'}) {
  final dio = Dio()..httpClientAdapter = adapter;
  return OrderApi(dio: dio, tokenProvider: () async => token);
}

final _items = [
  const CartItem(
    productId: 'p1',
    name: 'كأس كريستال',
    price: 1000,
    image: 'https://img/p1.jpg',
    quantity: 2,
    stock: 10,
    discountPrice: 800,
    categoryId: 'c1',
  ),
];

Future<Order> call(OrderApi api) => api.createOrder(
      checkoutId: 'checkout-abc-0001',
      items: _items,
      paymentMethod: PaymentMethod.cod,
    );

void main() {
  final successBody = {
    'ok': true,
    'orderId': 'srv-order-1',
    'order': {
      'userId': 'real-uid',
      'items': [
        {
          'productId': 'p1',
          'name': 'كأس كريستال',
          'price': 1000,
          'image': 'https://img/p1.jpg',
          'quantity': 2,
          'stock': 10,
          'discountPrice': 800,
          'categoryId': 'c1',
        },
      ],
      'total': 1600,
      'status': 'pending',
      'paymentMethod': 'cod',
      'shippingFee': 0,
      'discountAmount': 0,
    },
  };

  group('إرسال رمز الهوية', () {
    test('يُرسل رمز هوية Firebase في ترويسة Authorization', () async {
      final adapter = _FakeAdapter(body: successBody);
      await call(_buildApi(adapter));

      expect(
        adapter.lastRequest!.headers['Authorization'],
        'Bearer valid-id-token',
      );
    });

    test('بلا رمز هوية لا يُرسل طلب إطلاقاً', () async {
      final adapter = _FakeAdapter(body: successBody);
      final api = _buildApi(adapter, token: null);

      await expectLater(
        call(api),
        throwsA(isA<OrderApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
      expect(adapter.lastRequest, isNull);
    });
  });

  group('ما يُرسَل إلى الخادم', () {
    test('لا يُرسل السعر ولا سعر الخصم — المعرّف والكمية فقط', () async {
      final adapter = _FakeAdapter(body: successBody);
      await call(_buildApi(adapter));

      final sentItems = (adapter.lastBody!['items'] as List)
          .cast<Map<String, dynamic>>();
      expect(sentItems.single.keys.toSet(), {'productId', 'quantity'});
      expect(sentItems.single['productId'], 'p1');
      expect(sentItems.single['quantity'], 2);
    });

    test('لا يُرسل الإجمالي ولا الخصم ولا الشحن ولا المخزون', () async {
      final adapter = _FakeAdapter(body: successBody);
      await call(_buildApi(adapter));

      final keys = adapter.lastBody!.keys.toSet();
      for (final forbidden in [
        'total',
        'subtotal',
        'discount',
        'discountAmount',
        'shippingFee',
        'stock',
        'soldCount',
        'usedCount',
        'userId',
        'status',
      ]) {
        expect(keys.contains(forbidden), isFalse,
            reason: 'يجب ألا يُرسل $forbidden');
      }
    });

    test('يُرسل معرّف محاولة الدفع كما هو', () async {
      final adapter = _FakeAdapter(body: successBody);
      await call(_buildApi(adapter));
      expect(adapter.lastBody!['checkoutId'], 'checkout-abc-0001');
    });

    test('الإجمالي المُعاد يأتي من الخادم لا من حساب محلي', () async {
      final adapter = _FakeAdapter(body: successBody);
      final order = await call(_buildApi(adapter));

      // محلياً 2×800 = 1600، والخادم قال 1600 — نتحقق أن القيمة مصدرها الرد
      expect(order.total, 1600);
      expect(order.id, 'srv-order-1');
      expect(order.userId, 'real-uid');
      expect(order.status, OrderStatus.pending);
    });
  });

  group('معالجة الأخطاء', () {
    test('401 خطأ نهائي (لا مسار بديل)', () async {
      final adapter = _FakeAdapter(
        statusCode: 401,
        body: {'error': 'unauthorized', 'reason': 'token_expired'},
      );
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('400 برسالة الخادم تُعرض كما هي', () async {
      final adapter = _FakeAdapter(
        statusCode: 400,
        body: {
          'error': 'insufficient_stock',
          'message': 'الكمية المتوفرة من "كأس كريستال" غير كافية حالياً',
        },
      );
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiException>()
            .having((e) => e.code, 'code', 'insufficient_stock')
            .having((e) => e.message, 'message', contains('غير كافية'))),
      );
    });

    test('كل أخطاء التحقق تبقى نهائية ولا تتحول لعطل مؤقت', () async {
      for (final code in [
        'insufficient_stock',
        'coupon_expired',
        'coupon_not_found',
        'coupon_exhausted',
        'coupon_per_user',
        'coupon_audience',
        'product_missing',
        'bad_quantity',
        'bad_product',
        'empty_cart',
        'checkout_id_required',
      ]) {
        final adapter = _FakeAdapter(
          statusCode: 400,
          body: {'error': code, 'message': 'مرفوض'},
        );
        await expectLater(
          call(_buildApi(adapter)),
          throwsA(isA<OrderApiException>().having((e) => e.code, 'code', code)),
          reason: 'الكود $code يجب أن يكون نهائياً',
        );
      }
    });

    test('409 تعارض خطأ نهائي برسالة واضحة', () async {
      final adapter = _FakeAdapter(
        statusCode: 409,
        body: {'error': 'conflict', 'message': 'ازدحام مؤقت، حاول مرة أخرى'},
      );
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiException>()
            .having((e) => e.statusCode, 'statusCode', 409)),
      );
    });

    test('500 عطل تقني مؤقت (يسمح بالمسار البديل)', () async {
      final adapter = _FakeAdapter(statusCode: 500, body: {'error': 'x'});
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiUnavailable>()),
      );
    });

    test('503 عطل تقني مؤقت', () async {
      final adapter = _FakeAdapter(statusCode: 503, body: {});
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiUnavailable>()),
      );
    });

    test('انقطاع الاتصال عطل تقني مؤقت', () async {
      final adapter = _FakeAdapter()
        ..throwError = DioException.connectionError(
          requestOptions: RequestOptions(),
          reason: 'no internet',
        );
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiUnavailable>()),
      );
    });

    test('انتهاء المهلة عطل تقني مؤقت', () async {
      final adapter = _FakeAdapter()
        ..throwError = DioException.receiveTimeout(
          timeout: const Duration(seconds: 30),
          requestOptions: RequestOptions(),
        );
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiUnavailable>()),
      );
    });

    test('رد 200 بشكل غير متوقع يُعامَل كعطل لا كنجاح', () async {
      final adapter = _FakeAdapter(body: {'ok': true});
      await expectLater(
        call(_buildApi(adapter)),
        throwsA(isA<OrderApiUnavailable>()),
      );
    });
  });

  group('منع تكرار الطلب', () {
    test('معرّف المحاولة عشوائي وطويل بما يكفي', () {
      final a = OrderApi.newCheckoutId();
      final b = OrderApi.newCheckoutId();
      expect(a.length, 24);
      expect(a, isNot(b));
      expect(RegExp(r'^[A-Za-z0-9]+$').hasMatch(a), isTrue);
    });

    test('إعادة المحاولة بنفس المعرّف تُعيد نفس الطلب دون إنشاء ثانٍ', () async {
      // الخادم يرد duplicate:true بنفس معرّف الطلب — العميل يتعامل معه كنجاح
      final adapter = _FakeAdapter(body: {
        ...successBody,
        'duplicate': true,
      });
      final api = _buildApi(adapter);

      final first = await call(api);
      final second = await call(api);

      expect(first.id, second.id);
      expect(adapter.lastBody!['checkoutId'], 'checkout-abc-0001');
    });
  });
}
