import 'package:cloud_functions/cloud_functions.dart';

/// خطأ تحقق برسالة عربية قابلة للعرض مباشرة
class EmailVerificationException implements Exception {
  EmailVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// خدمة التحقق من البريد الإلكتروني بكود مكوّن من 6 أرقام — يُرسَل الكود
/// وتُتحقَّق صحته عبر Cloud Functions (الكود نفسه لا يُخزَّن ولا يُقارَن
/// على العميل إطلاقاً)
class EmailVerificationService {
  EmailVerificationService._internal();
  static final EmailVerificationService instance =
      EmailVerificationService._internal();

  /// طلب إرسال كود جديد لبريد المستخدم الحالي
  /// يرجع true إن كان البريد موثَّقاً بالفعل (لا حاجة لكود)
  Future<bool> sendCode() async {
    try {
      final response = await FirebaseFunctions.instance
          .httpsCallable('sendEmailVerificationCode')
          .call();
      final data = Map<String, dynamic>.from(
        (response.data as Map?) ?? const <String, dynamic>{},
      );
      return data['alreadyVerified'] == true;
    } on FirebaseFunctionsException catch (e) {
      throw EmailVerificationException(e.message ?? 'تعذر إرسال كود التحقق');
    }
  }

  /// التحقق من الكود المُدخَل
  Future<void> verifyCode(String code) async {
    try {
      await FirebaseFunctions.instance
          .httpsCallable('verifyEmailCode')
          .call({'code': code});
    } on FirebaseFunctionsException catch (e) {
      throw EmailVerificationException(e.message ?? 'الكود غير صحيح');
    }
  }
}
