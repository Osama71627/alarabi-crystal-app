import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../l10n/localization_service.dart';

/// شاشة البداية مع أنيميشن الشعار المتلألئ
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scale;
  late final Animation<double> _sparkle;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );
    _sparkle = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  void _navigateAfterDelay() {
    final hasSeenOnboarding = LocalizationService.instance.hasSeenOnboarding;
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      context.go(hasSeenOnboarding ? AppRoutes.home : AppRoutes.onboarding);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // خلفية متلألئة
          Positioned.fill(
            child: CustomPaint(painter: _SparklePainter(animation: _sparkle)),
          ),
          // الشعار والنص
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // شعار الشركة
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.25),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      AppStrings.appName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: isDark ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppStrings.appTagline,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 40),
                    Text(
                      AppConstants.appVersion,
                      style: TextStyle(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// لوحة رسم الجزيئات المتلألئة (سباركلز) خلف الشعار
class _SparklePainter extends CustomPainter {
  const _SparklePainter({required this.animation});

  final Animation<double> animation;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.secondary.withValues(
        alpha: 0.5 * animation.value,
      );

    final sparkles = [
      (x: 0.15, y: 0.25, r: 3.0),
      (x: 0.85, y: 0.2, r: 2.0),
      (x: 0.75, y: 0.85, r: 3.5),
      (x: 0.2, y: 0.8, r: 2.5),
      (x: 0.5, y: 0.1, r: 2.0),
      (x: 0.9, y: 0.55, r: 2.5),
      (x: 0.08, y: 0.5, r: 2.0),
      (x: 0.65, y: 0.12, r: 1.5),
    ];

    for (final s in sparkles) {
      final cx = size.width * s.x;
      final cy = size.height * s.y;
      final r = s.r * animation.value;

      // نجم رباعي الأطراف
      final path = Path();
      path.moveTo(cx, cy - r * 2);
      path.quadraticBezierTo(cx, cy, cx + r * 2, cy);
      path.quadraticBezierTo(cx, cy, cx, cy + r * 2);
      path.quadraticBezierTo(cx, cy, cx - r * 2, cy);
      path.quadraticBezierTo(cx, cy, cx, cy - r * 2);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklePainter oldDelegate) {
    return oldDelegate.animation.value != animation.value;
  }
}
