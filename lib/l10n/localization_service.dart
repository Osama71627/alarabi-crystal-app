import 'dart:ui';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';
import 'app_strings.dart';
import 'app_strings_en.dart';
import 'app_languages.dart';

/// خدمة إدارة اللغة في التطبيق
class LocalizationService {
  LocalizationService._();

  static final LocalizationService instance = LocalizationService._();

  /// اللغة الحالية (عربية افتراضياً)
  String _currentLanguage = 'ar';
  String get currentLanguage => _currentLanguage;

  /// الحصول على Locale الحالي
  Locale get currentLocale => AppLanguages.localeFromCode(_currentLanguage);

  /// هل اللغة الحالية هي العربية؟
  bool get isArabic => _currentLanguage == 'ar';

  /// هل اتجاه التطبيق RTL؟
  bool get isRtl => isArabic;

  /// النصوص حسب اللغة الحالية
  dynamic get strings => isArabic ? AppStrings : AppStringsEn;

  /// تحميل اللغة المحفوظة
  Future<void> loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(AppConstants.prefsKeyLanguage);
    if (saved != null && AppLanguages.supportedLocales.contains(saved)) {
      _currentLanguage = saved;
    }
  }

  /// تغيير اللغة وحفظها
  Future<void> changeLanguage(String code) async {
    if (!AppLanguages.supportedLocales.contains(code)) return;
    _currentLanguage = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefsKeyLanguage, code);
  }

  /// هل رأى المستخدم شاشة التعريف؟
  bool _onboardingSeen = false;
  bool get hasSeenOnboarding => _onboardingSeen;

  /// تحميل حالة شاشة التعريف
  Future<void> loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingSeen = prefs.getBool(AppConstants.prefsKeyOnboarding) ?? false;
  }

  /// تعليم أن المستخدم شاهد شاشة التعريف
  Future<void> setOnboardingSeen() async {
    _onboardingSeen = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.prefsKeyOnboarding, true);
  }
}
