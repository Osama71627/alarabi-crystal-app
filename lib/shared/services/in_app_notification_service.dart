import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'notifications_feed.dart';

/// إشعارات منبثقة داخل التطبيق (Foreground) — تُكمّل [NotificationService]
/// التي تعتمد على FCM (يصل فقط من خادم خارجي). هذه الخدمة تستمع مباشرة
/// لمجموعة notifications في Firestore (بلا أي خادم) وتعرض SnackBar فوري
/// لأي إشعار جديد طالما التطبيق مفتوحاً — تعمل حتى بدون اتصال FCM.
///
/// لا تعرض شيئاً للإشعارات الموجودة مسبقاً عند بدء التطبيق (تُسجَّل كمقروءة
/// "مرئية" فوراً)، فقط لما يصل جديداً أثناء الجلسة الحالية.
class InAppNotificationService {
  InAppNotificationService._internal();
  static final InAppNotificationService instance =
      InAppNotificationService._internal();

  StreamSubscription<List<AdminNotification>>? _sub;
  final Set<String> _seenIds = {};
  bool _initialized = false;

  void init() {
    _sub?.cancel();
    _initialized = false;
    _seenIds.clear();
    _sub = NotificationsFeed.watch(limit: 20).listen(_onSnapshot);
  }

  void _onSnapshot(List<AdminNotification> notifications) {
    if (!_initialized) {
      // أول تحميل: نسجّل الموجود مسبقاً كمرئي بلا عرض أي شيء
      for (final notification in notifications) {
        _seenIds.add(notification.id);
      }
      _initialized = true;
      return;
    }

    for (final notification in notifications) {
      if (_seenIds.contains(notification.id)) continue;
      _seenIds.add(notification.id);
      if (!_isMine(notification)) continue;
      _showPopup(notification);
    }
  }

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

  void _showPopup(AdminNotification notification) {
    final messenger = AppRouter.scaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.secondaryDark,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notification.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (notification.body.isNotEmpty)
              Text(notification.body, style: const TextStyle(color: Colors.white)),
          ],
        ),
        action: SnackBarAction(
          label: 'عرض',
          textColor: AppColors.secondaryLight,
          onPressed: () => NotificationService.instance.handleTap({
            'type': notification.type,
            'linkId': notification.linkId,
          }),
        ),
      ),
    );
  }

  void dispose() {
    _sub?.cancel();
  }
}
