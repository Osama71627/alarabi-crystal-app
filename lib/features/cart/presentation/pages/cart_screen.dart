import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/network_image_widget.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/cart_item.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/cart_service.dart';
import '../../../../shared/services/coupon_service.dart';
import '../../../../shared/services/currency_formatter.dart';

/// شاشة السلة
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final CartService _cartService = CartService.instance;
  final TextEditingController _couponController = TextEditingController();
  bool _applyingCoupon = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _applyingCoupon = true);
    final cartItems = _cartService.items;
    try {
      final coupon = await CouponService.instance.validate(
        code,
        subtotal: _cartService.subtotal,
        productIds: cartItems.map((item) => item.productId).toList(),
        userId: AuthService.instance.currentUser?.uid,
      );
      _cartService.applyCoupon(coupon);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.couponApplied)),
      );
    } on CouponException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.invalidCoupon)),
      );
    } finally {
      if (mounted) setState(() => _applyingCoupon = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.myCart)),
      body: StreamBuilder<List<CartItem>>(
        stream: _cartService.itemsStream,
        initialData: _cartService.items,
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return _EmptyCart(onShop: () => context.go(AppRoutes.home));
          }
          return _buildCartContent(context, items);
        },
      ),
    );
  }

  Widget _buildCartContent(BuildContext context, List<CartItem> items) {
    final subtotal = _cartService.subtotal;
    final discount = _cartService.couponDiscount;
    final freeShipping = _cartService.freeShippingApplied;
    final shippingFee = subtotal >= 500 || freeShipping ? 0.0 : 25.0;
    final total = subtotal - discount + shippingFee;

    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CouponField(
                  controller: _couponController,
                  appliedCoupon: _cartService.appliedCouponCode,
                  applying: _applyingCoupon,
                  onApply: _applyCoupon,
                  onRemove: () => _cartService.clearCoupon(),
                );
              }
              final item = items[index - 1];
              return _CartItemTile(
                item: item,
                onRemove: () => _cartService.removeItem(item.productId),
                onQuantityChange: (q) =>
                    _cartService.updateQuantity(item.productId, q),
              );
            },
          ),
        ),
        // ملخص الإجمالي
        _OrderSummary(
          subtotal: subtotal,
          discount: discount,
          shippingFee: shippingFee,
          total: total,
          onCheckout: () => context.push(AppRoutes.checkout),
        ),
      ],
    );
  }
}

/// سلة فارغة
class _EmptyCart extends StatelessWidget {
  const _EmptyCart({required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.emptyCart,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.emptyCartMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onShop,
            child: Text(AppStrings.continueShopping),
          ),
        ],
      ),
    );
  }
}

/// حقل الكوبون
class _CouponField extends StatelessWidget {
  const _CouponField({
    required this.controller,
    required this.appliedCoupon,
    required this.onApply,
    required this.onRemove,
    this.applying = false,
  });

  final TextEditingController controller;
  final String? appliedCoupon;
  final VoidCallback onApply;
  final VoidCallback onRemove;
  final bool applying;

  @override
  Widget build(BuildContext context) {
    if (appliedCoupon != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 8),
            Text(
              appliedCoupon!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      );
    }

    return TextField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        hintText: AppStrings.couponCode,
        prefixIcon: const Icon(Icons.confirmation_number_outlined),
        suffixIcon: TextButton(
          onPressed: applying ? null : onApply,
          child: applying
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppStrings.applyCoupon),
        ),
      ),
    );
  }
}

/// عنصر السلة
class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.onRemove,
    required this.onQuantityChange,
  });

  final CartItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChange;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // الصورة
            SizedBox(
              width: 80,
              height: 80,
              child: item.image.isNotEmpty
                  ? NetworkImageWidget(imageUrl: item.image)
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.diamond, color: AppColors.secondary),
                    ),
            ),
            const SizedBox(width: 12),
            // المعلومات
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        CurrencyFormatter.format(item.unitPrice),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      if (item.discountPrice != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          CurrencyFormatter.format(item.price),
                          style: theme.textTheme.bodySmall?.copyWith(
                            decoration: TextDecoration.lineThrough,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // الكمية
                      _QuantityStepper(
                        quantity: item.quantity,
                        onIncrement: () =>
                            onQuantityChange(item.quantity + 1),
                        onDecrement: () =>
                            onQuantityChange(item.quantity - 1),
                      ),
                      IconButton(
                        onPressed: onRemove,
                        icon: const Icon(Icons.delete_outline),
                        color: theme.colorScheme.error,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove,
            onTap: quantity > 1 ? onDecrement : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$quantity',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          _StepButton(icon: Icons.add, onTap: onIncrement),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? Theme.of(context).colorScheme.outline
              : AppColors.secondary,
        ),
      ),
    );
  }
}

/// ملخص الطلب
class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.subtotal,
    required this.discount,
    required this.shippingFee,
    required this.total,
    required this.onCheckout,
  });

  final double subtotal;
  final double discount;
  final double shippingFee;
  final double total;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SummaryRow(label: AppStrings.subtotal, value: subtotal),
            const SizedBox(height: 6),
            if (discount > 0)
              _SummaryRow(
                label: '${AppStrings.discount} (${AppStrings.applyCoupon})',
                value: -discount,
                valueColor: AppColors.success,
              ),
            const SizedBox(height: 6),
            _SummaryRow(label: AppStrings.shipping, value: shippingFee),
            const Divider(height: 20),
            _SummaryRow(
              label: AppStrings.total,
              value: total,
              isTotal: true,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onCheckout,
              child: Text(
                '${AppStrings.checkout} • ${CurrencyFormatter.format(total)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
    this.valueColor,
  });

  final String label;
  final double value;
  final bool isTotal;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = isTotal
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          CurrencyFormatter.format(value),
          style: style?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
