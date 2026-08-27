import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../shared/services/order_service.dart';

/// شاشة سجل الطلبات (مزامنة سحابية)
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.myOrders),
        actions: [
          IconButton(
            tooltip: AppStrings.trackOrder,
            icon: const Icon(Icons.local_shipping_outlined),
            onPressed: () => context.push(AppRoutes.trackOrderLink()),
          ),
        ],
      ),
      body: user == null
          ? _LoginRequired(onLogin: () => context.push(AppRoutes.login))
          : StreamBuilder<List<Order>>(
              stream: OrderService.instance.watchOrders(user.uid),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text(AppStrings.errorGeneric));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final orders = snapshot.data ?? const <Order>[];
                if (orders.isEmpty) {
                  return const _EmptyOrders();
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    return _OrderCard(order: orders[index]);
                  },
                );
              },
            ),
    );
  }
}

/// غير مسجل الدخول
class _LoginRequired extends StatelessWidget {
  const _LoginRequired({required this.onLogin});

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.ordersLoginTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.ordersLoginMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onLogin,
            child: Text(AppStrings.login),
          ),
        ],
      ),
    );
  }
}

/// لا توجد طلبات
class _EmptyOrders extends StatelessWidget {
  const _EmptyOrders();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.emptyOrders,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.emptyOrdersMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final idLabel = order.id.length > 8
        ? order.id.substring(0, 8)
        : order.id;
    return Card(
      child: ListTile(
        onTap: () => context.push(AppRoutes.orderDetailsLink(order.id)),
        title: Text(
          '${AppStrings.orderNumber}: $idLabel',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${order.items.length} ${AppStrings.itemsCount}',
            ),
            Text(
              CurrencyFormatter.format(order.total),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
      ),
    );
  }
}
