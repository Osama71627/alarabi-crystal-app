import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/services/currency_formatter.dart';

/// شاشة تأكيد الطلب — تعرض رقم الطلب بعد إتمام الطلب بنجاح
class OrderConfirmationScreen extends StatelessWidget {
  const OrderConfirmationScreen({
    super.key,
    required this.orderId,
    required this.total,
  });

  final String orderId;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 96,
                  color: AppColors.success,
                ),
                const SizedBox(height: 24),
                Text(
                  AppStrings.orderPlaced,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppStrings.orderConfirmationMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          AppStrings.orderNumber,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          orderId,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                        const Divider(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(AppStrings.total),
                            Text(
                              CurrencyFormatter.format(total),
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text(AppStrings.continueShopping),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
