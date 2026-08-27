import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/order_service.dart';
import '../../domain/admin_stats.dart';
import '../../domain/repositories/admin_repository.dart';

/// مستودع لوحة الإدارة عبر Firestore
class FirestoreAdminRepository implements AdminRepository {
  FirestoreAdminRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection('orders');

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection('notifications');

  @override
  Future<List<Product>> getProducts() async {
    final snapshot =
        await _firestore.collection('products').limit(_statsLimit).get();
    return snapshot.docs
        .map((doc) => Product.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// سقف السجلات المقروءة لحساب الإحصاءات.
  ///
  /// كانت الدالة تقرأ **كل** الطلبات والمستخدمين والمنتجات في كل مرة تُفتح
  /// فيها لوحة التحكم — مع نمو المتجر يعني هذا آلاف عمليات قراءة (تكلفة
  /// وبطء) في كل فتحة. الإحصاءات المعروضة زمنية (اليوم/الشهر/السنة) فيكفي
  /// أحدث سجل، ونقرأه مرتّباً تنازلياً بحدّ أعلى.
  static const int _statsLimit = 500;

  @override
  Future<AdminStats> getStats() async {
    final ordersFuture =
        _orders.orderBy('createdAt', descending: true).limit(_statsLimit).get();
    final usersFuture = _users.limit(_statsLimit).get();
    final productsFuture =
        _firestore.collection('products').limit(_statsLimit).get();

    final results = await Future.wait([
      ordersFuture,
      usersFuture,
      productsFuture,
    ]);

    final orders = results[0].docs
        .map((doc) => Order.fromMap(doc.data(), doc.id))
        .toList();
    final users = results[1].docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
    final products = results[2].docs
        .map((doc) => Product.fromMap(doc.data(), doc.id))
        .toList();

    return AdminStatsCalculator.calculate(
      orders: orders,
      users: users,
      products: products,
    );
  }

  @override
  Stream<List<Order>> watchAllOrders() =>
      OrderService.instance.watchAllOrders();

  @override
  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await _users.limit(_statsLimit).get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap(doc.data(), doc.id))
        .toList();
  }

  @override
  Future<AppUser?> getUser(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  @override
  Future<void> sendNotification(AdminNotification notification) async {
    await _notifications.doc(notification.id).set(_sanitize(
      notification.toMap(),
    ));
  }

  /// حدّ أعلى مقصود (المرحلة 13 — M6): سجل كل الإشعارات المُرسَلة تاريخياً
  /// من لوحة الإدارة كان يُحمَّل بلا سقف. سخي بما يكفي للسجل الحديث الفعلي.
  static const int _notificationsLimit = 200;

  @override
  Stream<List<AdminNotification>> watchNotifications() {
    return _notifications
        .orderBy('createdAt', descending: true)
        .limit(_notificationsLimit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => AdminNotification.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// إزالة القيم الفارغة (Firestore لا يقبل null)
  Map<String, dynamic> _sanitize(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) return;
      if (value is Map<String, dynamic>) {
        result[key] = _sanitize(value);
      } else if (value is Map) {
        result[key] = _sanitize(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
