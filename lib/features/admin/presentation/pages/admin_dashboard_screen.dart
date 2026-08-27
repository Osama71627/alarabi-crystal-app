import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../domain/admin_stats.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_widgets.dart';

/// لوحة الإحصائيات الرئيسية
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  AdminStats? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await sl<AdminRepository>().getStats();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = AuthService.instance.currentUser?.name;
    final greeting = (name == null || name.trim().isEmpty)
        ? AppStrings.adminDashboard
        : 'مرحباً، ${name.trim()} 👋';

    return Column(
      children: [
        AdminPageHeader(
          icon: Icons.dashboard_outlined,
          title: greeting,
          subtitle: _dateLabel(),
          actions: [
            IconButton.filledTonal(
              tooltip: AppStrings.retry,
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _stats == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(AppStrings.errorGeneric),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text(AppStrings.retry),
            ),
          ],
        ),
      );
    }

    final stats = _stats!;
    final chartLabels = stats.dailySales
        .map((p) => '${p.date.day}/${p.date.month}')
        .toList();
    final chartValues = stats.dailySales.map((p) => p.amount).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          // المبيعات
          _SectionLabel(AppStrings.salesStats),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: [
              StatCard(
                icon: Icons.today,
                label: AppStrings.today,
                value: CurrencyFormatter.formatClean(stats.salesToday),
                color: const Color(0xFF2196F3),
              ),
              StatCard(
                icon: Icons.date_range,
                label: AppStrings.thisMonth,
                value: CurrencyFormatter.formatClean(stats.salesThisMonth),
                color: const Color(0xFF4CAF50),
              ),
              StatCard(
                icon: Icons.calendar_month,
                label: AppStrings.thisYear,
                value: CurrencyFormatter.formatClean(stats.salesThisYear),
                color: const Color(0xFF9C27B0),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // الطلبات والمستخدمون
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.3,
            children: [
              StatCard(
                icon: Icons.receipt_long,
                label: AppStrings.totalOrders,
                value: '${stats.ordersCount}',
                subLabel: '${AppStrings.pendingOrders}: ${stats.pendingOrders}',
                color: AppColors.warning,
              ),
              StatCard(
                icon: Icons.people,
                label: AppStrings.totalUsers,
                value: '${stats.totalUsers}',
                subLabel:
                    '${AppStrings.newThisMonth}: ${stats.newUsersThisMonth}',
                color: const Color(0xFF00ACC1),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // الرسم البياني
          AdminSectionCard(
            title: AppStrings.salesLast7Days,
            icon: Icons.show_chart,
            child: SalesBarChart(labels: chartLabels, values: chartValues),
          ),
          const SizedBox(height: 24),

          // الأكثر مبيعاً
          _SectionLabel(AppStrings.bestSellers),
          const SizedBox(height: 8),
          if (stats.bestSellers.isEmpty)
            const AdminEmptyState(
              icon: Icons.diamond_outlined,
              title: AppStrings.noData,
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    for (final entry in stats.bestSellers.asMap().entries)
                      _BestSellerRow(rank: entry.key + 1, product: entry.value),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _dateLabel() {
    final now = DateTime.now();
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.secondary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

class _BestSellerRow extends StatelessWidget {
  const _BestSellerRow({required this.rank, required this.product});

  final int rank;
  final Product product;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        alignment: Alignment.center,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
            child: const Icon(
              Icons.diamond,
              color: AppColors.secondary,
              size: 18,
            ),
          ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 18,
              height: 18,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: StatusPill(
        label: '${product.soldCount} ${AppStrings.soldUnits}',
        color: AppColors.success,
        dense: true,
      ),
    );
  }
}
