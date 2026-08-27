import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/offer.dart';
import '../../../../shared/services/cart_service.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../../config/routes.dart';
import '../../domain/repositories/offer_repository.dart';
import '../widgets/flash_countdown.dart';

/// شاشة تفاصيل العرض
class OfferDetailsScreen extends StatefulWidget {
  const OfferDetailsScreen({super.key, required this.offerId});

  final String offerId;

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  Offer? _offer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadOffer();
  }

  Future<void> _loadOffer() async {
    final offers = await sl<OfferRepository>().getActiveOffers();
    if (!mounted) return;
    Offer? match;
    for (final o in offers) {
      if (o.id == widget.offerId) {
        match = o;
        break;
      }
    }
    setState(() {
      _offer = match;
      _loading = false;
    });
  }

  void _applyOffer(Offer offer) {
    CartService.instance.applyOffer(offer);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.offerApplied)),
    );
  }

  void _shopNow(Offer offer) {
    _applyOffer(offer);
    if (!mounted) return;
    if (offer.applicableType == OfferApplicableType.category &&
        offer.applicableIds.length == 1) {
      context.go(AppRoutes.productsByCategoryLink(offer.applicableIds.first));
    } else if (offer.applicableType == OfferApplicableType.product &&
        offer.applicableIds.isNotEmpty) {
      context.go(AppRoutes.productDetailsLink(offer.applicableIds.first));
    } else {
      context.go(AppRoutes.products);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offer = _offer;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.offerDetails)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : offer == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_outlined,
                        size: 64,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(AppStrings.noData),
                    ],
                  ),
                )
              : _buildOfferContent(context, offer),
    );
  }

  Widget _buildOfferContent(BuildContext context, Offer offer) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // العنوان والشارة
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                offer.title,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                offer.badgeLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          offer.description,
          style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // عد تنازلي للفلاش
        if (offer.type == OfferType.flash && offer.endDate != null) ...[
          _InfoTile(
            icon: Icons.timer_outlined,
            title: AppStrings.offerEndsIn,
            child: FlashCountdown(endTime: offer.endDate!),
          ),
          const SizedBox(height: 12),
        ],

        // شروط العرض
        if (offer.minPurchase > 0) ...[
          _InfoTile(
            icon: Icons.shopping_bag_outlined,
            title: AppStrings.minPurchase,
            trailing: CurrencyFormatter.format(offer.minPurchase),
          ),
          const SizedBox(height: 12),
        ],
        if (offer.maxDiscount != null) ...[
          _InfoTile(
            icon: Icons.percent,
            title: AppStrings.maxDiscount,
            trailing: CurrencyFormatter.format(offer.maxDiscount!),
          ),
          const SizedBox(height: 12),
        ],
        if (offer.type == OfferType.bundle) ...[
          _InfoTile(
            icon: Icons.card_giftcard,
            title: AppStrings.buyGetOffer,
            trailing: '${offer.getQuantity} + ${offer.buyQuantity}',
          ),
          const SizedBox(height: 12),
        ],
        if (offer.type == OfferType.member) ...[
          _InfoTile(
            icon: Icons.workspace_premium,
            title: AppStrings.memberOfferHint,
          ),
          const SizedBox(height: 12),
        ],

        const SizedBox(height: 24),

        // أزرار
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _applyOffer(offer),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text(AppStrings.applyOffer),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _shopNow(offer),
                icon: const Icon(Icons.storefront),
                label: const Text(AppStrings.shopNow),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.child,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.secondary),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: trailing != null ? Text(trailing!) : null,
        subtitle: child,
      ),
    );
  }
}
