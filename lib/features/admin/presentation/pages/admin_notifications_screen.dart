import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/push_trigger_service.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_widgets.dart';

/// إرسال الإشعارات + سجل الإشعارات المُرسلة
class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _targetId = TextEditingController();
  NotificationTarget _target = NotificationTarget.all;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _targetId.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.fillRequired)),
      );
      return;
    }
    setState(() => _sending = true);
    final notification = AdminNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      body: _body.text.trim(),
      target: _target,
      targetId: _target == NotificationTarget.all
          ? null
          : _targetId.text.trim(),
      createdAt: DateTime.now(),
    );
    try {
      await sl<AdminRepository>().sendNotification(notification);
      // إرسال Push فعلي (يصل حتى لو التطبيق مغلق) للإرسال العام فقط —
      // موضوع FCM يبث للجميع، فلا معنى لاستخدامه مع استهداف فئة/مستخدم محدد
      if (_target == NotificationTarget.all) {
        unawaited(PushTriggerService.instance.notify(
          title: notification.title,
          body: notification.body,
        ));
      }
      if (mounted) {
        setState(() {
          _sending = false;
          _title.clear();
          _body.clear();
          _targetId.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.notificationSent)),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AdminPageHeader(
          icon: Icons.notifications_active_outlined,
          title: AppStrings.adminNotifications,
          subtitle: 'إرسال إشعارات فورية للعملاء والمدراء',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              AdminSectionCard(
                title: AppStrings.sendNotification,
                icon: Icons.send_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _title,
                      decoration:
                          const InputDecoration(labelText: AppStrings.notifTitle),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _body,
                      maxLines: 3,
                      decoration:
                          const InputDecoration(labelText: AppStrings.notifBody),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<NotificationTarget>(
                      initialValue: _target,
                      decoration:
                          const InputDecoration(labelText: AppStrings.notifTarget),
                      items: [
                        for (final target in NotificationTarget.values)
                          DropdownMenuItem(
                            value: target,
                            child: Text(_targetLabel(target)),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _target = v ?? NotificationTarget.all),
                    ),
                    if (_target != NotificationTarget.all) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _targetId,
                        decoration: InputDecoration(
                          labelText: _target == NotificationTarget.category
                              ? AppStrings.categoryId
                              : AppStrings.userId,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_outlined),
                        label: const Text(AppStrings.sendNotification),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              StreamBuilder<List<AdminNotification>>(
                stream: sl<AdminRepository>().watchNotifications(),
                builder: (context, snapshot) {
                  final notifications =
                      snapshot.data ?? const <AdminNotification>[];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                            AppStrings.sentNotifications,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          if (notifications.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            StatusPill(
                              label: '${notifications.length}',
                              color: AppColors.primary,
                              dense: true,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (notifications.isEmpty)
                        const AdminEmptyState(
                          icon: Icons.notifications_none_outlined,
                          title: AppStrings.noData,
                        )
                      else
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              children: [
                                for (final n in notifications)
                                  ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppColors.primary.withValues(alpha: 0.1),
                                      child: const Icon(
                                        Icons.notifications_outlined,
                                        color: AppColors.primary,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      n.title,
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      n.body,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: Text(
                                      _date(n.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context).colorScheme.outline,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _targetLabel(NotificationTarget target) {
    switch (target) {
      case NotificationTarget.all:
        return AppStrings.sendToAll;
      case NotificationTarget.category:
        return AppStrings.sendToCategory;
      case NotificationTarget.user:
        return AppStrings.sendToUser;
      case NotificationTarget.admin:
        return AppStrings.sendToAdmin;
    }
  }

  String _date(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }
}
