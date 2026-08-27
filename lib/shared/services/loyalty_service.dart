import 'package:cloud_firestore/cloud_firestore.dart';

/// حركة بسجل نقاط الولاء (كسب/استخدام/استرجاع)
class PointsLedgerEntry {
  const PointsLedgerEntry({
    required this.type,
    required this.points,
    this.orderId,
    this.createdAt,
  });

  final String type; // earned / redeemed / refunded
  final int points;
  final String? orderId;
  final DateTime? createdAt;

  factory PointsLedgerEntry.fromMap(Map<String, dynamic> map) {
    return PointsLedgerEntry(
      type: map['type'] as String? ?? '',
      points: (map['points'] as num?)?.toInt() ?? 0,
      orderId: map['orderId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }
}

/// خدمة نقاط الولاء.
///
/// كانت النقاط تُمنح عبر Cloud Function (onOrderUpdate) عند تسليم الطلب،
/// لكن تلك الدالة غير منشورة (خطة Firebase المجانية) فلم تُمنح أي نقاط
/// إطلاقاً وبقي الرصيد صفراً دائماً — أي أن ميزة الولاء كانت معطّلة كلياً.
///
/// البديل: تُمنح النقاط من تطبيق **الإدارة** لحظة تعليم الطلب "تم التوصيل"
/// (المدير طرف موثوق وقواعد Firestore تسمح له بتعديل رصيد المستخدم)، داخل
/// معاملة واحدة مع تسجيل حركة في pointsLedger ووسم الطلب بأن نقاطه مُنحت
/// حتى لا تتكرر. العميل نفسه لا يستطيع زيادة رصيده (القواعد تمنع الزيادة).
///
/// عمداً بمعزل عن AppUser/AuthService حتى لا يتعارض الحفظ المحلي لبيانات
/// الملف الشخصي مع الرصيد المُدار مركزياً.
class LoyaltyService {
  LoyaltyService._internal();
  static final LoyaltyService instance = LoyaltyService._internal();

  /// ريال واحد لكل 10 ريالات مشتريات (نفس نسبة الاستبدال بالسلة)
  static const int pointsEarnDivisor = 10;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// منح نقاط طلب مُسلَّم لصاحبه — تُستدعى من لوحة الإدارة.
  /// آمنة للتكرار: إن كانت نقاط الطلب مُنحت سابقاً لا تُمنح مرة أخرى.
  Future<int> awardPointsForDeliveredOrder({
    required String orderId,
    required String userId,
    required double orderTotal,
  }) async {
    final points = (orderTotal / pointsEarnDivisor).floor();
    if (points <= 0 || userId.isEmpty) return 0;

    return _firestore.runTransaction<int>((tx) async {
      final orderRef = _firestore.collection('orders').doc(orderId);
      final orderSnap = await tx.get(orderRef);
      if (!orderSnap.exists) return 0;
      if (orderSnap.data()?['pointsAwarded'] == true) return 0;

      final userRef = _firestore.collection('users').doc(userId);
      final userSnap = await tx.get(userRef);
      final current = (userSnap.data()?['points'] as num?)?.toInt() ?? 0;

      tx.update(userRef, {'points': current + points});
      tx.update(orderRef, {'pointsAwarded': true});
      tx.set(_firestore.collection('pointsLedger').doc(), {
        'userId': userId,
        'type': 'earned',
        'points': points,
        'orderId': orderId,
        'createdAt': DateTime.now().toIso8601String(),
      });
      return points;
    });
  }

  /// بث رصيد النقاط الحالي لمستخدم
  Stream<int> watchPoints(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map(
          (doc) => (doc.data()?['points'] as num?)?.toInt() ?? 0,
        );
  }

  /// بث سجل حركات النقاط (الأحدث أولاً)
  Stream<List<PointsLedgerEntry>> watchLedger(String uid) {
    return _firestore
        .collection('pointsLedger')
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => PointsLedgerEntry.fromMap(doc.data())).toList());
  }
}
