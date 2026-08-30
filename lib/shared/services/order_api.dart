import 'dart:math';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/backend_config.dart';
import '../models/cart_item.dart';
import '../models/order.dart';

/// مزوّد رمز هوية Firebase — قابل للاستبدال في الاختبارات
typedef IdTokenProvider = Future<String?> Function();

/// خطأ منطقي نهائي من الخادم (4xx): كمية غير متوفرة، كوبون منتهٍ، هوية
/// غير صالحة… يُعرض للعميل كما هو **ولا يُتجاوَز أبداً** بمسار بديل، لأن
/// تجاوزه يعني تنفيذ ما رفضه الخادم عن قصد.
class OrderApiException implements Exception {
  OrderApiException({
    required this.message,
    required this.code,
    required this.statusCode,
  });

  final String message;
  final String code;
  final int statusCode;

  @override
  String toString() => message;
}

/// عطل تقني مؤقت (انقطاع شبكة، مهلة، 5xx): لا يعني أن الطلب مرفوض، بل أن
/// الخادم لم يُجب. هذا هو النوع الوحيد الذي يجوز معه المسار البديل.
class OrderApiUnavailable implements Exception {
  OrderApiUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'الخادم غير متاح مؤقتاً ($reason)';
}

/// عميل خدمة الطلبات على الخادم الموثوق.
///
/// ما يُرسَل: معرّفات المنتجات وكمياتها، رمز الكوبون، العنوان (نصاً
/// وإحداثيات اختيارية من الخريطة)، الملاحظات، عدد النقاط المطلوب
/// استخدامه، ومعرّف محاولة الدفع.
/// ما لا يُرسَل إطلاقاً: السعر، الإجمالي، الخصم، المخزون، usedCount،
/// userId، حالة الطلب — كلها يقرّرها الخادم من قاعدة البيانات.
class OrderApi {
  OrderApi({Dio? dio, IdTokenProvider? tokenProvider})
      : _dio = dio ?? Dio(),
        _tokenProvider = tokenProvider ?? _firebaseIdToken;

  final Dio _dio;
  final IdTokenProvider _tokenProvider;

  static Future<String?> _firebaseIdToken() async {
    // getIdToken() يجدّد الرمز تلقائياً إن قارب الانتهاء
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  /// معرّف محاولة دفع عشوائي — يُولَّد مرة واحدة لكل محاولة ويُعاد استخدامه
  /// في كل إعادة إرسال، فيمنع الخادم إنشاء طلب مكرر (راجع deriveOrderId)
  static String newCheckoutId() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(24, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// إنشاء طلب على الخادم. ترمي [OrderApiException] لرفض نهائي، أو
  /// [OrderApiUnavailable] لعطل تقني مؤقت.
  Future<Order> createOrder({
    required String checkoutId,
    required List<CartItem> items,
    required PaymentMethod paymentMethod,
    String? couponCode,
    String? shippingAddress,
    double? shippingLat,
    double? shippingLng,
    String notes = '',
    int pointsToRedeem = 0,
  }) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw OrderApiException(
        message: 'يجب تسجيل الدخول لإتمام الطلب',
        code: 'no_id_token',
        statusCode: 401,
      );
    }

    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        BackendConfig.orderUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          // نتولّى تفسير رموز الحالة بأنفسنا لنفرّق بين رفض ومشكلة تقنية
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'checkoutId': checkoutId,
          // المعرّف والكمية فقط — لا سعر ولا إجمالي
          'items': items
              .map((item) => {
                    'productId': item.productId,
                    'quantity': item.quantity,
                  })
              .toList(),
          if (couponCode != null && couponCode.isNotEmpty)
            'couponCode': couponCode,
          'paymentMethod': paymentMethod.name,
          if (shippingAddress != null && shippingAddress.isNotEmpty)
            'shippingAddress': shippingAddress,
          if (shippingLat != null) 'latitude': shippingLat,
          if (shippingLng != null) 'longitude': shippingLng,
          if (notes.isNotEmpty) 'notes': notes,
          if (pointsToRedeem > 0) 'pointsToRedeem': pointsToRedeem,
        },
      );
    } on DioException catch (error) {
      throw OrderApiUnavailable(error.type.name);
    } catch (error) {
      throw OrderApiUnavailable('unknown');
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    final body = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    if (status >= 200 && status < 300) {
      final orderId = body['orderId'] as String?;
      final orderMap = body['order'];
      if (orderId == null || orderMap is! Map) {
        // رد 200 بشكل غير متوقع: نعتبره عطلاً تقنياً لا رفضاً
        throw OrderApiUnavailable('bad_response');
      }
      return Order.fromMap(Map<String, dynamic>.from(orderMap), orderId);
    }

    // 5xx: الخادم موجود لكنه فشل — عطل تقني يجوز معه المسار البديل
    if (status >= 500) {
      throw OrderApiUnavailable('http_$status');
    }

    // 4xx: قرار نهائي من الخادم — يُعرض للعميل ولا يُتجاوَز
    throw OrderApiException(
      message: (body['message'] as String?) ?? _fallbackMessage(status),
      code: (body['error'] as String?) ?? 'rejected',
      statusCode: status,
    );
  }

  String _fallbackMessage(int status) {
    if (status == 401 || status == 403) {
      return 'انتهت صلاحية الجلسة، سجّل الدخول من جديد';
    }
    if (status == 409) return 'ازدحام مؤقت، حاول مرة أخرى';
    return 'تعذر إتمام الطلب، تحقق من سلتك وحاول مرة أخرى';
  }
}
