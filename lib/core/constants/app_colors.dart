import 'package:flutter/material.dart';

/// ألوان تطبيق العربية للكريستال - نظام التصميم الفاخر
class AppColors {
  AppColors._();

  // الألوان الأساسية
  static const Color primary = Color(0xFF1A237E); // أزرق داكن - الفخامة
  static const Color primaryDark = Color(0xFF0D1440); // أزرق أغمق للتدرجات
  // ذهبي مطابق تماماً لموقع الشركة arabiacrystal.com (مُستخرج من الكود
  // الفعلي للموقع، لا تخميناً) — لون أزرار "أضف إلى السلة" و"تسوق الآن"
  static const Color secondary = Color(0xFFB69123);
  static const Color secondaryLight = Color(0xFFF4E4BB); // كريمي ذهبي فاتح (خلفيات)
  // زيتوني ذهبي غامق مطابق لشارة "تخفيض" في الموقع
  static const Color secondaryDark = Color(0xFF958E09);
  static const Color accent = Color(0xFFE8EAF6); // أزرق فاتح

  // الألوان المحايدة
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color surfaceDark = Color(0xFF121212);

  // حالة الألوان
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // الألوان النصية
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFF9E9E9E);
  static const Color textOnPrimary = Colors.white;

  // ألوان الوضع الليلي
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceLight = Color(0xFF1F2937);
  static const Color darkTextPrimary = Color(0xFFE1E1E1);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
}
