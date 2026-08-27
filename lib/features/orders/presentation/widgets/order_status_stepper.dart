import 'package:flutter/material.dart';

import '../../../../core/widgets/order_status_x.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/order.dart';

/// خط تتبع حالة الطلب
class OrderStatusStepper extends StatelessWidget {
  const OrderStatusStepper({super.key, required this.status});

  final OrderStatus status;

  static const _allStatuses = [
    OrderStatus.pending,
    OrderStatus.confirmed,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.outForDelivery,
    OrderStatus.delivered,
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = _allStatuses.indexOf(status);

    if (status == OrderStatus.cancelled) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined),
              const SizedBox(width: 12),
              Text(
                AppStrings.cancelled,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      children: List.generate(_allStatuses.length, (index) {
        final isDone = index <= currentIndex;
        final isLast = index == _allStatuses.length - 1;

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: isDone
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        color: isDone
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _allStatuses[index].label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                  color: isDone
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
