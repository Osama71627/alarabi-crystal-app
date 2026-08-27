import 'package:flutter/material.dart';

import '../../l10n/app_strings.dart';
import '../../shared/models/order.dart';

/// تسمية ولون موحّدان لحالة الطلب — مصدر واحد يُستخدم في كل الشاشات
/// (بدل تكرار نفس القوائم في شاشة الطلبات/تفاصيل الطلب/لوحة الإدارة)
extension OrderStatusX on OrderStatus {
  String get label {
    switch (this) {
      case OrderStatus.pending:
        return AppStrings.pending;
      case OrderStatus.confirmed:
        return AppStrings.confirmed;
      case OrderStatus.processing:
        return AppStrings.processing;
      case OrderStatus.shipped:
        return AppStrings.shipped;
      case OrderStatus.outForDelivery:
        return AppStrings.outForDelivery;
      case OrderStatus.delivered:
        return AppStrings.delivered;
      case OrderStatus.cancelled:
        return AppStrings.cancelled;
      case OrderStatus.returned:
        return AppStrings.returned;
    }
  }

  Color get color {
    switch (this) {
      case OrderStatus.pending:
        return const Color(0xFFF59E0B);
      case OrderStatus.confirmed:
        return const Color(0xFF3B82F6);
      case OrderStatus.processing:
        return const Color(0xFF8B5CF6);
      case OrderStatus.shipped:
        return const Color(0xFF06B6D4);
      case OrderStatus.outForDelivery:
        return const Color(0xFF6366F1);
      case OrderStatus.delivered:
        return const Color(0xFF10B981);
      case OrderStatus.cancelled:
        return const Color(0xFFEF4444);
      case OrderStatus.returned:
        return const Color(0xFF78716C);
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.pending:
        return Icons.schedule;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.processing:
        return Icons.inventory_2_outlined;
      case OrderStatus.shipped:
        return Icons.local_shipping_outlined;
      case OrderStatus.outForDelivery:
        return Icons.delivery_dining_outlined;
      case OrderStatus.delivered:
        return Icons.task_alt;
      case OrderStatus.cancelled:
        return Icons.cancel_outlined;
      case OrderStatus.returned:
        return Icons.assignment_return_outlined;
    }
  }
}

/// تسمية موحّدة لطريقة الدفع
extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cod:
        return AppStrings.cod;
      case PaymentMethod.online:
        return AppStrings.onlinePayment;
      case PaymentMethod.bankTransfer:
        return AppStrings.bankTransfer;
    }
  }
}
