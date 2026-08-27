import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/offer.dart';
import '../../../../shared/services/cart_service.dart';
import '../../../../config/routes.dart';
import '../../domain/repositories/offer_repository.dart';
import '../bloc/offer_bloc.dart';
import '../widgets/offer_card.dart';

/// شاشة العروض — عروض حقيقية من المستودع مع فلترة حسب النوع
class OffersScreen extends StatelessWidget {
  const OffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          OfferBloc(repository: sl<OfferRepository>())..add(const LoadOffers()),
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<OfferBloc, OfferState>(
            builder: (context, state) {
              return switch (state) {
                OfferInitial() || OfferLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                OfferError() => _ErrorView(
                    onRetry: () =>
                        context.read<OfferBloc>().add(const LoadOffers()),
                  ),
                OfferLoaded(:final offers) => _OffersList(offers: offers),
              };
            },
          ),
        ),
      ),
    );
  }
}

class _OffersList extends StatefulWidget {
  const _OffersList({required this.offers});

  final List<Offer> offers;

  @override
  State<_OffersList> createState() => _OffersListState();
}

class _OffersListState extends State<_OffersList> {
  OfferType? _filter;

  List<Offer> get _visibleOffers {
    final filter = _filter;
    if (filter == null) return widget.offers;
    return widget.offers.where((o) => o.type == filter).toList();
  }

  void _shopNow(BuildContext context, Offer offer) {
    CartService.instance.applyOffer(offer);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.offerApplied)),
    );
    if (offer.applicableType == OfferApplicableType.category &&
        offer.applicableIds.length == 1) {
      context.push(AppRoutes.productsByCategoryLink(offer.applicableIds.first));
    } else {
      context.push(AppRoutes.products);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleOffers;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          AppStrings.offers,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.appTagline,
          style: const TextStyle(color: AppColors.secondary),
        ),
        const SizedBox(height: 16),
        _FilterChips(
          selected: _filter,
          onChanged: (type) => setState(() => _filter = type),
        ),
        const SizedBox(height: 16),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 48),
            child: Column(
              children: [
                Icon(
                  Icons.local_offer_outlined,
                  size: 64,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.noOffers,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          )
        else
          for (final offer in visible) ...[
            OfferCard(
              offer: offer,
              onTap: () => context.push(
                AppRoutes.offerDetailsLink(offer.id),
              ),
              onShopNow: () => _shopNow(context, offer),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final OfferType? selected;
  final ValueChanged<OfferType?> onChanged;

  static const _filters = <(String, OfferType?)>[
    (AppStrings.allOffers, null),
    (AppStrings.flashOffers, OfferType.flash),
    (AppStrings.percentageOffers, OfferType.percentage),
    (AppStrings.fixedOffers, OfferType.fixed),
    (AppStrings.bundleOffers, OfferType.bundle),
    (AppStrings.cartOffers, OfferType.cart),
    (AppStrings.memberOffers, OfferType.member),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, type) = _filters[index];
          return ChoiceChip(
            label: Text(label),
            selected: selected == type,
            onSelected: (_) => onChanged(type),
            selectedColor: AppColors.secondary,
            labelStyle: TextStyle(
              color: selected == type ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.errorNetwork,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text(AppStrings.retry),
          ),
        ],
      ),
    );
  }
}
