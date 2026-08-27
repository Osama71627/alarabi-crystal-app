import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/notifications_feed.dart';
import '../../../admin/domain/repositories/admin_repository.dart';

/// شاشة الإشعارات — تقرأ من مجموعة notifications في Firestore
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    _markAllRead();
  }

  /// عند فتح الشاشة يُحدَّث وقت آخر قراءة لتُصفَّر شارة الإشعارات
  Future<void> _markAllRead() async {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(
            {'lastNotifReadAt': DateTime.now().toIso8601String()},
            SetOptions(merge: true),
          );
    } catch (_) {
      // تجاهل — فشل التحديث لا يمنع عرض الإشعارات
    }
  }

  /// هل يخصّ هذا الإشعار المستخدم الحالي؟
  bool _isMine(AdminNotification notification) {
    final uid = AuthService.instance.currentUser?.uid;
    switch (notification.target) {
      case NotificationTarget.all:
      case NotificationTarget.category:
        return true;
      case NotificationTarget.user:
        return uid != null && notification.targetId == uid;
      case NotificationTarget.admin:
        return AuthService.instance.isAdmin;
    }
  }

  /// التنقل إلى الصفحة المقصودة عند الضغط على الإشعار
  void _openNotification(AdminNotification notification) {
    final linkId = notification.linkId;
    switch (notification.type) {
      case 'product':
        if (linkId != null && linkId.isNotEmpty) {
          context.push(AppRoutes.productDetailsLink(linkId));
        } else {
          context.push(AppRoutes.products);
        }
      case 'offer':
        if (linkId != null && linkId.isNotEmpty) {
          context.push(AppRoutes.offerDetailsLink(linkId));
        } else {
          context.push(AppRoutes.offers);
        }
      case 'order':
        if (linkId != null && linkId.isNotEmpty) {
          context.push(AppRoutes.orderDetailsLink(linkId));
        } else {
          context.push(AppRoutes.orders);
        }
      default:
        context.push(AppRoutes.offers);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.notifications),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text(AppStrings.markAllRead),
          ),
        ],
      ),
      body: StreamBuilder<List<AdminNotification>>(
        stream: NotificationsFeed.watch(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(AppStrings.errorGeneric));
          }

          final notifications =
              (snapshot.data ?? const <AdminNotification>[])
                  .where(_isMine)
                  .toList();

          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppStrings.emptyNotifications,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height:12),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () => _openNotification(notification),
              );
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AdminNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(_iconForType, color: AppColors.secondary),
        ),
        title: Text(
          notification.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              _relativeTime(notification.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }

  IconData get _iconForType {
    switch (notification.type) {
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'offer':
        return Icons.local_offer_outlined;
      case 'order':
        return Icons.local_shipping_outlined;
      default:
        return Icons.notifications;
    }
  }

  String _relativeTime(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}
