import 'cart_item.dart';

/// حالات الطلب
enum OrderStatus {
  pending, // قيد الانتظار
  confirmed, // مؤكد
  processing, // قيد التجهيز
  shipped, // تم الشحن
  outForDelivery, // خارج للتوصيل
  delivered, // تم التوصيل
  cancelled, // ملغي
  returned, // مرتجع
}

/// طرق الدفع
enum PaymentMethod { cod, online, bankTransfer }

/// الطلب
class Order {
  const Order({
    required this.id,
    required this.userId,
    required this.items,
    required this.total,
    this.status = OrderStatus.pending,
    this.paymentMethod = PaymentMethod.cod,
    this.shippingAddress,
    this.shippingFee = 0,
    this.discountAmount = 0,
    this.couponCode,
    this.trackingNumber,
    this.carrier,
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final List<CartItem> items;
  final double total;
  final OrderStatus status;
  final PaymentMethod paymentMethod;
  final String? shippingAddress;
  final double shippingFee;
  final double discountAmount;
  final String? couponCode;
  final String? trackingNumber;
  final String? carrier;
  final String notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// الإجمالي الفرعي (قبل الشحن والخصم)
  double get subtotal => items.fold(0, (sum, item) => sum + item.totalPrice);

  factory Order.fromMap(Map<String, dynamic> map, String id) {
    final items = (map['items'] as List?)
            ?.map((e) => CartItem.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        const <CartItem>[];

    return Order(
      id: id,
      userId: map['userId'] as String? ?? '',
      items: items,
      total: (map['total'] as num?)?.toDouble() ?? 0,
      status: _statusFromString(map['status'] as String? ?? 'pending'),
      paymentMethod:
          _paymentFromString(map['paymentMethod'] as String? ?? 'cod'),
      shippingAddress: map['shippingAddress'] as String?,
      shippingFee: (map['shippingFee'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discountAmount'] as num?)?.toDouble() ?? 0,
      couponCode: map['couponCode'] as String?,
      trackingNumber: map['trackingNumber'] as String?,
      carrier: map['carrier'] as String?,
      notes: map['notes'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.tryParse(map['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((e) => e.toMap()).toList(),
      'total': total,
      'status': status.name,
      'paymentMethod': paymentMethod.name,
      'shippingAddress': shippingAddress,
      'shippingFee': shippingFee,
      'discountAmount': discountAmount,
      'couponCode': couponCode,
      'trackingNumber': trackingNumber,
      'carrier': carrier,
      'notes': notes,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  Order copyWith({
    OrderStatus? status,
    String? trackingNumber,
    String? carrier,
    String? shippingAddress,
    DateTime? updatedAt,
  }) {
    return Order(
      id: id,
      userId: userId,
      items: items,
      total: total,
      status: status ?? this.status,
      paymentMethod: paymentMethod,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingFee: shippingFee,
      discountAmount: discountAmount,
      couponCode: couponCode,
      trackingNumber: trackingNumber ?? this.trackingNumber,
      carrier: carrier ?? this.carrier,
      notes: notes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static OrderStatus _statusFromString(String value) {
    return OrderStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OrderStatus.pending,
    );
  }

  static PaymentMethod _paymentFromString(String value) {
    return PaymentMethod.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PaymentMethod.cod,
    );
  }
}
