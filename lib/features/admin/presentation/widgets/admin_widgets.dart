import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';

/// رسم بياني شريطي للمبيعات اليومية (بدون مكتبات خارجية)
class SalesBarChart extends StatelessWidget {
  const SalesBarChart({
    super.key,
    required this.labels,
    required this.values,
  });

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (m, v) => math.max(m, v));
    final safeMax = maxValue <= 0 ? 1.0 : maxValue;

    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final ratio = values[i] / safeMax;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: values[i].toStringAsFixed(0),
                    child: Container(
                      height: math.max(4, 140 * ratio),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: values[i] > 0
                              ? [
                                  AppColors.primary,
                                  AppColors.secondary,
                                ]
                              : [
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    labels[i],
                    style: const TextStyle(fontSize: 10),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// بطاقة إحصائية بسيطة
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subLabel,
    this.color = AppColors.primary,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? subLabel;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (subLabel != null) ...[
              const SizedBox(height: 2),
              Text(
                subLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// رأس صفحة موحّد لكل شاشات لوحة الإدارة: أيقونة + عنوان + عدّاد/وصف
/// اختياري + إجراءات على اليمين. يحل محل الرؤوس المتفرقة التي كانت بكل
/// شاشة بأسلوبها الخاص.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(width: 8),
            Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ],
      ),
    );
  }
}

/// حالة فارغة موحّدة (لا بيانات) لكل قوائم لوحة الإدارة
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: scheme.surfaceContainerHighest,
              ),
              child: Icon(icon, size: 32, color: scheme.outline),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: scheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// شارة حالة دائرية صغيرة (Pill) بلون خلفية فاتح ونص/أيقونة بنفس اللون —
/// تُستخدم لحالة الطلب، تفعيل العروض، توفر المخزون...
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 10.5 : 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// بطاقة قسم بعنوان وأيقونة موحّدين — تلف أي مجموعة حقول/محتوى ضمن
/// شاشات الإدارة (نماذج، تفاصيل الطلب...) بمظهر واحد بدل التكرار.
class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  final String title;
  final IconData? icon;
  final Widget? trailing;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: AppColors.secondary),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
