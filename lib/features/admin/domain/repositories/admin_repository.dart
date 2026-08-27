import '../../../../shared/models/app_user.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/models/product.dart';
import '../admin_stats.dart';

/// نوع استهداف الإشعار الإداري
enum NotificationTarget { all, category, user, admin }

/// إشعار إداري مُرسل
class AdminNotification {
  const AdminNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.target,
    this.targetId,
    this.type = 'general',
    this.linkId,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final NotificationTarget target;
  final String? targetId;

  /// نوع الرابط للتنقل عند الضغط (product / offer / order / general)
  final String type;
  final String? linkId;
  final DateTime? createdAt;

  factory AdminNotification.fromMap(Map<String, dynamic> map, String id) {
    return AdminNotification(
      id: id,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      target: _targetFromString(map['target'] as String? ?? 'all'),
      targetId: map['targetId'] as String?,
      type: map['type'] as String? ?? 'general',
      linkId: map['linkId'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'target': target.name,
      'targetId': targetId,
      'type': type,
      'linkId': linkId,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  static NotificationTarget _targetFromString(String value) {
    return NotificationTarget.values.firstWhere(
      (e) => e.name == value,
      orElse: () => NotificationTarget.all,
    );
  }
}

/// واجهة مستودع لوحة الإدارة
abstract class AdminRepository {
  /// جلب إحصاءات اللوحة
  Future<AdminStats> getStats();

  /// بث جميع الطلبات
  Stream<List<Order>> watchAllOrders();

  /// جلب جميع المستخدمين
  Future<List<AppUser>> getAllUsers();

  /// جلب مستخدم بالمعرف
  Future<AppUser?> getUser(String uid);

  /// إرسال إشعار (يُخزَّن في مجموعة notifications)
  Future<void> sendNotification(AdminNotification notification);

  /// بث الإشعارات المُرسلة
  Stream<List<AdminNotification>> watchNotifications();

  /// جلب المنتجات لتحديد الأكثر مبيعاً
  Future<List<Product>> getProducts();
}
