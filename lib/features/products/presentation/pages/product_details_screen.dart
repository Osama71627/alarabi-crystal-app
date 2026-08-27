import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/network_image_widget.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/cart_item.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/models/review.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/cart_service.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../shared/services/storage_service.dart';
import '../../../../config/routes.dart';
import '../../domain/repositories/product_repository.dart';
import '../../domain/repositories/review_repository.dart';

/// شاشة تفاصيل المنتج
class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId, this.heroTag});

  final String productId;

  /// علامة Hero الواردة من بطاقة المنتج المصدر
  final String? heroTag;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final ProductRepository _repository = sl<ProductRepository>();
  Product? _product;
  bool _loading = true;
  int _selectedImage = 0;
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    final product = await _repository.getProductById(widget.productId);
    setState(() {
      _product = product;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_product == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64),
              const SizedBox(height: 12),
              Text(AppStrings.errorGeneric),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProduct,
                child: Text(AppStrings.retry),
              ),
            ],
          ),
        ),
      );
    }

    final product = _product!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // الشريط العلوي
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                tooltip: AppStrings.shareProduct,
                onPressed: () => _shareProduct(product),
              ),
              ListenableBuilder(
                listenable: AuthService.instance,
                builder: (context, _) {
                  final isFavorite = AuthService
                          .instance.currentUser?.favorites
                          .contains(product.id) ??
                      false;
                  return IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : null,
                    ),
                    onPressed: () => _toggleFavorite(product),
                  );
                },
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ImageGallery(
                product: product,
                selectedIndex: _selectedImage,
                heroTag: widget.heroTag,
                onSelect: (index) => setState(() => _selectedImage = index),
              ),
            ),
          ),
          // معلومات المنتج
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPriceSection(product),
                  const SizedBox(height: 12),
                  Text(
                    product.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildRatingRow(product),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  // اختيار الكمية
                  Row(
                    children: [
                      Text(
                        AppStrings.quantity,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      _QuantitySelector(
                        quantity: _quantity,
                        maxQuantity: product.stock,
                        onChange: (value) => setState(() => _quantity = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // الوصف
                  _buildSection(
                    context,
                    title: AppStrings.description,
                    child: Text(
                      product.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // المواصفات
                  _buildSection(
                    context,
                    title: AppStrings.specifications,
                    child: Column(
                      children: product.specifications.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 120,
                                child: Text(
                                  entry.key,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondary,
                                      ),
                                ),
                              ),
                              Expanded(
                                child: Text(entry.value),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _ReviewsSection(product: product),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      // شريط الإجراءات السفلية
      bottomNavigationBar: _BottomActions(
        product: product,
        quantity: _quantity,
        onAddToCart: _addToCart,
        onBuyNow: _buyNow,
      ),
    );
  }

  /// مشاركة المنتج عبر تطبيقات الجهاز
  Future<void> _shareProduct(Product product) async {
    final price = CurrencyFormatter.format(product.effectivePrice);
    final text = '${product.name}\n'
        '$price\n'
        '${product.brand.isNotEmpty ? '${product.brand} • ' : ''}'
        '${product.description.length > 140 ? '${product.description.substring(0, 140)}...' : product.description}\n'
        '— من تطبيق ${AppConstants.appName}';
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.shareFailed)),
        );
      }
    }
  }

  Future<void> _toggleFavorite(Product product) async {    final auth = AuthService.instance;
    if (!auth.isLoggedIn) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.loginRequired)),
        );
        context.push(AppRoutes.login);
      }
      return;
    }
    try {
      await auth.toggleFavorite(product.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    }
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null) return;
    final item = CartItem(
      productId: product.id,
      name: product.name,
      price: product.price,
      image: product.images.isNotEmpty ? product.images.first : '',
      quantity: _quantity,
      stock: product.stock,
      discountPrice: product.discountPrice,
      categoryId: product.categoryId,
    );
    await CartService.instance.addItem(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.addedToCart)),
    );
  }

  Future<void> _buyNow() async {
    await _addToCart();
    if (mounted) context.push(AppRoutes.cart);
  }

  Widget _buildPriceSection(Product product) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          CurrencyFormatter.format(product.effectivePrice),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        if (product.hasDiscount)
          Text(
            CurrencyFormatter.format(product.price),
            style: theme.textTheme.titleMedium?.copyWith(
              decoration: TextDecoration.lineThrough,
              color: theme.colorScheme.outline,
            ),
          ),
        const Spacer(),
        if (product.hasDiscount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.error,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '-${product.discountPercentage.toStringAsFixed(0)}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRatingRow(Product product) {
    final theme = Theme.of(context);
    return Row(
      children: [
        ...List.generate(5, (index) {
          return Icon(
            index < product.rating.round() ? Icons.star : Icons.star_border,
            size: 18,
            color: AppColors.secondary,
          );
        }),
        const SizedBox(width: 8),
        Text(
          '${product.rating.toStringAsFixed(1)} (${product.reviewCount} ${AppStrings.reviews})',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(width: 12),
        Text(
          product.isInStock ? AppStrings.inStock : AppStrings.outOfStock,
          style: theme.textTheme.bodySmall?.copyWith(
            color: product.isInStock
                ? AppColors.success
                : theme.colorScheme.error,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// معرض الصور
class _ImageGallery extends StatelessWidget {
  const _ImageGallery({
    required this.product,
    required this.selectedIndex,
    required this.onSelect,
    this.heroTag,
  });

  final Product product;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// علامة Hero للتنقل المتحرك
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final images = product.images;

    if (images.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: Icon(Icons.diamond, size: 80, color: AppColors.secondary),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Hero(
          tag: heroTag ?? 'product-${product.id}',
          child: NetworkImageWidget(
            imageUrl: images[selectedIndex],
            fit: BoxFit.contain,
          ),
        ),
        // صور مصغرة
        if (images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (index) {
                return GestureDetector(
                  onTap: () => onSelect(index),
                  child: Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index == selectedIndex
                          ? AppColors.secondary
                          : Colors.white54,
                    ),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

/// اختيار الكمية
class _QuantitySelector extends StatelessWidget {
  const _QuantitySelector({
    required this.quantity,
    required this.maxQuantity,
    required this.onChange,
  });

  final int quantity;
  final int maxQuantity;
  final ValueChanged<int> onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: quantity > 1 ? () => onChange(quantity - 1) : null,
            icon: const Icon(Icons.remove, size: 18),
            color: AppColors.secondary,
          ),
          Text(
            '$quantity',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          IconButton(
            onPressed: quantity < maxQuantity
                ? () => onChange(quantity + 1)
                : null,
            icon: const Icon(Icons.add, size: 18),
            color: AppColors.secondary,
          ),
        ],
      ),
    );
  }
}

/// شريط الإجراءات السفلية
class _BottomActions extends StatelessWidget {
  const _BottomActions({
    required this.product,
    required this.quantity,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  final Product product;
  final int quantity;
  final VoidCallback onAddToCart;
  final VoidCallback onBuyNow;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // زر السلة
            Expanded(
              child: OutlinedButton(
                onPressed: onAddToCart,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_cart_outlined, size: 20),
                    SizedBox(width: 8),
                    Text(AppStrings.addToCart),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            // زر الشراء
            Expanded(
              child: ElevatedButton(
                onPressed: onBuyNow,
                child: Text(
                  CurrencyFormatter.format(product.effectivePrice * quantity),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// قسم التقييمات: عرض التقييمات الحالية + زر إضافة تقييم جديد
class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({required this.product});

  final Product product;

  void _openReviewForm(BuildContext context) {
    final auth = AuthService.instance;
    if (!auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.loginRequired)),
      );
      context.push(AppRoutes.login);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReviewFormSheet(productId: product.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                AppStrings.reviews,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => _openReviewForm(context),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(AppStrings.writeReview),
            ),
          ],
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Review>>(
          stream: sl<ReviewRepository>().watchReviews(product.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final reviews = snapshot.data ?? const <Review>[];
            if (reviews.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  AppStrings.noReviewsYet,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              );
            }
            return Column(
              children: [for (final review in reviews) _ReviewTile(review: review)],
            );
          },
        ),
      ],
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                  child: Text(
                    review.userName.isNotEmpty
                        ? review.userName.substring(0, 1).toUpperCase()
                        : '؟',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.userName.isEmpty ? AppStrings.guest : review.userName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < review.rating.round()
                                ? Icons.star
                                : Icons.star_border,
                            size: 14,
                            color: AppColors.secondary,
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(review.comment),
            ],
            if (review.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: review.images.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: NetworkImageWidget(imageUrl: review.images[index]),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// نموذج إضافة تقييم جديد (تقييم نجمي + تعليق + صور اختيارية)
class _ReviewFormSheet extends StatefulWidget {
  const _ReviewFormSheet({required this.productId});

  final String productId;

  @override
  State<_ReviewFormSheet> createState() => _ReviewFormSheetState();
}

class _ReviewFormSheetState extends State<_ReviewFormSheet> {
  final _commentController = TextEditingController();
  double _rating = 0;
  final List<Uint8List> _pickedImages = [];
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(limit: 3);
    if (files.isEmpty) return;
    final bytesList = await Future.wait(files.map((f) => f.readAsBytes()));
    if (!mounted) return;
    setState(() {
      _pickedImages.addAll(bytesList);
      if (_pickedImages.length > 3) {
        _pickedImages.removeRange(3, _pickedImages.length);
      }
    });
  }

  Future<void> _submit() async {
    if (_rating <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.selectRatingFirst)),
      );
      return;
    }
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    setState(() => _submitting = true);
    try {
      final imageUrls = <String>[];
      for (final bytes in _pickedImages) {
        final result = await StorageService.instance.uploadReviewImage(
          productId: widget.productId,
          bytes: bytes,
        );
        imageUrls.add(result.url);
      }
      final review = Review(
        id: 'rv-${DateTime.now().millisecondsSinceEpoch}',
        userId: user.uid,
        productId: widget.productId,
        rating: _rating,
        comment: _commentController.text.trim(),
        userName: user.name,
        userAvatar: user.avatar,
        images: imageUrls,
        createdAt: DateTime.now(),
      );
      await sl<ReviewRepository>().addReview(review);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.reviewSubmitted)),
      );
    } on ReviewException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            AppStrings.writeReview,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = starIndex.toDouble()),
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: AppColors.secondary,
                    size: 32,
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(hintText: AppStrings.reviewCommentHint),
          ),
          const SizedBox(height: 12),
          if (_pickedImages.isNotEmpty) ...[
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _pickedImages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (context, index) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _pickedImages[index],
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: _pickedImages.length >= 3 ? null : _pickImages,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: Text(AppStrings.addPhotos),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(AppStrings.submitReview),
          ),
        ],
      ),
    );
  }
}
