import '../models/cart_item.dart';
import '../models/offer.dart';

/// نتيجة حساب خصم عرض
class OfferResult {
  const OfferResult({required this.offer, required this.discount});

  final Offer offer;
  final double discount;
}

/// محرك حساب خصومات العروض
/// منطق نقي بدون تبعيات خارجية ليسهل اختباره
class OfferEngine {
  OfferEngine._();

  /// هل ينطبق العرض على السلة الحالية؟
  static bool isApplicable(
    Offer offer, {
    required List<String> productIds,
    required List<String> categoryIds,
  }) {
    if (!offer.isValid) return false;
    switch (offer.applicableType) {
      case OfferApplicableType.all:
        return true;
      case OfferApplicableType.product:
        return offer.applicableIds.any(productIds.contains);
      case OfferApplicableType.category:
        return offer.applicableIds.any(categoryIds.contains);
    }
  }

  /// حساب قيمة الخصم لعرض واحد على السلة
  static double discountFor(
    Offer offer, {
    required double subtotal,
    required List<String> productIds,
    required List<String> categoryIds,
    required List<CartItem> items,
    bool memberEligible = false,
  }) {
    if (!isApplicable(offer, productIds: productIds, categoryIds: categoryIds)) {
      return 0;
    }
    if (offer.type == OfferType.member && !memberEligible) return 0;
    if (subtotal < offer.minPurchase) return 0;
    if (subtotal <= 0) return 0;

    switch (offer.type) {
      case OfferType.bundle:
        return _bundleDiscount(offer, items);
      case OfferType.fixed:
        return offer.discountValue > subtotal ? subtotal : offer.discountValue;
      case OfferType.percentage:
      case OfferType.cart:
      case OfferType.flash:
      case OfferType.member:
        final raw = subtotal * offer.discountValue / 100;
        if (offer.maxDiscount != null && raw > offer.maxDiscount!) {
          return offer.maxDiscount!;
        }
        return raw;
    }
  }

  /// خصم عروض "اشترِ واحصل على" للعناصر المؤهلة
  static double _bundleDiscount(Offer offer, List<CartItem> items) {
    if (offer.buyQuantity <= 0) return 0;
    double total = 0;
    for (final item in items) {
      if (!_itemIncluded(offer, item)) continue;
      final sets = item.quantity ~/ offer.buyQuantity;
      if (sets == 0) continue;
      final free = sets * offer.getQuantity;
      total += free * item.unitPrice;
    }
    return total;
  }

  static bool _itemIncluded(Offer offer, CartItem item) {
    switch (offer.applicableType) {
      case OfferApplicableType.all:
        return true;
      case OfferApplicableType.product:
        return offer.applicableIds.contains(item.productId);
      case OfferApplicableType.category:
        final categoryId = item.categoryId;
        return categoryId != null && offer.applicableIds.contains(categoryId);
    }
  }

  /// أفضل عرض (الأعلى خصماً) بين العروض المطبقة
  static OfferResult? bestOffer(
    List<Offer> offers, {
    required double subtotal,
    required List<String> productIds,
    required List<String> categoryIds,
    required List<CartItem> items,
    bool memberEligible = false,
  }) {
    OfferResult? best;
    for (final offer in offers) {
      final discount = discountFor(
        offer,
        subtotal: subtotal,
        productIds: productIds,
        categoryIds: categoryIds,
        items: items,
        memberEligible: memberEligible,
      );
      if (discount <= 0) continue;
      if (best == null || discount > best.discount) {
        best = OfferResult(offer: offer, discount: discount);
      }
    }
    return best;
  }
}
