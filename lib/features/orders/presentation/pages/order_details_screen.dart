import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/models/refund_request.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/invoice_service.dart';
import '../../../../shared/services/order_service.dart';
import '../../../../shared/services/refund_service.dart';
import '../widgets/order_status_stepper.dart';

/// شاشة تفاصيل الطلب مع تتبع الحالة
class OrderDetailsScreen extends StatefulWidget {
  const OrderDetailsScreen({super.key, required this.orderId});

  final String orderId;

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  /// يفتح نافذة الطباعة الأصلية (طباعة / حفظ PDF / مشاركة) لفاتورة الطلب
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
      // بث مباشر من Firestore: أي تحديث تعمله الإدارة على حالة الطلب يظهر
      // فوراً للعميل بلا حاجة للخروج من الشاشة والرجوع إليها
      body: StreamBuilder<Order?>(
        stream: OrderService.instance.watchOrder(widget.orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data;
          if (order == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(AppStrings.noData),
                ],
              ),
            );
          }
          return _buildOrderContent(context, order);
        },
      ),
    );
  }

  Widget _buildOrderContent(BuildContext context, Order order) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // حالة الطلب
        Text(
          AppStrings.orderStatus,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        OrderStatusStepper(status: order.status),
        const SizedBox(height: 24),

        // رقم التتبع
        if (order.trackingNumber != null && order.trackingNumber!.isNotEmpty)
          Card(
            child: ListTile(
              onTap: () => context.push(
                AppRoutes.trackOrderLink(
                  trackingNumber: order.trackingNumber,
                ),
              ),
              leading: const Icon(Icons.local_shipping_outlined),
              title: Text(AppStrings.trackOrder),
              subtitle: Text('${order.carrier ?? ''} ${order.trackingNumber}'),
              trailing: const Icon(Icons.chevron_left),
            ),
          ),

        // المنتجات
        Text(
          AppStrings.itemsCount,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ...order.items.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.name),
              trailing: Text(
                '${item.quantity} × ${item.unitPrice.toStringAsFixed(0)} ر.س',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            )),

        const Divider(height: 24),

        // الإجماليات
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(AppStrings.total),
            Text(
              '${order.total.toStringAsFixed(2)} ر.س',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => _printInvoice(order),
          icon: const Icon(Icons.print_outlined),
          label: const Text(AppStrings.printInvoice),
        ),

        if (order.status == OrderStatus.delivered) ...[
          const SizedBox(height: 24),
          _RefundSection(order: order),
        ],
      ],
    );
  }
}

class _RefundSection extends StatelessWidget {
  const _RefundSection({required this.order});

  final Order order;

  Future<void> _requestRefund(BuildContext context) async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.requestRefund),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: AppStrings.refundReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text(AppStrings.requestRefund),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    try {
      await RefundService.instance.requestRefund(
        orderId: order.id,
        userId: user.uid,
        reason: reason,
        amount: order.total,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.refundRequested)),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RefundRequest>>(
      stream: RefundService.instance.watchByOrder(order.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <RefundRequest>[];
        if (requests.isEmpty) {
          return OutlinedButton.icon(
            onPressed: () => _requestRefund(context),
            icon: const Icon(Icons.assignment_return_outlined),
            label: const Text(AppStrings.requestRefund),
          );
        }
        final request = requests.first;
        final (label, color) = switch (request.status) {
          RefundStatus.pending => (AppStrings.refundPending, AppColors.warning),
          RefundStatus.approved => (AppStrings.refundApproved, AppColors.success),
          RefundStatus.rejected => (AppStrings.refundRejected, Theme.of(context).colorScheme.error),
        };
        return Card(
          child: ListTile(
            leading: Icon(Icons.assignment_return_outlined, color: color),
            title: Text(AppStrings.refundStatus),
            subtitle: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        );
      },
    );
  }
}
