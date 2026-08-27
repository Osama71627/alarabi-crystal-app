/// أنواع العروض
enum OfferType {
  percentage, // خصم نسبي
  fixed, // خصم ثابت
  bundle, // شراء مجمع
  cart, // خصم على السلة
  flash, // عرض محدود الوقت
  member, // عرض الأعضاء
}

/// أنواع المجال الذي ينطبق عليه العرض
enum OfferApplicableType { product, category, all }

/// العرض
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.type,
    this.description = '',
    this.discountValue = 0,
    this.applicableType = OfferApplicableType.all,
    this.applicableIds = const [],
    this.minPurchase = 0,
    this.maxDiscount,
    this.usageLimit,
    this.usedCount = 0,
    this.perUserLimit,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.bannerImage,
    this.displayOrder = 0,
    this.buyQuantity = 0,
    this.getQuantity = 0,
  });

  final String id;
  final String title;
  final String description;
  final OfferType type;
  final double discountValue;
  final OfferApplicableType applicableType;
  final List<String> applicableIds;
  final double minPurchase;
  final double? maxDiscount;
  final int? usageLimit;
  final int usedCount;
  final int? perUserLimit;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final String? bannerImage;
  final int displayOrder;
  final int buyQuantity; // للعروض المجمعة: اشترِ
  final int getQuantity; // للعروض المجمعة: احصل على

  /// هل العرض سارٍ حالياً؟
  bool get isValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    if (usageLimit != null && usedCount >= usageLimit!) return false;
    return true;
  }

  /// الوقت المتبقي حتى نهاية العرض
  Duration? get remainingTime {
    if (endDate == null) return null;
    return endDate!.difference(DateTime.now());
  }

  /// هل العرض محدود الوقت؟
  bool get isFlash => type == OfferType.flash;

  /// نص الشارة
  String get badgeLabel {
    switch (type) {
      case OfferType.percentage:
        return '-${discountValue.toStringAsFixed(0)}%';
      case OfferType.fixed:
        return '-${discountValue.toStringAsFixed(0)}';
      case OfferType.bundle:
        return '$buyQuantity+$getQuantity';
      case OfferType.cart:
        return 'عرض السلة';
      case OfferType.flash:
        return 'فلاش';
      case OfferType.member:
        return 'أعضاء';
    }
  }

  factory Offer.fromMap(Map<String, dynamic> map, String id) {
    return Offer(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      type: _offerTypeFromString(map['type'] as String? ?? 'percentage'),
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0,
      applicableType: _applicableFromString(
          map['applicableType'] as String? ?? 'all'),
      applicableIds:
          (map['applicableIds'] as List?)?.cast<String>() ?? const [],
      minPurchase: (map['minPurchase'] as num?)?.toDouble() ?? 0,
      maxDiscount: (map['maxDiscount'] as num?)?.toDouble(),
      usageLimit: (map['usageLimit'] as num?)?.toInt(),
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      perUserLimit: (map['perUserLimit'] as num?)?.toInt(),
      startDate: map['startDate'] != null
          ? DateTime.tryParse(map['startDate'].toString())
          : null,
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'].toString())
          : null,
      isActive: map['isActive'] as bool? ?? true,
      bannerImage: map['bannerImage'] as String?,
      displayOrder: (map['displayOrder'] as num?)?.toInt() ?? 0,
      buyQuantity: (map['buyQuantity'] as num?)?.toInt() ?? 0,
      getQuantity: (map['getQuantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'type': type.name,
      'discountValue': discountValue,
      'applicableType': applicableType.name,
      'applicableIds': applicableIds,
      'minPurchase': minPurchase,
      'maxDiscount': maxDiscount,
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'perUserLimit': perUserLimit,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'isActive': isActive,
      'bannerImage': bannerImage,
      'displayOrder': displayOrder,
      'buyQuantity': buyQuantity,
      'getQuantity': getQuantity,
    };
  }

  static OfferType _offerTypeFromString(String value) {
    return OfferType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OfferType.percentage,
    );
  }

  /// نسخة معدلة من العرض
  Offer copyWith({
    String? title,
    String? description,
    OfferType? type,
    double? discountValue,
    OfferApplicableType? applicableType,
    List<String>? applicableIds,
    double? minPurchase,
    double? maxDiscount,
    int? usageLimit,
    int? usedCount,
    int? perUserLimit,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    String? bannerImage,
    int? displayOrder,
    int? buyQuantity,
    int? getQuantity,
  }) {
    return Offer(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      discountValue: discountValue ?? this.discountValue,
      applicableType: applicableType ?? this.applicableType,
      applicableIds: applicableIds ?? this.applicableIds,
      minPurchase: minPurchase ?? this.minPurchase,
      maxDiscount: maxDiscount ?? this.maxDiscount,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      perUserLimit: perUserLimit ?? this.perUserLimit,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      bannerImage: bannerImage ?? this.bannerImage,
      displayOrder: displayOrder ?? this.displayOrder,
      buyQuantity: buyQuantity ?? this.buyQuantity,
      getQuantity: getQuantity ?? this.getQuantity,
    );
  }

  static OfferApplicableType _applicableFromString(String value) {
    return OfferApplicableType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => OfferApplicableType.all,
    );
  }
}
