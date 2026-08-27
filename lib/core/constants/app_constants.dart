/// ثوابت تطبيق العربية للكريستال
class AppConstants {
  AppConstants._();

  // معلومات التطبيق
  static const String appName = 'العربية للكريستال';
  static const String appNameEn = 'Al Arabi Crystal';
  static const String appVersion = '1.0.0';

  // الإعدادات العامة
  static const double borderRadius = 16;
  static const double borderRadiusSmall = 8;
  static const double defaultPadding = 16;
  static const double buttonHeight = 52;

  // الحقول
  static const String currencyCode = 'SAR';
  static const String currencySymbol = 'ر.س';

  // الحدود
  static const int maxCompareItems = 4;
  static const int maxProductImages = 8;

  // التخزين المحلي
  static const String prefsKeyTheme = 'theme_mode';
  static const String prefsKeyLanguage = 'language_code';
  static const String prefsKeyOnboarding = 'onboarding_seen';
  static const String prefsKeyUserId = 'user_id';
  static const String prefsKeyUserToken = 'user_token';

  // مفاتيح Hive
  static const String hiveBoxCart = 'cart_box';
  static const String hiveBoxFavorites = 'favorites_box';
  static const String hiveBoxSettings = 'settings_box';
  static const String hiveBoxCompare = 'compare_box';
}
