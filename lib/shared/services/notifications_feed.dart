import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/admin/domain/repositories/admin_repository.dart';
import 'auth_service.dart';

/// بث مجموعة notifications بأمان بعد تشديد قواعد Firestore (إصلاح M1).
///
/// المشكلة التي يحلّها هذا الملف: القاعدة الجديدة تمنح كل مستند صلاحية
/// قراءة منفصلة (عام، أو موجَّه لصاحبه فقط). استعلام واحد غير مُصفّى على
/// المجموعة كاملة سيطابق حتماً مستندات موجَّهة لعملاء آخرين، وقواعد
/// Firestore تُفشل الاستعلام **بالكامل** إن رفضت قراءة أي مستند واحد يطابقه
/// — فيتعطّل عرض الإشعارات كلياً بدل إخفاء بعضها فقط.
///
/// الحل: استعلامان منفصلان يطابق كل منهما فقط مستندات يملك القارئ صلاحية
/// عليها فعلاً بحسب القاعدة نفسها، ثم دمجهما هنا في التطبيق:
/// 1) العام: target في ['all','category'] — مسموح لأي مستخدم مسجَّل.
/// 2) الموجَّه لي: targetId == uid — بما أن الكتابة الوحيدة لهذا الحقل
///    تكون بقاعدة target=='user' معه دائماً، فأي مستند يطابق هذا الاستعلام
///    يُضمَن أنه يجتاز قاعدة القراءة (راجع firestore.rules).
///
/// المدير حالة خاصة: قاعدته `isAdmin()` تسمح بقراءة المجموعة كاملة دون
/// قيد، فيُستخدم استعلام واحد غير مُصفّى بدل الاستعلامين (يطابق ما تعرضه
/// لوحة الإدارة أصلاً في `watchNotifications`).
///
/// ⚠️ استعلام "الموجَّه لي" يقيّد `target == 'user'` **بالإضافة** إلى
/// `targetId == uid` معاً — وليس `targetId` وحدها. القاعدة تحتاج ضمان أن
/// كل حقل تعتمد عليه مقيَّد فعلياً بالاستعلام نفسه (راجع التعليق في
/// firestore.rules)؛ استعلام بحقل واحد فقط تعرّض تجريبياً لخطأ تقييم من
/// محرّك أمان Firestore يمنع الاستعلام المشروع نفسه من العمل.
class NotificationsFeed {
  NotificationsFeed._();

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection('notifications');

  /// بث الإشعارات التي يملك المستخدم الحالي صلاحية قراءتها، مدموجة ومرتبة
  /// (الأحدث أولاً) بحدّ أعلى [limit].
  ///
  /// ⚠️ إصلاح خلل مُبلَّغ: الإشعارات العامة (target: all/category) كانت
  /// تُجلَب بلا أي قيد زمني، فيرى أي مستخدم جديد **كل** الإشعارات العامة
  /// منذ إنشاء المتجر (إعلانات منتجات/عروض سبقت وجود حسابه أصلاً). الآن
  /// تُستبعَد بعد الجلب أي إشعارات عامة سابقة لتاريخ إنشاء حسابه — لا يرى
  /// إلا ما نُشر بعد انضمامه، تماماً كما يتوقع أي مستخدم جديد.
  /// المستخدمون الحاليون غير متأثرين عملياً (تاريخ انضمامهم أصلاً يسبق كل
  /// الإشعارات المعروضة لهم). الاستبعاد يتم في التطبيق لا بشرط Firestore
  /// إضافي، تفادياً لحاجة فهرس مركّب جديد لم يُتحقَّق من وجوده فعلياً.
  static Stream<List<AdminNotification>> watch({int limit = 100}) {
    if (AuthService.instance.isAdmin) {
      return _collection
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snap) => _parse(snap.docs));
    }

    final currentUser = AuthService.instance.currentUser;
    final uid = currentUser?.uid;
    final joinedAt = currentUser?.createdAt;

    final publicStream = _collection
        .where('target', whereIn: ['all', 'category'])
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => excludeBeforeJoin(_parse(snap.docs), joinedAt));

    if (uid == null) {
      return publicStream;
    }

    final mineStream = _collection
        .where('target', isEqualTo: 'user')
        .where('targetId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => _parse(snap.docs));

    return _mergeStreams(publicStream, mineStream, limit: limit);
  }

  /// دمج تدفقين إلى بث واحد: كل تحديث من أي مصدر يعيد بناء واحصائم
  /// القائمة المدموجة كاملة
  static Stream<List<AdminNotification>> _mergeStreams(
    Stream<List<AdminNotification>> a,
    Stream<List<AdminNotification>> b, {
    required int limit,
  }) {
    late final StreamController<List<AdminNotification>> controller;
    List<AdminNotification> latestA = const [];
    List<AdminNotification> latestB = const [];
    StreamSubscription<List<AdminNotification>>? subA;
    StreamSubscription<List<AdminNotification>>? subB;

    void emit() {
      if (!controller.isClosed) {
        controller.add(merge(latestA, latestB, limit: limit));
      }
    }

    controller = StreamController<List<AdminNotification>>.broadcast(
      onListen: () {
        subA = a.listen((v) {
          latestA = v;
          emit();
        }, onError: controller.addError);
        subB = b.listen((v) {
          latestB = v;
          emit();
        }, onError: controller.addError);
      },
      onCancel: () async {
        await subA?.cancel();
        await subB?.cancel();
      },
    );
    return controller.stream;
  }

  /// دمج قائمتين بلا تكرار (بحسب المعرّف) مع ترتيب الأحدث أولاً وقصّها
  /// على [limit] — منطق نقي بلا اتصال، قابل للاختبار وحده
  static List<AdminNotification> merge(
    List<AdminNotification> a,
    List<AdminNotification> b, {
    int limit = 100,
  }) {
    final byId = <String, AdminNotification>{};
    for (final n in a) {
      byId[n.id] = n;
    }
    for (final n in b) {
      byId[n.id] = n;
    }
    final result = byId.values.toList()
      ..sort((x, y) {
        final xDate = x.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final yDate = y.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return yDate.compareTo(xDate);
      });
    return result.length > limit ? result.sublist(0, limit) : result;
  }

  /// يستبعد أي إشعار سابق لتاريخ انضمام المستخدم — راجع الشرح في [watch].
  /// إشعار بلا تاريخ إنشاء معروف (createdAt == null) يبقى ظاهراً عمداً
  /// بدل إخفائه بالخطأ لغموض تاريخه
  static List<AdminNotification> excludeBeforeJoin(
    List<AdminNotification> notifications,
    DateTime? joinedAt,
  ) {
    if (joinedAt == null) return notifications;
    return notifications
        .where((n) => n.createdAt == null || !n.createdAt!.isBefore(joinedAt))
        .toList();
  }

  static List<AdminNotification> _parse(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) =>
      docs.map((doc) => AdminNotification.fromMap(doc.data(), doc.id)).toList();
}
