import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../shared/models/offer.dart';
import 'flash_countdown.dart';

/// بطاقة عرض
class OfferCard extends StatelessWidget {
  const OfferCard({
    super.key,
    required this.offer,
    this.onTap,
    this.onShopNow,
  });

  final Offer offer;
  final VoidCallback? onTap;
  final VoidCallback? onShopNow;

  Color _colorFor(OfferType type) {
    switch (type) {
      case OfferType.flash:
        return const Color(0xFFB71C1C);
      case OfferType.bundle:
        return const Color(0xFF00695C);
      case OfferType.member:
        return const Color(0xFF4A148C);
      case OfferType.cart:
        return const Color(0xFF1565C0);
      case OfferType.fixed:
        return const Color(0xFFE65100);
      case OfferType.percentage:
        return AppColors.secondary;
    }
  }

  String _badge(Offer offer) {
    switch (offer.type) {
      case OfferType.percentage:
        return '-${offer.discountValue.toStringAsFixed(0)}%';
      case OfferType.fixed:
        return '-${offer.discountValue.toStringAsFixed(0)}';
      case OfferType.bundle:
        return '${offer.getQuantity} + ${offer.buyQuantity}';
      case OfferType.flash:
        return 'FLASH';
      case OfferType.cart:
        return 'سلة';
      case OfferType.member:
        return 'أعضاء';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(offer.type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.75)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _badge(offer),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            if (offer.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                offer.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (offer.type == OfferType.flash && offer.endDate != null) ...[
              FlashCountdown(
                endTime: offer.endDate!,
                compact: true,
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: const Text(AppStrings.offerDetails),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onShopNow,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: color,
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(AppStrings.shopNow),
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
