import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'app.dart';
import 'injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // بلا انتظار عمداً: تفعيل App Check يجب ألا يؤخّر إقلاع التطبيق، ولا
  // يمنع أي شيء حتى يُفعَّل Enforcement صراحة من Firebase Console (راجع
  // تقرير المرحلة 13) — يبدأ الآن بوضع Debug/Monitor فقط.
  unawaited(_activateAppCheck());
  await setupLocator();
  runApp(const AlArabiApp());
}

/// تفعيل Firebase App Check — يثبت أن الطلب صادر من نسخة تطبيق أصلية لا
/// من سكربت خارجي يستدعي Firestore/Storage مباشرة (يحمي من استنزاف حصة
/// القراءة المجانية اليومية — راجع الثغرة H1 في تقرير المرحلة 12).
///
/// ⚠️ بوضع Debug/Monitor فقط حالياً: لا يحجب أي طلب حتى لو فشل التفعيل أو
/// لم يُسجَّل رمز التصحيح بعد — يتطلب إكمال إعداد Firebase Console (تسجيل
/// رمز Debug Token، ثم التأكد أن المقاييس سليمة قبل تفعيل Enforcement).
/// فشل هذه الدالة لا يجب أن يمنع تشغيل التطبيق أبداً.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: kDebugMode
          ? const AppleDebugProvider()
          : const AppleAppAttestProvider(),
    );
  } catch (_) {
    // بصمت — أي فشل هنا (شبكة، إعداد ناقص في الكونسول) لا يجب أن يمنع
    // عمل التطبيق طالما Enforcement غير مُفعَّل بعد على مستوى Firebase
  }
}
