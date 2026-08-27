import 'package:flutter/material.dart';

/// حالة تحميل مع Shimmer Effect
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.shape = BoxShape.rectangle,
    this.borderRadius = 12,
    this.margin,
  });

  final double width;
  final double height;
  final BoxShape shape;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? BorderRadius.circular(borderRadius)
            : null,
      ),
    );
  }
}

/// شبكة تحميل للمنتجات
class ProductGridShimmer extends StatelessWidget {
  const ProductGridShimmer({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // يطابق نسبة ProductCard الفعلية بعد إضافة زر "أضف إلى السلة"
        childAspectRatio: 0.56,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Expanded(
              child: ShimmerLoading(width: double.infinity, height: double.infinity),
            ),
            SizedBox(height: 8),
            ShimmerLoading(width: 140, height: 16),
            SizedBox(height: 6),
            ShimmerLoading(width: 90, height: 14),
          ],
        );
      },
    );
  }
}
