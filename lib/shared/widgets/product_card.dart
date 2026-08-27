import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/product.dart';
import '../../config/routes.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/widgets/network_image_widget.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../l10n/app_strings.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';
import '../services/currency_formatter.dart';

/// بطاقة منتج للشبكة والقوائم
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.product,
    this.onFavoriteTap,
    this.isFavorite = false,
    this.onCompareTap,
    this.heroTag,
  });

  final Product product;
  final VoidCallback? onFavoriteTap;
  final bool isFavorite;
  final VoidCallback? onCompareTap;

  /// علامة Hero للتنقل المتحرك؛ تُستخدم للتفرقة بين المقاطع المتكررة
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tag = heroTag ?? 'product-${product.id}';

    return PressableScale(
      onTap: () =>
          context.push(AppRoutes.productDetailsLink(product.id, heroTag: tag)),
      child: Card(
        clipBehavior: Clip.antiAlias,
        // حدّ ذهبي فاتح حول البطاقة يفصلها بوضوح عن الخلفية البيضاء —
        // بنفس روح حدود بطاقات المنتج في موقع الشركة
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          side: BorderSide(
            color: AppColors.secondary.withValues(alpha: 0.35),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: tag,
                    child: NetworkImageWidget(
                      imageUrl: product.images.isNotEmpty
                          ? product.images.first
                          : '',
                    ),
                  ),
                  // شارة الخصم — بنفس لون ونمط شارة "تخفيض" في موقع الشركة
                  // (زيتوني ذهبي دائري الحواف)، مع نسبة الخصم الفعلية
                  if (product.hasDiscount)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondaryDark,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Text(
                          '-${product.discountPercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  // زر المفضلة
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _IconButton(
                      icon: isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                      onTap: onFavoriteTap,
                    ),
                  ),
                  // زر المقارنة
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _IconButton(
                      icon: Icons.compare_arrows,
                      color: Colors.white,
                      onTap: onCompareTap,
                    ),
                  ),
                ],
              ),
            ),
            // معلومات المنتج
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // التقييم
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        product.rating.toStringAsFixed(1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '(${product.reviewCount})',
                          style: theme.textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // السعر
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            CurrencyFormatter.format(product.effectivePrice),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          if (product.hasDiscount) ...[
                            const SizedBox(width: 6),
                            Text(
                              CurrencyFormatter.format(product.price),
                              style: theme.textTheme.bodySmall?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // التوفر
                  Text(
                    !product.isInStock
                        ? 'غير متوفر'
                        : product.isLowStock
                            ? 'كمية محدودة'
                            : 'متوفر',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: !product.isInStock
                          ? theme.colorScheme.error
                          : product.isLowStock
                              ? AppColors.secondary
                              : theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // زر إضافة سريعة للسلة — يطابق زر "أضف إلى السلة" الذهبي
                  // أسفل بطاقة المنتج في موقع الشركة arabiacrystal.com
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton(
                      onPressed: product.isInStock
                          ? () => _quickAddToCart(context)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        AppStrings.addToCart,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _quickAddToCart(BuildContext context) async {
    final item = CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      image: product.images.isNotEmpty ? product.images.first : '',
      stock: product.stock,
      discountPrice: product.discountPrice,
      categoryId: product.categoryId,
    );
    await CartService.instance.addItem(item);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.addedToCart)),
    );
  }
}

/// زر أيقونة دائري صغير
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
