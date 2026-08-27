import 'dart:ui';

/// إدارة اللغات المدعومة في التطبيق
class AppLanguages {
  AppLanguages._();

  /// قائمة اللغات المدعومة
  static const List<String> supportedLocales = ['ar', 'en'];

  /// اللغة الافتراضية
  static const Locale defaultLocale = Locale('ar');

  /// الحصول على Locale من رمز اللغة
  static Locale localeFromCode(String code) {
    switch (code) {
      case 'en':
        return const Locale('en');
      default:
        return const Locale('ar');
    }
  }
}
