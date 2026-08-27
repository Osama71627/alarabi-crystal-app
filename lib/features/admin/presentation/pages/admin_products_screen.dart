import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/network_image_widget.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/csv_product_service.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../widgets/admin_widgets.dart';
import 'product_form_screen.dart';

/// إدارة المنتجات: قائمة + بحث + إضافة/تعديل/حذف + CSV
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  ProductRepository get _repository => sl<ProductRepository>();

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل تريد حذف "${product.name}" نهائياً؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.deleteProduct(product.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.productDeleted)),
    );
  }

  Future<void> _exportCsv(List<Product> products) async {
    final csv = CsvProductService.export(products);
    final bytes = Uint8List.fromList(csv.codeUnits);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            bytes,
            name: 'products.csv',
            mimeType: 'text/csv',
          ),
        ],
        text: 'Al Arabi Crystal - Products',
      ),
    );
  }

  Future<void> _importCsv() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.importCsv),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'id,name,description,price,...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text(AppStrings.importCsv),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    try {
      final products = CsvProductService.parse(text);
      for (final product in products) {
        await _repository.addProduct(product);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${products.length} ${AppStrings.imported}')),
      );
    } on CsvImportException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Product>>(
      stream: _repository.watchProducts(),
      builder: (context, snapshot) {
        final products = snapshot.data ?? const <Product>[];
        final filtered = _query.isEmpty
            ? products
            : products.where((p) {
                final q = _query.toLowerCase();
                return p.name.toLowerCase().contains(q) ||
                    p.sku.toLowerCase().contains(q) ||
                    p.brand.toLowerCase().contains(q);
              }).toList();

        final lowStockCount = products.where((p) => p.isLowStock).length;

        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.inventory_2_outlined,
              title: AppStrings.adminProducts,
              subtitle: '${products.length} منتج'
                  '${lowStockCount > 0 ? ' • $lowStockCount بمخزون منخفض' : ''}',
              actions: [
                IconButton.filledTonal(
                  tooltip: AppStrings.importCsv,
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  onPressed: _importCsv,
                ),
                IconButton.filledTonal(
                  tooltip: AppStrings.exportCsv,
                  icon: const Icon(Icons.upload_file_outlined, size: 20),
                  onPressed: products.isEmpty ? null : () => _exportCsv(products),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductFormScreen(),
                      ),
                    );
                    if (created == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.productAdded)),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(AppStrings.addProduct),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: AppStrings.searchProducts,
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? AdminEmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: AppStrings.noProducts,
                          subtitle: _query.isEmpty
                              ? null
                              : 'لا نتائج مطابقة لـ "$_query"',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: filtered.length,
                          itemBuilder: (context, i) {
                            final product = filtered[i];
                            return _ProductTile(
                              product: product,
                              onEdit: () async {
                                await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProductFormScreen(
                                      product: product,
                                    ),
                                  ),
                                );
                              },
                              onDelete: () => _delete(product),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final Product product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final image = product.images.isNotEmpty ? product.images.first : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 52,
                height: 52,
                child: NetworkImageWidget(imageUrl: image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        '${product.price.toStringAsFixed(0)} ر.س',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      _stockPill(context),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: AppStrings.edit,
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: AppStrings.delete,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: Theme.of(context).colorScheme.error,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  Widget _stockPill(BuildContext context) {
    if (product.stock <= 0) {
      return StatusPill(
        label: 'نفد المخزون',
        color: Theme.of(context).colorScheme.error,
        dense: true,
      );
    }
    if (product.isLowStock) {
      return StatusPill(
        label: '${AppStrings.lowStock} • ${product.stock}',
        color: AppColors.warning,
        dense: true,
      );
    }
    return StatusPill(
      label: '${AppStrings.inStock} • ${product.stock}',
      color: AppColors.success,
      dense: true,
    );
  }
}
