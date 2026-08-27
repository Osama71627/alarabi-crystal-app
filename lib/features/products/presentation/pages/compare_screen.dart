import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/network_image_widget.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/compare_service.dart';
import '../../../../shared/services/currency_formatter.dart';

/// شاشة مقارنة المنتجات
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.compare),
        actions: [
          ListenableBuilder(
            listenable: CompareService.instance,
            builder: (context, _) {
              if (CompareService.instance.items.isEmpty) {
                return const SizedBox.shrink();
              }
              return IconButton(
                onPressed: () => CompareService.instance.clear(),
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: AppStrings.clearAll,
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: CompareService.instance,
        builder: (context, _) {
          final products = CompareService.instance.items;
          if (products.isEmpty) {
            return _EmptyCompare(
              onBrowse: () => context.push(AppRoutes.products),
            );
          }
          return _CompareTable(products: products);
        },
      ),
    );
  }
}

/// حالة فارغة مع زر تصفح
class _EmptyCompare extends StatelessWidget {
  const _EmptyCompare({required this.onBrowse});

  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.compare_arrows,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.emptyCompare,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.emptyCompareMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onBrowse,
            icon: const Icon(Icons.shopping_bag_outlined),
            label: Text(AppStrings.browseProducts),
          ),
        ],
      ),
    );
  }
}

/// جدول المقارنة
class _CompareTable extends StatelessWidget {
  const _CompareTable({required this.products});

  final List<Product> products;

  /// مفاتيح المواصفات المجمعة من كل المنتجات
  List<String> get _specKeys {
    final keys = <String>{};
    for (final product in products) {
      keys.addAll(product.specifications.keys);
    }
    return keys.toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // صف أسماء المنتجات مع الصور وزر الحذف
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _ColumnLabel(''),
              ...products.map((product) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        children: [
                          // الصورة
                          SizedBox(
                            height: 100,
                            width: double.infinity,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: product.images.isNotEmpty
                                  ? NetworkImageWidget(
                                      imageUrl: product.images.first,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      color: theme
                                          .colorScheme.surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.diamond,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            product.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            CurrencyFormatter.format(product.effectivePrice),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          IconButton(
                            onPressed: () =>
                                CompareService.instance.remove(product.id),
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: AppStrings.remove,
                            color: theme.colorScheme.error,
                          ),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),

          // صفوف المقارنة
          _buildRow(theme, 'التقييم',
              products.map((p) => '${p.rating.toStringAsFixed(1)} ★')),
          _buildRow(theme, 'السعر',
              products.map((p) => CurrencyFormatter.format(p.effectivePrice))),
          _buildRow(theme, AppStrings.availability,
              products.map((p) => p.isInStock ? AppStrings.inStock : AppStrings.outOfStock)),
          _buildRow(theme, AppStrings.brand,
              products.map((p) => p.brand.isEmpty ? '—' : p.brand)),
          _buildRow(theme, 'SKU', products.map((p) => p.sku.isEmpty ? '—' : p.sku)),
          _buildRow(theme, AppStrings.weight,
              products.map((p) => p.weight == null ? '—' : '${p.weight} kg')),

          // المواصفات
          for (final key in _specKeys)
            _buildRow(
              theme,
              key,
              products.map(
                (p) => p.specifications[key] ?? '—',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRow(ThemeData theme, String label, Iterable<String> values) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ...values.map((value) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    value,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

/// عنوان عمود ثابت العرض
class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}
