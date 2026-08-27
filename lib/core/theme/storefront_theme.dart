import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';

/// يلفّ شاشات المتجر (تجربة العميل) بثيم محلي يستبدل اللون الأساسي
/// الأزرق بالذهبي (نفس لون شعار الشركة) — أبيض + ذهبي بدل أبيض + أزرق.
/// لوحة تحكم الإدارة لا تُلَف بهذا الثيم فتبقى بهويتها الزرقاء الحالية،
/// لأن كلتا الواجهتين تشتركان بنفس MaterialApp/ThemeData الأساسي.
class StorefrontTheme extends StatelessWidget {
  const StorefrontTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final isDark = base.brightness == Brightness.dark;
    const gold = AppColors.secondary;
    final onGold = isDark ? Colors.black : Colors.white;

    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: gold,
          onPrimary: onGold,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: gold,
            foregroundColor: onGold,
            minimumSize: const Size.fromHeight(AppConstants.buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: gold,
            minimumSize: const Size.fromHeight(AppConstants.buttonHeight),
            side: const BorderSide(color: gold, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppConstants.borderRadius),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
        ),
        progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
          color: gold,
        ),
        floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
          backgroundColor: gold,
          foregroundColor: onGold,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? gold : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? gold.withValues(alpha: 0.4) : null,
          ),
        ),
      ),
      child: child,
    );
  }
}
