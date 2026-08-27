import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/routes.dart';
import '../../l10n/app_strings.dart';
import '../models/product.dart';
import '../services/auth_service.dart';
import '../services/compare_service.dart';
import 'product_card.dart';

/// بطاقة منتج مدركة لحالة المفضلة السحابية والمقارنة
class FavoriteAwareCard extends StatelessWidget {
  const FavoriteAwareCard({
    super.key,
    required this.product,
    this.heroTag,
  });

  final Product product;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([auth, CompareService.instance]),
      builder: (context, _) {
        final isFavorite =
            auth.currentUser?.favorites.contains(product.id) ?? false;
        return ProductCard(
          product: product,
          heroTag: heroTag,
          isFavorite: isFavorite,
          onFavoriteTap: () => _toggleFavorite(context, auth, isFavorite),
          onCompareTap: () => _toggleCompare(context),
        );
      },
    );
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    AuthService auth,
    bool isFavorite,
  ) async {
    if (!auth.isLoggedIn) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.loginRequired)),
        );
        context.push(AppRoutes.login);
      }
      return;
    }
    try {
      await auth.toggleFavorite(product.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.errorGeneric)),
        );
      }
    }
  }

  void _toggleCompare(BuildContext context) async {
    final result = await CompareService.instance.toggle(product);
    if (!context.mounted) return;
    final message = switch (result) {
      CompareToggleResult.added => AppStrings.compareAdded,
      CompareToggleResult.removed => AppStrings.compareRemoved,
      CompareToggleResult.limitReached => AppStrings.compareLimit,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: result == CompareToggleResult.limitReached
            ? null
            : SnackBarAction(
                label: AppStrings.compare,
                onPressed: () => context.push(AppRoutes.compare),
              ),
      ),
    );
  }
}
