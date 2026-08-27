import 'package:flutter/material.dart';

import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/services/order_service.dart';
import '../widgets/order_status_stepper.dart';

/// شاشة تتبع الطلب برقم التتبع (متاحة للضيوف أيضاً)
class TrackOrderScreen extends StatefulWidget {
  const TrackOrderScreen({super.key, this.trackingNumber, this.trackLookup});

  /// رقم تتبع مُعبّأ مسبقاً
  final String? trackingNumber;

  /// دالة البحث - تُحقن في الاختبارات فقط
  final Future<Order?> Function(String trackingNumber)? trackLookup;

  @override
  State<TrackOrderScreen> createState() => _TrackOrderScreenState();
}

class _TrackOrderScreenState extends State<TrackOrderScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  Order? _order;
  bool _notFound = false;

  @override
  void initState() {
    super.initState();
    if (widget.trackingNumber != null && widget.trackingNumber!.isNotEmpty) {
      _controller.text = widget.trackingNumber!;
      _track();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _track() async {
    final number = _controller.text.trim();
    if (number.isEmpty) return;
    setState(() {
      _loading = true;
      _order = null;
      _notFound = false;
    });
    final lookup =
        widget.trackLookup ?? OrderService.instance.getOrderByTrackingNumber;
    final order = await lookup(number);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _order = order;
      _notFound = order == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.trackOrder)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // حقل إدخال رقم التتبع
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _track(),
            decoration: InputDecoration(
              hintText: AppStrings.trackingNumberHint,
              prefixIcon: const Icon(Icons.pin_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _loading ? null : _track,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.search),
            label: Text(AppStrings.trackNow),
          ),
          const SizedBox(height: 24),

          // نتيجة البحث
          if (_notFound)
            _TrackingResult(
              icon: Icons.search_off,
              title: AppStrings.trackingNotFound,
              message: AppStrings.trackingNotFoundMessage,
            )
          else if (_order != null)
            _buildOrderContent(context, _order!)
          else if (!_loading)
            _TrackingResult(
              icon: Icons.local_shipping_outlined,
              title: AppStrings.trackingIntroTitle,
              message: AppStrings.trackingIntroMessage,
            ),
        ],
      ),
    );
  }

  Widget _buildOrderContent(BuildContext context, Order order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // حالة الشحنة
        Text(
          AppStrings.orderStatus,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        OrderStatusStepper(status: order.status),
        const SizedBox(height: 24),

        // رقم التتبع وشركة الشحن
        Card(
          child: ListTile(
            leading: const Icon(Icons.local_shipping_outlined),
            title: Text(AppStrings.trackingNumberLabel),
            subtitle: Text(order.trackingNumber ?? ''),
            trailing: order.carrier != null && order.carrier!.isNotEmpty
                ? Chip(
                    label: Text(order.carrier!),
                    labelStyle: const TextStyle(fontSize: 12),
                  )
                : null,
          ),
        ),
        const SizedBox(height: 16),

        // تاريخ الطلب
        if (order.createdAt != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(AppStrings.orderDate),
            subtitle: Text(
              '${order.createdAt!.day}/${order.createdAt!.month}/${order.createdAt!.year}',
            ),
          ),

        const Divider(height: 24),

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

        // الإجمالي
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
      ],
    );
  }
}

/// حالة إرشادية أو نتيجة غير موجودة
class _TrackingResult extends StatelessWidget {
  const _TrackingResult({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Icon(
              icon,
              size: 72,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
