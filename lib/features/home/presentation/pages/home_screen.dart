import 'package:flutter/material.dart' hide Banner;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/pressable_scale.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/banner.dart';
import '../../../../shared/models/offer.dart';
import '../../../../shared/models/product.dart';
import '../../../../shared/widgets/favorite_aware_card.dart';
import '../../../../config/routes.dart';
import '../../../../injection.dart';
import '../../../offers/domain/repositories/offer_repository.dart';
import '../../../offers/presentation/bloc/offer_bloc.dart';
import '../../../offers/presentation/widgets/flash_countdown.dart';
import '../../../offers/presentation/widgets/offers_marquee.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../products/presentation/bloc/product_bloc.dart';
import '../../../notifications/presentation/widgets/notification_bell.dart';

/// الشاشة الرئيسية
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProductBloc(repository: sl<ProductRepository>())
            ..add(const LoadProducts()),
        ),
        BlocProvider(
          create: (_) =>
              OfferBloc(repository: sl<OfferRepository>())
                ..add(const LoadOffers()),
        ),
      ],
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<ProductBloc, ProductState>(
            builder: (context, state) {
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _HomeAppBar(onSearchTap: () {
                      context.push(AppRoutes.products);
                    }),
                  ),
                  const SliverToBoxAdapter(child: _OffersMarqueeSection()),
                  const SliverToBoxAdapter(child: _BannerCarousel()),
                  const SliverToBoxAdapter(child: _FlashSaleSection()),
                  const SliverToBoxAdapter(child: _CategoriesSection()),
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: AppStrings.featuredProducts,
                      onViewAll: () => context.push(AppRoutes.products),
                    ),
                  ),
                  if (state is ProductLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: ProductGridShimmer(itemCount: 2),
                      ),
                    )
                  else if (state is ProductLoaded)
                    SliverToBoxAdapter(
                      child: _FeaturedProducts(products: state.featured),
                    ),
                  SliverToBoxAdapter(
                    child: _SectionHeader(
                      title: AppStrings.newArrivals,
                      onViewAll: () => context.push(AppRoutes.products),
                    ),
                  ),
                  if (state is ProductLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: ProductGridShimmer(itemCount: 2),
                      ),
                    )
                  else if (state is ProductLoaded)
                    SliverToBoxAdapter(
                      child: _NewArrivals(products: state.newArrivals),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// شريط العروض المتحرك
class _OffersMarqueeSection extends StatelessWidget {
  const _OffersMarqueeSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfferBloc, OfferState>(
      builder: (context, state) {
        final offers = state is OfferLoaded ? state.offers : DemoData.offers;
        return OffersMarquee(offers: offers);
      },
    );
  }
}

/// قسم عروض الفلاش (عد تنازلي)
class _FlashSaleSection extends StatelessWidget {
  const _FlashSaleSection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OfferBloc, OfferState>(
      builder: (context, state) {
        final flash = state is OfferLoaded ? state.flashOffers : const <Offer>[];
        if (flash.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: AppStrings.flashOffers,
              onViewAll: () => context.push(AppRoutes.offers),
            ),
            SizedBox(
              height: 190,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: flash.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final offer = flash[index];
                  return _FlashCard(
                    offer: offer,
                    onTap: () =>
                        context.push(AppRoutes.offerDetailsLink(offer.id)),
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

class _FlashCard extends StatelessWidget {
  const _FlashCard({required this.offer, required this.onTap});

  final Offer offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              offer.title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              offer.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
            ),
            const Spacer(),
            if (offer.endDate != null)
              FlashCountdown(endTime: offer.endDate!, compact: true),
          ],
        ),
      ),
    );
  }
}

/// شريط علوي مع البحث والإشعارات
class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({required this.onSearchTap});

  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(5),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset('assets/images/logo.png', fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.appName,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppStrings.appTagline,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onSearchTap,
            icon: const Icon(Icons.search),
            tooltip: AppStrings.search,
          ),
          IconButton(
            onPressed: () => context.push(AppRoutes.compare),
            icon: const Icon(Icons.compare_arrows),
            tooltip: AppStrings.compare,
          ),
          const NotificationBell(),
        ],
      ),
    );
  }
}

/// البانر الدوار للعروض
class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel();

  @override
  Widget build(BuildContext context) {
    final banners = DemoData.banners.where((b) => b.isActive).toList();

    return SizedBox(
      height: 170,
      child: PageView.builder(
        padEnds: true,
        controller: PageController(viewportFraction: 0.92),
        itemCount: banners.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _BannerCard(data: banners[index]),
          );
        },
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.data});

  final Banner data;

  Color _resolveColor() {
    final hex = data.bgColorHex ?? '1A237E';
    final value = int.tryParse(hex, radix: 16);
    if (value == null) return AppColors.secondary;
    return Color(0xFF000000 | value);
  }

  void _onTap(BuildContext context) {
    switch (data.linkType) {
      case BannerLinkType.product:
        if (data.linkTarget != null) {
          context.push(AppRoutes.productDetailsLink(data.linkTarget!));
        }
      case BannerLinkType.category:
        if (data.linkTarget != null) {
          context.push(AppRoutes.productsByCategoryLink(data.linkTarget!));
        }
      case BannerLinkType.offer:
        context.push(AppRoutes.offers);
      case BannerLinkType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _resolveColor();
    return GestureDetector(
      onTap: () => _onTap(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              bottom: -30,
              child: Icon(
                Icons.diamond_outlined,
                size: 140,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Text(
                    AppStrings.shopNow,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// قسم الفئات الأفقية
class _CategoriesSection extends StatelessWidget {
  const _CategoriesSection();

  @override
  Widget build(BuildContext context) {
    final categories = [
      ('الكريستال الإيطالي', Icons.diamond_outlined, 'cat_italian_crystal'),
      ('أدوات المائدة', Icons.restaurant, 'cat_cutlery'),
      ('ديكور المنزل', Icons.chair_outlined, 'cat_decor'),
      ('هدايا فاخرة', Icons.card_giftcard, 'cat_gifts'),
      ('مزهريات', Icons.local_florist, 'cat_crystal_vases'),
      ('جوائز وتذكارات', Icons.emoji_events, 'cat_trophies'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            children: [
              Text(
                AppStrings.categories,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.push(AppRoutes.categories),
                child: const Text(AppStrings.viewAll),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return _CategoryChip(
                icon: categories[index].$2,
                label: categories[index].$1,
                onTap: () => context.push(
                  AppRoutes.productsByCategoryLink(categories[index].$3),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 72,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 28, color: AppColors.secondary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// عنوان القسم
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onViewAll});

  final String title;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
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
          const Spacer(),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: const Text(AppStrings.viewAll),
            ),
        ],
      ),
    );
  }
}

/// المنتجات المميزة
class _FeaturedProducts extends StatelessWidget {
  const _FeaturedProducts({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      height: 280,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 170,
            child: FavoriteAwareCard(
              product: products[index],
              heroTag: 'featured-${products[index].id}',
            ),
          );
        },
      ),
    );
  }
}

/// وصل حديثاً
class _NewArrivals extends StatelessWidget {
  const _NewArrivals({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const SizedBox.shrink();
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // أُنقص النسبة (بطاقة أطول) لإفساح مجال لزر "أضف إلى السلة" الجديد
        // أسفل كل بطاقة (يطابق تصميم موقع الشركة)
        childAspectRatio: 0.56,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return FavoriteAwareCard(
          product: products[index],
          heroTag: 'new-${products[index].id}',
        );
      },
    );
  }
}
