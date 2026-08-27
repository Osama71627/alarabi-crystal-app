import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import 'auth_service.dart';

/// خدمة الإشعارات عبر Firebase Cloud Messaging
/// - تطلب إذن العرض
/// - تسجّل رمز الجهاز وتخزّنه عند المستخدم في Firestore (fcmTokens)
/// - تعرض إشعاراً محلياً عند وصول رسالة والتطبيق في المقدمة
/// - تعالج الرسائل في الخلفية والمقدمة
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'general';
  static const _channelName = 'الإشعارات العامة';

  /// موضوع FCM الذي يرسل له push-server/ الإشعارات العامة (منتج/عرض جديد)
  static const _topicStoreUpdates = 'store_updates';

  String? _token;

  String? get token => _token;

  /// التهيئة: الأذونات + المعالجات + تسجيل الرمز
  Future<void> init() async {
    try {
      await _initLocalNotifications();

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('[notifications] permission=${settings.authorizationStatus.name}');

      // رسالة تصل أثناء تشغيل التطبيق — تُعرض كإشعار محلي
      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      // فتح التطبيق من إشعار (في الخلفية)
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[notifications] openedApp: ${message.data}');
        handleTap(message.data);
      });

      // إشعار فتح التطبيق من حالة الإنهاء
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        debugPrint('[notifications] initial: ${initial.data}');
        handleTap(initial.data);
      }

      await refreshToken();

      // الاشتراك بموضوع التحديثات العامة (منتجات/عروض جديدة) — يستقبله كل
      // الأجهزة المشتركة دفعة واحدة عبر الخادم الخارجي (push-server/)
      unawaited(_messaging.subscribeToTopic(_topicStoreUpdates));

      // تجديد الرمز تلقائياً
      _messaging.onTokenRefresh.listen((token) async {
        _token = token;
        debugPrint('[notifications] tokenRefreshed=${_redact(token)}');
        await _saveTokenToUser();
      });
    } catch (e) {
      debugPrint('[notifications] init error: $e');
    }
  }

  /// تهيئة الإشعارات المحلية + طلب إذن الإشعارات (أندرويد 13+)
  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
      ),
      onDidReceiveNotificationResponse: (response) {
        // الضغط على إشعار محلي معروض أثناء تشغيل التطبيق
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final data = jsonDecode(payload) as Map<String, dynamic>;
          handleTap(data);
        } catch (_) {
          // تجاهل payload غير صالح
        }
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// عرض إشعار محلي عند وصول رسالة والتطبيق في المقدمة
  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title;
    final body = message.notification?.body;
    if (title == null && body == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'إشعارات المتجر والعروض والطلبات',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  /// جلب رمز الجهاز وتخزينه عند المستخدم الحالي
  Future<String?> refreshToken() async {
    try {
      _token = await _messaging.getToken();
      debugPrint('[notifications] token=${_redact(_token)}');
      await _saveTokenToUser();
      return _token;
    } catch (e) {
      debugPrint('[notifications] getToken error: $e');
      return null;
    }
  }

  /// يعرض بداية الرمز فقط في السجلات (كافٍ للتشخيص دون كشف الرمز كاملاً)
  String _redact(String? token) {
    if (token == null || token.isEmpty) return 'null';
    return '${token.substring(0, token.length < 8 ? token.length : 8)}…';
  }

  /// حفظ الرمز في مستند المستخدم (fcmTokens) مع دمج جزئي
  Future<void> _saveTokenToUser() async {
    final token = _token;
    if (token == null) return;
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('users').doc(uid).set(
        {
          'fcmTokens': FieldValue.arrayUnion([token]),
        },
        SetOptions(merge: true),
      );
      debugPrint('[notifications] token saved for $uid');
    } catch (e) {
      debugPrint('[notifications] save token error: $e');
    }
  }

  /// التنقل إلى الصفحة المقصودة عند الضغط على الإشعار
  /// (نوع الصفحة ورقمها داخل data payload من Cloud Function)
  void handleTap(Map<String, dynamic> data) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null) return;
    final type = data['type'] as String? ?? 'general';
    final linkId = data['linkId'] as String? ?? '';
    switch (type) {
      case 'product':
        if (linkId.isNotEmpty) {
          context.push(AppRoutes.productDetailsLink(linkId));
        } else {
          context.push(AppRoutes.products);
        }
      case 'offer':
        if (linkId.isNotEmpty) {
          context.push(AppRoutes.offerDetailsLink(linkId));
        } else {
          context.push(AppRoutes.offers);
        }
      case 'order':
        if (linkId.isNotEmpty) {
          context.push(AppRoutes.orderDetailsLink(linkId));
        } else {
          context.push(AppRoutes.orders);
        }
      default:
        context.push(AppRoutes.offers);
    }
  }
}
