import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/loyalty_service.dart';

/// شاشة نقاط الولاء: الرصيد الحالي + سجل الحركات
class PointsScreen extends StatelessWidget {
  const PointsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myPoints)),
      body: uid == null
          ? Center(child: Text(AppStrings.loginRequired))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StreamBuilder<int>(
                  stream: LoyaltyService.instance.watchPoints(uid),
                  builder: (context, snapshot) {
                    final points = snapshot.data ?? 0;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.secondary, AppColors.secondaryDark],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars_rounded, color: AppColors.secondary, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            '$points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppStrings.pointsBalance,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '≈ ${(points / 10).toStringAsFixed(2)} ر.س',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.howPointsWork,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.pointsHistory,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                StreamBuilder<List<PointsLedgerEntry>>(
                  stream: LoyaltyService.instance.watchLedger(uid),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final entries = snapshot.data ?? const <PointsLedgerEntry>[];
                    if (entries.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            AppStrings.noPointsYet,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Theme.of(context).colorScheme.outline),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [for (final entry in entries) _LedgerTile(entry: entry)],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _LedgerTile extends StatelessWidget {
  const _LedgerTile({required this.entry});

  final PointsLedgerEntry entry;

  @override
  Widget build(BuildContext context) {
    final positive = entry.points > 0;
    final label = switch (entry.type) {
      'earned' => 'نقاط مكتسبة من طلب',
      'redeemed' => 'استخدام نقاط بطلب',
      'refunded' => 'استرجاع نقاط (إلغاء طلب)',
      _ => entry.type,
    };
    final date = entry.createdAt;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (positive ? AppColors.success : Theme.of(context).colorScheme.error)
              .withValues(alpha: 0.12),
          child: Icon(
            positive ? Icons.add : Icons.remove,
            color: positive ? AppColors.success : Theme.of(context).colorScheme.error,
          ),
        ),
        title: Text(label),
        subtitle: date != null
            ? Text('${date.day}/${date.month}/${date.year}')
            : null,
        trailing: Text(
          '${positive ? '+' : ''}${entry.points}',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: positive ? AppColors.success : Theme.of(context).colorScheme.error,
          ),
        ),
      ),
    );
  }
}
