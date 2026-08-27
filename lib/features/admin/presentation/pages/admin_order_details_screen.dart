import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/widgets/network_image_widget.dart';
import '../../../../core/widgets/order_status_x.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../shared/services/invoice_service.dart';
import '../../../../shared/services/loyalty_service.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/services/push_trigger_service.dart';
import '../../../orders/presentation/widgets/order_status_stepper.dart';
import '../widgets/admin_widgets.dart';

/// تفاصيل الطلب للإدارة: تحديث الحالة + رقم التتبع + الفاتورة
class AdminOrderDetailsScreen extends StatefulWidget {
  const AdminOrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  late Future<Order?> _future;
  late final TextEditingController _tracking;
  late final TextEditingController _carrier;
  OrderStatus? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _future = OrderService.instance.getOrder(widget.orderId);
    _tracking = TextEditingController();
    _carrier = TextEditingController();
  }

  @override
  void dispose() {
    _tracking.dispose();
    _carrier.dispose();
    super.dispose();
  }

  Future<void> _save(Order order) async {
    final newStatus = _selectedStatus;
    final statusChanged = newStatus != null && newStatus != order.status;

    await OrderService.instance.updateOrder(
      order.id,
      status: newStatus,
      trackingNumber: _tracking.text,
      carrier: _carrier.text,
    );

    // منح نقاط الولاء عند التسليم (لا توجد Cloud Functions على الخطة
    // المجانية، فتُمنح من هنا — والدالة آمنة للتكرار)
    if (statusChanged &&
        newStatus == OrderStatus.delivered &&
        order.userId.isNotEmpty) {
      try {
        await LoyaltyService.instance.awardPointsForDeliveredOrder(
          orderId: order.id,
          userId: order.userId,
          orderTotal: order.total,
        );
      } catch (_) {
        // فشل منح النقاط لا يجب أن يمنع تحديث حالة الطلب
      }
    }

    // إشعار صاحب الطلب وحده بتغيّر الحالة (يصل حتى لو تطبيقه مغلق) —
    // يُرسل فقط عند تغيّر الحالة فعلاً، لا عند حفظ رقم التتبع مثلاً
    if (statusChanged && order.userId.isNotEmpty) {
      unawaited(PushTriggerService.instance.notify(
        title: AppStrings.orderStatusNotifTitle,
        body: AppStrings.orderStatusNotifBody
            .replaceFirst('{status}', newStatus.label),
        type: 'order',
        linkId: order.id,
        userId: order.userId,
      ));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.orderUpdated)),
      );
      setState(() {
        _future = OrderService.instance.getOrder(widget.orderId);
      });
    }
  }

  /// يفتح نافذة الطباعة الأصلية للنظام (طباعة فعلية أو حفظ كـ PDF أو مشاركة)
  Future<void> _printInvoice(Order order) async {
    try {
      await InvoiceService.instance.printInvoice(order);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.orderDetails)),
      body: FutureBuilder<Order?>(
        future: _future,
        builder: (context, snapshot) {
          final order = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (order == null) {
            return Center(child: Text(AppStrings.noData));
          }
          _tracking.text = order.trackingNumber ?? '';
          _carrier.text = order.carrier ?? '';
          _selectedStatus ??= order.status;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text(
                    '#${order.id.substring(0, order.id.length > 10 ? 10 : order.id.length)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const Spacer(),
                  StatusPill(
                    label: order.status.label,
                    color: order.status.color,
                    icon: order.status.icon,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              OrderStatusStepper(status: order.status),
              const SizedBox(height: 24),
              AdminSectionCard(
                title: AppStrings.updateOrderStatus,
                icon: Icons.edit_note,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<OrderStatus>(
                      initialValue: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: AppStrings.status,
                      ),
                      items: [
                        for (final status in OrderStatus.values)
                          DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedStatus = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _tracking,
                      decoration: const InputDecoration(
                        labelText: AppStrings.trackingNumber,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _carrier,
                      decoration: const InputDecoration(
                        labelText: AppStrings.carrier,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _save(order),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text(AppStrings.saveChanges),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AdminSectionCard(
                title: AppStrings.orderDetails,
                icon: Icons.receipt_long_outlined,
                child: Column(
                  children: [
                    _row(context, AppStrings.orderNumber, '#${order.id}'),
                    _row(
                      context,
                      AppStrings.paymentMethod,
                      order.paymentMethod.label,
                    ),
                    if (order.shippingAddress != null)
                      _row(
                        context,
                        AppStrings.shippingAddress,
                        order.shippingAddress!,
                      ),
                    if (order.couponCode != null)
                      _row(
                        context,
                        AppStrings.coupon,
                        order.couponCode!,
                      ),
                    const Divider(height: 20),
                    for (final item in order.items) _itemRow(context, item),
                    const Divider(height: 20),
                    _row(
                      context,
                      AppStrings.subtotal,
                      CurrencyFormatter.formatClean(order.subtotal),
                    ),
                    _row(
                      context,
                      AppStrings.shippingFee,
                      CurrencyFormatter.formatClean(order.shippingFee),
                    ),
                    if (order.discountAmount > 0)
                      _row(
                        context,
                        AppStrings.discount,
                        '-${CurrencyFormatter.formatClean(order.discountAmount)}',
                      ),
                    const Divider(height: 16),
                    _row(
                      context,
                      AppStrings.total,
                      CurrencyFormatter.formatClean(order.total),
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => _printInvoice(order),
                icon: const Icon(Icons.print_outlined),
                label: const Text(AppStrings.printInvoice),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _itemRow(BuildContext context, dynamic item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 40,
              height: 40,
              child: NetworkImageWidget(imageUrl: item.image),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${item.quantity} × ${item.unitPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyFormatter.formatClean(item.totalPrice),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  /// صف "عنوان: قيمة" — القيمة داخل [Expanded] لأن بعض القيم طويلة جداً
  /// (رقم الطلب الكامل، عنوان الشحن) وكانت تتجاوز عرض الشاشة وتُظهر شريط
  /// تحذير الفيضان الأسود/الأصفر
  Widget _row(BuildContext context, String label, String value,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                fontSize: bold ? 16 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

}
