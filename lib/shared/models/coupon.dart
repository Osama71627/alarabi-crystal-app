/// أنواع الكوبونات
enum CouponType { percentage, fixed, freeShipping }

/// فئة العملاء المستهدفة بالكوبون
/// - [all]: متاح لكل العملاء
/// - [newCustomers]: من لم يشترِ من قبل (لا طلبات سابقة)
/// - [bigSpenders]: من تجاوز إجمالي مشترياته [Coupon.minTotalSpent]
enum CouponAudience { all, newCustomers, bigSpenders }

/// كوبون الخصم
class Coupon {
  const Coupon({
    required this.code,
    required this.type,
    required this.discountValue,
    this.minOrderAmount = 0,
    this.maxDiscount,
    this.expiryDate,
    this.usageLimit,
    this.usedCount = 0,
    this.perUserLimit,
    this.isActive = true,
    this.applicableProductIds = const [],
    this.applicableCategoryIds = const [],
    this.audience = CouponAudience.all,
    this.minTotalSpent = 0,
  });

  final String code;
  final CouponType type;
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscount;
  final DateTime? expiryDate;
  final int? usageLimit;
  final int usedCount;
  final int? perUserLimit;
  final bool isActive;
  final List<String> applicableProductIds;
  final List<String> applicableCategoryIds;

  /// فئة العملاء المسموح لها باستخدام هذا الكوبون
  final CouponAudience audience;

  /// حد إجمالي المشتريات لفئة [CouponAudience.bigSpenders]
  final double minTotalSpent;

  /// هل الكوبون صالح؟
  bool get isValid {
    if (!isActive) return false;
    if (expiryDate != null && DateTime.now().isAfter(expiryDate!)) return false;
    if (usageLimit != null && usedCount >= usageLimit!) return false;
    return true;
  }

  factory Coupon.fromMap(Map<String, dynamic> map, String id) {
    return Coupon(
      code: id,
      type: CouponType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => CouponType.percentage,
      ),
      discountValue: (map['discountValue'] as num?)?.toDouble() ?? 0,
      minOrderAmount: (map['minOrderAmount'] as num?)?.toDouble() ?? 0,
      maxDiscount: (map['maxDiscount'] as num?)?.toDouble(),
      expiryDate: map['expiryDate'] != null
          ? DateTime.tryParse(map['expiryDate'].toString())
          : null,
      usageLimit: (map['usageLimit'] as num?)?.toInt(),
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
      perUserLimit: (map['perUserLimit'] as num?)?.toInt(),
      isActive: map['isActive'] as bool? ?? true,
      applicableProductIds:
          (map['applicableProductIds'] as List?)?.cast<String>() ?? const [],
      applicableCategoryIds:
          (map['applicableCategoryIds'] as List?)?.cast<String>() ?? const [],
      audience: CouponAudience.values.firstWhere(
        (e) => e.name == map['audience'],
        orElse: () => CouponAudience.all,
      ),
      minTotalSpent: (map['minTotalSpent'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'discountValue': discountValue,
      'minOrderAmount': minOrderAmount,
      'maxDiscount': maxDiscount,
      'expiryDate': expiryDate?.toIso8601String(),
      'usageLimit': usageLimit,
      'usedCount': usedCount,
      'perUserLimit': perUserLimit,
      'isActive': isActive,
      'applicableProductIds': applicableProductIds,
      'applicableCategoryIds': applicableCategoryIds,
      'audience': audience.name,
      'minTotalSpent': minTotalSpent,
    };
  }
}
