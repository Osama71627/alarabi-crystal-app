import 'package:flutter/material.dart';

import '../../../../core/widgets/order_status_x.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../domain/repositories/admin_repository.dart';
import '../widgets/admin_widgets.dart';
import 'admin_order_details_screen.dart';

/// إدارة الطلبات: قائمة مع فلترة بالحالة
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  OrderStatus? _filter;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Order>>(
      stream: sl<AdminRepository>().watchAllOrders(),
      builder: (context, snapshot) {
        final allOrders = snapshot.data ?? const <Order>[];
        var orders = allOrders;
        if (_filter != null) {
          orders = orders.where((o) => o.status == _filter).toList();
        }
        final pendingCount =
            allOrders.where((o) => o.status == OrderStatus.pending).length;

        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.receipt_long_outlined,
              title: AppStrings.adminOrders,
              subtitle: '${allOrders.length} طلب'
                  '${pendingCount > 0 ? ' • $pendingCount قيد الانتظار' : ''}',
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip(context, null, AppStrings.all),
                  for (final status in OrderStatus.values)
                    _chip(context, status, status.label),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : snapshot.hasError
                      ? Center(child: Text(AppStrings.errorGeneric))
                      : orders.isEmpty
                          ? AdminEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: AppStrings.noData,
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: orders.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, i) {
                                final order = orders[i];
                                return _OrderCard(
                                  order: order,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AdminOrderDetailsScreen(
                                        orderId: order.id,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(BuildContext context, OrderStatus? status, String label) {
    final selected = _filter == status;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = status),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final created = order.createdAt;
    final date = created != null
        ? '${created.day}/${created.month}/${created.year}'
        : '';
    final color = order.status.color;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  order.items.length.toString(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'طلب #${order.id.substring(0, order.id.length > 8 ? 8 : order.id.length)}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatClean(order.total),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  StatusPill(
                    label: order.status.label,
                    color: color,
                    icon: order.status.icon,
                    dense: true,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
