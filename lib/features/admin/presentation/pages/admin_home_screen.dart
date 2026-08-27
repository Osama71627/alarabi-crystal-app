import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import 'admin_chat_list_screen.dart';
import 'admin_coupons_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_offers_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_products_screen.dart';
import 'admin_refunds_screen.dart';
import 'admin_users_screen.dart';

/// شيل لوحة تحكم الإدارة
class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  static const _screens = [
    AdminDashboardScreen(),
    AdminProductsScreen(),
    AdminOrdersScreen(),
    AdminOffersScreen(),
    AdminCouponsScreen(),
    AdminUsersScreen(),
    AdminNotificationsScreen(),
    AdminChatListScreen(),
    AdminRefundsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final items = _navItems(context);
    final current = items[_index];
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(current.$1, color: AppColors.secondary, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.$2,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: AppStrings.backToStore,
            icon: const Icon(Icons.storefront_outlined),
            onPressed: () => context.go(AppRoutes.home),
          ),
          IconButton(
            tooltip: AppStrings.logout,
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.instance.signOut();
              if (context.mounted) context.go(AppRoutes.login);
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final sidebar = _buildSidebar(context);
          if (constraints.maxWidth < 700) {
            // شريط سفلي للجوال + قائمة جانبية قابلة للطي
            return Column(
              children: [
                Expanded(
                  child: IndexedStack(
                    index: _index,
                    children: _screens,
                  ),
                ),
                _buildBottomNav(context),
              ],
            );
          }
          return Row(
            children: [
              sidebar,
              VerticalDivider(
                width: 1,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
              Expanded(
                child: IndexedStack(index: _index, children: _screens),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final items = _navItems(context);
    final user = AuthService.instance.currentUser;
    return SizedBox(
      width: 232,
      child: Column(
        children: [
          // شعار العلامة التجارية
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.diamond, color: AppColors.secondary, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppStrings.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                      Text(
                        AppStrings.adminDashboard,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          // عناصر التنقل
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, i) {
                final selected = i == _index;
                return InkWell(
                  onTap: () => setState(() => _index = i),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          items[i].$1,
                          size: 20,
                          color: selected
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            items[i].$2,
                            style: TextStyle(
                              color: selected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurfaceVariant,
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // هوية المدير الحالي
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  child: Text(
                    _initial(user?.name),
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        (user?.name.isEmpty ?? true) ? AppStrings.admin : user!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      Text(
                        user?.email ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // فهارس التبويبات الأساسية (تظهر مباشرة في الشريط السفلي) مقابل الثانوية
  // (تُفتح عبر "المزيد") — تطابق ترتيب الشاشات في [_screens]
  static const _primaryIndices = [0, 1, 2, 3];
  static const _secondaryIndices = [4, 5, 6, 7, 8];

  Widget _buildBottomNav(BuildContext context) {
    final items = _navItems(context);
    final inSecondary = _secondaryIndices.contains(_index);
    return NavigationBar(
      selectedIndex: inSecondary ? _primaryIndices.length : _index,
      onDestinationSelected: (i) {
        if (i == _primaryIndices.length) {
          _openMoreSheet(context);
        } else {
          setState(() => _index = _primaryIndices[i]);
        }
      },
      destinations: [
        for (final i in _primaryIndices)
          NavigationDestination(icon: Icon(items[i].$1), label: items[i].$2),
        NavigationDestination(
          icon: Icon(
            Icons.more_horiz,
            color: inSecondary ? AppColors.secondary : null,
          ),
          label: AppStrings.more,
        ),
      ],
    );
  }

  Future<void> _openMoreSheet(BuildContext context) async {
    final items = _navItems(context);
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  AppStrings.more,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
            for (final i in _secondaryIndices)
              ListTile(
                leading: Icon(items[i].$1, color: AppColors.secondary),
                title: Text(
                  items[i].$2,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: _index == i
                    ? const Icon(Icons.check, color: AppColors.secondary)
                    : null,
                onTap: () => Navigator.pop(context, i),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _index = selected);
    }
  }

  String _initial(String? name) {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return 'A';
    return trimmed.substring(0, 1).toUpperCase();
  }

  List<(IconData, String)> _navItems(BuildContext context) => [
        (Icons.dashboard_outlined, AppStrings.adminDashboard),
        (Icons.inventory_2_outlined, AppStrings.adminProducts),
        (Icons.receipt_long_outlined, AppStrings.adminOrders),
        (Icons.local_offer_outlined, AppStrings.adminOffers),
        (Icons.confirmation_num_outlined, AppStrings.adminCoupons),
        (Icons.group_outlined, AppStrings.adminUsers),
        (Icons.notifications_active_outlined, AppStrings.adminNotifications),
        (Icons.support_agent_outlined, AppStrings.supportChat),
        (Icons.assignment_return_outlined, AppStrings.myRefundRequests),
      ];
}
