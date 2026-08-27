import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';

/// شاشة الملف الشخصي
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _shareApp(BuildContext context) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'جرّب تطبيق ${AppConstants.appName} 💎\n'
              'تسوّق أفخم قطع الكريستال بسهولة — عروض حصرية وتوصيل سريع!',
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.shareFailed)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: AuthService.instance,
          builder: (context, _) {
            final user = AuthService.instance.currentUser;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const SizedBox(height: 8),
                // رأس الملف
                Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.secondary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name.isNotEmpty == true
                                ? user!.name
                                : AppStrings.guest,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user != null
                                ? (user.email.isNotEmpty
                                    ? user.email
                                    : AppStrings.welcome)
                                : AppStrings.welcome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user == null)
                      TextButton(
                        onPressed: () => context.push(AppRoutes.login),
                        child: Text(AppStrings.login),
                      ),
                  ],
                ),
                const SizedBox(height: 24),

                // لوحة تحكم المدير
                if (user?.isAdmin == true) ...[
                  _ProfileTile(
                    icon: Icons.dashboard_outlined,
                    title: AppStrings.adminDashboard,
                    onTap: () => context.push(AppRoutes.admin),
                  ),
                  const SizedBox(height: 8),
                ],

                // قائمة الخيارات
                _ProfileTile(
                  icon: Icons.receipt_long_outlined,
                  title: AppStrings.myOrders,
                  onTap: () => context.push(AppRoutes.orders),
                ),
                _ProfileTile(
                  icon: Icons.favorite_outline,
                  title: AppStrings.favorites,
                  onTap: () => context.push(AppRoutes.favorites),
                ),
                _ProfileTile(
                  icon: Icons.compare_arrows,
                  title: AppStrings.compare,
                  onTap: () => context.push(AppRoutes.compare),
                ),
                _ProfileTile(
                  icon: Icons.notifications_outlined,
                  title: AppStrings.notifications,
                  onTap: () => context.push(AppRoutes.notifications),
                ),
                if (user != null)
                  _ProfileTile(
                    icon: Icons.stars_rounded,
                    title: AppStrings.myPoints,
                    onTap: () => context.push(AppRoutes.points),
                  ),
                _ProfileTile(
                  icon: Icons.support_agent_outlined,
                  title: AppStrings.supportChat,
                  onTap: () => context.push(AppRoutes.supportChat),
                ),
                const SizedBox(height: 16),

                // الإعدادات
                Text(
                  AppStrings.accountSettings,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.language,
                  title: AppStrings.language,
                  subtitle: 'العربية',
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.dark_mode_outlined,
                  title: AppStrings.themeMode,
                  subtitle: AppStrings.systemMode,
                  onTap: () {},
                ),
                const SizedBox(height: 16),

                // الدعم
                Text(
                  AppStrings.helpSupport,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                _ProfileTile(
                  icon: Icons.headset_mic_outlined,
                  title: AppStrings.contactUs,
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.privacy_tip_outlined,
                  title: AppStrings.privacyPolicy,
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.description_outlined,
                  title: AppStrings.terms,
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.info_outline,
                  title: AppStrings.about,
                  onTap: () {},
                ),
                _ProfileTile(
                  icon: Icons.ios_share,
                  title: AppStrings.shareApp,
                  onTap: () => _shareApp(context),
                ),
                const SizedBox(height: 24),

                // تسجيل الخروج
                if (user != null)
                  OutlinedButton.icon(
                    onPressed: () => AuthService.instance.signOut(),
                    icon: const Icon(Icons.logout),
                    label: Text(AppStrings.logout),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.secondary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_left),
    );
  }
}
