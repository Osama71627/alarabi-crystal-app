import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/constants/push_config.dart';

/// مزوّد رمز هوية Firebase — قابل للاستبدال في الاختبارات
typedef IdTokenProvider = Future<String?> Function();

/// يطلب من الخادم الخارجي (push-server/ على Vercel) إرسال إشعار Push فعلي
/// يصل حتى لو كان تطبيق العميل مغلقاً تماماً — راجع push-server/README.md
/// لتفاصيل سبب وجود خادم منفصل هنا بدل الاعتماد على Cloud Functions.
///
/// ⚠️ المرحلة 13: لم يعد الاستدعاء محمياً بسرّ ثابت (كان قابلاً للاستخراج
/// من ملف APK الموزَّع نفسه — راجع تقرير المرحلة 12، الثغرة C1). الخادم
/// الآن يتحقق من توقيع Firebase على رمز الهوية بنفس آلية `/api/order` و
/// `/api/review`، ويقرّر الصلاحية من دور المستخدم المخزَّن في Firestore
/// (`users/{uid}.role`) لا من أي قيمة يرسلها هذا الملف — فلا يوجد أي سرّ
/// جديد يمكن استخراجه من التطبيق بعد الآن.
///
/// فشل هذا الاستدعاء (أو عدم ضبط [PushConfig.baseUrl] بعد) لا يجب أبداً
/// أن يوقف الإجراء الأساسي (مثل نشر منتج) — الإشعار داخل التطبيق
/// (InAppNotificationService) يبقى يعمل بشكل مستقل تماماً بلا حاجة لهذا.
class PushTriggerService {
  PushTriggerService._internal()
      : _tokenProvider = _firebaseIdToken,
        _dio = Dio();

  /// مُنشئ للاختبارات فقط — يسمح باستبدال مزوّد التوكن وعميل الشبكة الحقيقيَّين
  PushTriggerService.forTesting({
    required IdTokenProvider tokenProvider,
    Dio? dio,
  })  : _tokenProvider = tokenProvider,
        _dio = dio ?? Dio();

  static final PushTriggerService instance = PushTriggerService._internal();

  final Dio _dio;
  final IdTokenProvider _tokenProvider;

  static Future<String?> _firebaseIdToken() async {
    return FirebaseAuth.instance.currentUser?.getIdToken();
  }

  /// [userId] فارغاً: بثّ عام لكل المشتركين (منتج/عرض جديد) — يتطلب صلاحية
  /// مدير على الخادم. [userId] محدداً بمعرّف المتصل نفسه: إشعار ذاتي، مسموح
  /// لأي مستخدم مسجَّل. [userId] محدداً بمعرّف مستخدم آخر: يتطلب صلاحية
  /// مدير — الخادم يتحقق من الدور من Firestore، لا من أي شيء يُرسَل هنا.
  Future<void> notify({
    required String title,
    required String body,
    String type = 'general',
    String? linkId,
    String? userId,
  }) async {
    if (!PushConfig.isConfigured) return;
    try {
      final token = await _tokenProvider();
      if (token == null || token.isEmpty) return;
      await _dio.post<void>(
        PushConfig.baseUrl,
        options: Options(headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        }),
        data: {
          'title': title,
          'body': body,
          'type': type,
          if (linkId != null) 'linkId': linkId,
          if (userId != null) 'userId': userId,
        },
      );
    } catch (_) {
      // بصمت — فشل إرسال الدفع لا يمنع الإجراء الأساسي
    }
  }
}
