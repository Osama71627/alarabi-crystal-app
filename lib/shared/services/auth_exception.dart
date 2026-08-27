/// استثناء مصادقة برسالة عربية
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
