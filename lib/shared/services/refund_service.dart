import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/refund_request.dart';

/// خطأ استرداد برسالة عربية قابلة للعرض مباشرة
class RefundException implements Exception {
  RefundException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// خدمة طلبات الاسترداد — العميل يُنشئ طلبه مباشرة (لا يحتاج خادماً، لا
/// يمس مالاً)، أما القرار الفعلي (الموافقة/الرفض) واسترداد المبلغ عبر
/// Stripe فيتم حصراً عبر Cloud Function (processRefundRequest) بصلاحيات
/// Admin SDK حتى يبقى مرتبطاً بعملية الاسترداد المالي الفعلية.
class RefundService {
  RefundService._internal();
  static final RefundService instance = RefundService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('refundRequests');

  Future<void> requestRefund({
    required String orderId,
    required String userId,
    required String reason,
    required double amount,
  }) async {
    final id = _requests.doc().id;
    final request = RefundRequest(
      id: id,
      orderId: orderId,
      userId: userId,
      reason: reason.trim(),
      amount: amount,
      createdAt: DateTime.now(),
    );
    final map = request.toMap()
      ..removeWhere((key, value) => value == null);
    await _requests.doc(id).set(map);
  }

  /// طلبات استرداد مستخدم معيّن لطلب معيّن (للتحقق هل سبق تقديم طلب)
  Stream<List<RefundRequest>> watchByOrder(String orderId) {
    return _requests
        .where('orderId', isEqualTo: orderId)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RefundRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// كل طلبات مستخدم معيّن
  Stream<List<RefundRequest>> watchMyRequests(String uid) {
    return _requests
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RefundRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// حدّ أعلى مقصود (المرحلة 13 — M6): كانت كل طلبات الاسترداد تاريخياً
  /// تُحمَّل بلا سقف. سخي بما يكفي لسجل استرداد فعلي بحجم المتجر الحالي.
  static const int _allRequestsLimit = 200;

  /// كل الطلبات (للوحة الإدارة)
  Stream<List<RefundRequest>> watchAllRequests() {
    return _requests
        .orderBy('createdAt', descending: true)
        .limit(_allRequestsLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RefundRequest.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// تسجيل قرار الإدارة (موافقة/رفض) على طلب الاسترجاع.
  ///
  /// كان هذا يمرّ بـ Cloud Function (processRefundRequest) تُنفّذ استرداداً
  /// فعلياً عبر Stripe، لكن تلك الدالة غير منشورة (المشروع على خطة Firebase
  /// المجانية) فكان القرار يفشل دائماً ولا تقدر الإدارة على معالجة أي طلب.
  ///
  /// وطرق الدفع الحالية (عند الاستلام / تحويل بنكي) لا تسمح باسترداد آلي
  /// أصلاً — الإرجاع يتم يدوياً من المتجر — فالمطلوب هنا هو تسجيل القرار
  /// فقط. الكتابة مقصورة على المدير بقواعد Firestore.
  Future<void> resolve({
    required String requestId,
    required bool approve,
    String? adminNote,
  }) async {
    try {
      await _requests.doc(requestId).update({
        'status': approve ? RefundStatus.approved.name : RefundStatus.rejected.name,
        'resolvedAt': DateTime.now().toIso8601String(),
        if (adminNote != null && adminNote.trim().isNotEmpty)
          'adminNote': adminNote.trim(),
      });
    } catch (_) {
      throw RefundException('تعذر معالجة الطلب');
    }
  }
}
