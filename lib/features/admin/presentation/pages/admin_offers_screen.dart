import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../injection.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/offer.dart';
import '../../../../shared/services/currency_formatter.dart';
import '../../../offers/domain/repositories/offer_repository.dart';
import '../widgets/admin_widgets.dart';
import 'offer_form_screen.dart';

/// إدارة العروض: قائمة + تفعيل/تعطيل + إضافة/تعديل/حذف
class AdminOffersScreen extends StatefulWidget {
  const AdminOffersScreen({super.key});

  @override
  State<AdminOffersScreen> createState() => _AdminOffersScreenState();
}

class _AdminOffersScreenState extends State<AdminOffersScreen> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Offer>>(
      stream: sl<OfferRepository>().watchOffers(),
      builder: (context, snapshot) {
        final offers = snapshot.data ?? const <Offer>[];
        final activeCount = offers.where((o) => o.isActive).length;

        return Column(
          children: [
            AdminPageHeader(
              icon: Icons.local_offer_outlined,
              title: AppStrings.adminOffers,
              subtitle: '${offers.length} عرض • $activeCount مفعّل',
              actions: [
                FilledButton.icon(
                  onPressed: () async {
                    final created = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OfferFormScreen(),
                      ),
                    );
                    if (created == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text(AppStrings.offerCreated)),
                      );
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text(AppStrings.createOffer),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const Center(child: CircularProgressIndicator())
                  : offers.isEmpty
                      ? const AdminEmptyState(
                          icon: Icons.local_offer_outlined,
                          title: AppStrings.noData,
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: offers.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) {
                            final offer = offers[i];
                            return _OfferCard(
                              offer: offer,
                              onToggle: () => _toggle(offer),
                              onEdit: () => _edit(offer),
                              onDelete: () => _delete(offer),
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggle(Offer offer) async {
    await sl<OfferRepository>()
        .updateOffer(offer.copyWith(isActive: !offer.isActive));
  }

  Future<void> _edit(Offer offer) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OfferFormScreen(offer: offer),
      ),
    );
  }

  Future<void> _delete(Offer offer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppStrings.delete} "${offer.title}"؟'),
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
    await sl<OfferRepository>().deleteOffer(offer.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.offerDeleted)),
      );
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final Offer offer;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: offer.isActive
                  ? AppColors.success.withValues(alpha: 0.12)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.local_offer_outlined,
                color: offer.isActive
                    ? AppColors.success
                    : Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    offer.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      StatusPill(
                        label: _valueLabel(offer),
                        color: AppColors.info,
                        dense: true,
                      ),
                      StatusPill(
                        label: offer.isActive ? AppStrings.active : AppStrings.inactive,
                        color: offer.isActive ? AppColors.success : Theme.of(context).colorScheme.outline,
                        dense: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: offer.isActive ? AppStrings.inactive : AppStrings.active,
              icon: Icon(
                offer.isActive ? Icons.visibility : Icons.visibility_off,
                size: 20,
              ),
              onPressed: onToggle,
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

  String _valueLabel(Offer offer) {
    switch (offer.type) {
      case OfferType.percentage:
        return '${offer.discountValue.toStringAsFixed(0)}%';
      case OfferType.fixed:
        return CurrencyFormatter.formatClean(offer.discountValue);
      case OfferType.bundle:
        return AppStrings.buyGetOffer;
      case OfferType.cart:
        return AppStrings.cartOffers;
      case OfferType.flash:
        return AppStrings.flashOffers;
      case OfferType.member:
        return AppStrings.memberOffers;
    }
  }
}
