import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/notifications_feed.dart';
import '../../../admin/domain/repositories/admin_repository.dart';

/// أيقونة الإشعارات مع شارة عدد غير المقروء
/// - تحسب الإشعارات العامة + الإشعارات الموجهة للمستخدم بعد وقت آخر قراءة
/// - عند الضغط تفتح شاشة الإشعارات (التي تُصفّر الشارة عند فتحها)
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      return IconButton(
        onPressed: () => context.push(AppRoutes.notifications),
        icon: const Icon(Icons.notifications_outlined),
        tooltip: AppStrings.notifications,
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, userSnapshot) {
        final lastReadRaw =
            (userSnapshot.data?.data() as Map<String, dynamic>?)
                ?['lastNotifReadAt'];
        final lastRead =
            DateTime.tryParse(lastReadRaw?.toString() ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);

        return StreamBuilder<List<AdminNotification>>(
          stream: NotificationsFeed.watch(limit: 200),
          builder: (context, notifSnapshot) {
            int unread = 0;
            if (notifSnapshot.hasData) {
              for (final notification in notifSnapshot.data!) {
                final createdAt = notification.createdAt;
                if (createdAt != null && createdAt.isAfter(lastRead)) {
                  unread++;
                }
              }
            }

            return IconButton(
              onPressed: () => context.push(AppRoutes.notifications),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text(unread > 99 ? '99+' : '$unread'),
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: AppStrings.notifications,
            );
          },
        );
      },
    );
  }
}
