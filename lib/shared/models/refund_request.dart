/// حالة طلب الاسترداد
enum RefundStatus { pending, approved, rejected }

/// طلب استرداد نقود لطلب سابق
class RefundRequest {
  const RefundRequest({
    required this.id,
    required this.orderId,
    required this.userId,
    required this.reason,
    required this.amount,
    this.status = RefundStatus.pending,
    this.adminNote,
    this.createdAt,
    this.resolvedAt,
  });

  final String id;
  final String orderId;
  final String userId;
  final String reason;
  final double amount;
  final RefundStatus status;
  final String? adminNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  factory RefundRequest.fromMap(Map<String, dynamic> map, String id) {
    return RefundRequest(
      id: id,
      orderId: map['orderId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      reason: map['reason'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      status: _statusFromString(map['status'] as String? ?? 'pending'),
      adminNote: map['adminNote'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      resolvedAt: map['resolvedAt'] != null
          ? DateTime.tryParse(map['resolvedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'userId': userId,
      'reason': reason,
      'amount': amount,
      'status': status.name,
      'adminNote': adminNote,
      'createdAt': createdAt?.toIso8601String(),
      'resolvedAt': resolvedAt?.toIso8601String(),
    };
  }

  static RefundStatus _statusFromString(String value) {
    return RefundStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => RefundStatus.pending,
    );
  }
}
