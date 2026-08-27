import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../l10n/localization_service.dart';

/// شاشة التعريف بالتطبيق (3 صفحات)
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final LocalizationService _localizationService = LocalizationService.instance;

  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// إكمال التمرين وحفظ العلم والانتقال للرئيسية
  Future<void> _finish() async {
    await _localizationService.setOnboardingSeen();
    if (!mounted) return;
    context.go(AppRoutes.home);
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _localizationService.isArabic;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // زر التخطي
            Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextButton(
                  onPressed: _finish,
                  child: Text(
                    _currentPage == 2 ? AppStrings.getStarted : AppStrings.skip,
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            // الصفحات
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: 3,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(
                    index: index,
                    icon: _pageIcon(index),
                    title: _pageTitle(index),
                    description: _pageDescription(index),
                  );
                },
              ),
            ),
            // مؤشر التقدم وزر التالي
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // مؤشر التقدم
                  _PageIndicator(
                    count: 3,
                    current: _currentPage,
                    isArabic: isArabic,
                  ),
                  const Spacer(),
                  // زر التالي / البدء
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed:
                          _currentPage == 2 ? _finish : _nextPage,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == 2
                            ? AppStrings.getStarted
                            : AppStrings.next,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _pageIcon(int index) {
    switch (index) {
      case 0:
        return Icons.diamond_rounded;
      case 1:
        return Icons.local_offer_rounded;
      default:
        return Icons.local_shipping_rounded;
    }
  }

  String _pageTitle(int index) {
    switch (index) {
      case 0:
        return AppStrings.onboarding1Title;
      case 1:
        return AppStrings.onboarding2Title;
      default:
        return AppStrings.onboarding3Title;
    }
  }

  String _pageDescription(int index) {
    switch (index) {
      case 0:
        return AppStrings.onboarding1Desc;
      case 1:
        return AppStrings.onboarding2Desc;
      default:
        return AppStrings.onboarding3Desc;
    }
  }
}

/// صفحة واحدة من صفحات التعريف
class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.index,
    required this.icon,
    required this.title,
    required this.description,
  });

  final int index;
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : index == 0
            ? AppColors.secondary
            : index == 1
                ? AppColors.secondaryDark
                : AppColors.primaryDark;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // الأيقونة داخل إطار فاخر
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(40),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.35),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.diamond_outlined,
                  size: 180,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                Icon(
                  icon,
                  size: 90,
                  color: AppColors.secondary,
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// مؤشر تقدم الصفحات
class _PageIndicator extends StatelessWidget {
  const _PageIndicator({
    required this.count,
    required this.current,
    required this.isArabic,
  });

  final int count;
  final int current;
  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final isActive = index == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: EdgeInsetsDirectional.only(
            end: isArabic ? 6 : 0,
            start: isArabic ? 0 : 6,
          ),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.secondary : AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
