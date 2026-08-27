import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/backend_config.dart';

/// مزوّد رمز هوية Firebase — قابل للاستبدال في الاختبارات
typedef IdTokenProvider = Future<String?> Function();

/// خطأ رفض نهائي من الخادم (تحقق مرفوض: تقييم خارج المدى، منتج غير معروف)
class ReviewApiException implements Exception {
  ReviewApiException({required this.message, required this.code});

  final String message;
  final String code;

  @override
  String toString() => message;
}

/// عطل تقني مؤقت (شبكة/خادم) — لا يعني رفض المراجعة، بل تعذّر الوصول للخادم
class ReviewApiUnavailable implements Exception {
  ReviewApiUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'الخادم غير متاح مؤقتاً ($reason)';
}

/// عميل خدمة المراجعات على الخادم الموثوق (push-server/api/review.js).
///
/// يرسل فقط ما يقرره العميل: المنتج، التقييم، التعليق، الصور. لا يُرسل
/// `userId` (يُشتق من رمز الهوية) ولا `rating`/`reviewCount` الخاصين
/// بالمنتج (يحسبهما الخادم من كل المراجعات الفعلية).
class ReviewApi {
  ReviewApi({Dio? dio, IdTokenProvider? tokenProvider})
      : _dio = dio ?? Dio(),
        _tokenProvider = tokenProvider ?? _firebaseIdToken;

  final Dio _dio;
  final IdTokenProvider _tokenProvider;

  static Future<String?> _firebaseIdToken() async {
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  Future<Map<String, dynamic>> _call(Map<String, dynamic> body) async {
    final token = await _tokenProvider();
    if (token == null || token.isEmpty) {
      throw ReviewApiException(message: 'يجب تسجيل الدخول', code: 'no_id_token');
    }

    Response<dynamic> response;
    try {
      response = await _dio.post<dynamic>(
        BackendConfig.reviewUrl,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          validateStatus: (_) => true,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: body,
      );
    } on DioException catch (error) {
      throw ReviewApiUnavailable(error.type.name);
    } catch (_) {
      throw ReviewApiUnavailable('unknown');
    }

    final status = response.statusCode ?? 0;
    final data = response.data;
    final result = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

    if (status >= 200 && status < 300) return result;
    if (status >= 500) throw ReviewApiUnavailable('http_$status');

    throw ReviewApiException(
      message: (result['message'] as String?) ?? 'تعذر حفظ التقييم، حاول مرة أخرى',
      code: (result['error'] as String?) ?? 'rejected',
    );
  }

  /// إنشاء أو تعديل مراجعة العميل الحالي على [productId]
  Future<void> upsert({
    required String productId,
    required double rating,
    String comment = '',
    String userName = '',
    List<String> images = const [],
  }) {
    return _call({
      'productId': productId,
      'rating': rating,
      'comment': comment,
      'userName': userName,
      'images': images,
    });
  }

  /// حذف مراجعة العميل الحالي على [productId] (لا يقدر حذف مراجعة غيره)
  Future<void> delete(String productId) {
    return _call({'productId': productId, 'action': 'delete'});
  }
}
