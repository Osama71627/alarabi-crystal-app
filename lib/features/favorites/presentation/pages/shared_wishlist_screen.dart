import 'package:flutter/material.dart';

import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/wishlist_share_service.dart';
import '../../../../shared/widgets/favorite_aware_card.dart';
import '../../../products/domain/repositories/product_repository.dart';

/// عرض قائمة أمنيات شخص آخر عبر رمز المشاركة
class SharedWishlistScreen extends StatefulWidget {
  const SharedWishlistScreen({super.key, this.initialCode});

  /// رمز مشاركة مُمرَّر مباشرة (مثلاً من رابط) — إن وُجد يُحمَّل تلقائياً
  final String? initialCode;

  @override
  State<SharedWishlistScreen> createState() => _SharedWishlistScreenState();
}

class _SharedWishlistScreenState extends State<SharedWishlistScreen> {
  final _codeController = TextEditingController();
  bool _loading = false;
  bool _searched = false;
  SharedWishlist? _wishlist;
  List<Product> _products = const [];

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null && widget.initialCode!.trim().isNotEmpty) {
      _codeController.text = widget.initialCode!.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _searched = true;
    });
    final wishlist = await WishlistShareService.instance.fetch(code);
    List<Product> products = const [];
    if (wishlist != null) {
      final all = await sl<ProductRepository>().getProducts();
      final ids = wishlist.productIds.toSet();
      products = all.where((p) => ids.contains(p.id)).toList();
    }
    if (!mounted) return;
    setState(() {
      _wishlist = wishlist;
      _products = products;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.sharedWishlistTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      hintText: 'رمز المشاركة',
                      prefixIcon: Icon(Icons.confirmation_number_outlined),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _search,
                  child: const Text('بحث'),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody(context)),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ProductGridShimmer(),
      );
    }
    if (!_searched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'أدخل رمز المشاركة اللي أرسله لك صديقك',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
    }
    if (_wishlist == null || _products.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(AppStrings.wishlistNotFound, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_wishlist!.ownerName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'قائمة أمنيات ${_wishlist!.ownerName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) => FavoriteAwareCard(
              product: _products[index],
              heroTag: 'shared-wish-${_products[index].id}',
            ),
          ),
        ),
      ],
    );
  }
}
