import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/wishlist_share_service.dart';
import '../../../../shared/widgets/favorite_aware_card.dart';
import '../../../../features/products/domain/repositories/product_repository.dart';

/// شاشة المفضلة (مزامنة سحابية عبر حساب المستخدم)
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final repository = sl<ProductRepository>();
    final all = await repository.getProducts();
    if (!mounted) return;
    setState(() {
      _products = all;
      _loading = false;
    });
  }

  Future<void> _shareWishlist() async {
    final user = AuthService.instance.currentUser;
    if (user == null || user.favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.emptyWishlistShareError)),
      );
      return;
    }
    try {
      final code = await WishlistShareService.instance.publish(user);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          text: 'شاهد قائمة أمنياتي على تطبيق ${AppConstants.appName}!\n'
              'افتح التطبيق ← المفضلة ← عرض قائمة مشتركة، وأدخل الرمز:\n'
              '$code',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.errorGeneric)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.favorites),
        actions: [
          IconButton(
            tooltip: AppStrings.sharedWishlistTitle,
            icon: const Icon(Icons.group_outlined),
            onPressed: () => context.push(AppRoutes.sharedWishlist),
          ),
          IconButton(
            tooltip: AppStrings.shareWishlist,
            icon: const Icon(Icons.ios_share),
            onPressed: _shareWishlist,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: AuthService.instance,
        builder: (context, _) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: ProductGridShimmer(),
            );
          }

          final user = AuthService.instance.currentUser;
          if (user == null) {
            return _LoginRequired(onLogin: () => context.push(AppRoutes.login));
          }

          final favoriteIds = user.favorites.toSet();
          final favorites = _products
              .where((p) => favoriteIds.contains(p.id))
              .toList();

          if (favorites.isEmpty) {
            return _EmptyFavorites(onShop: () => context.go(AppRoutes.home));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.56,
            ),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              return FavoriteAwareCard(
                product: favorites[index],
                heroTag: 'fav-${favorites[index].id}',
              );
            },
          );
        },
      ),
    );
  }
}

/// حالة غير مسجل الدخول
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
            AppStrings.favoritesLoginTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.favoritesLoginMessage,
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

/// مفضلة فارغة
class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites({required this.onShop});

  final VoidCallback onShop;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 80,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            AppStrings.emptyFavorites,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.emptyFavoritesMessage,
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
