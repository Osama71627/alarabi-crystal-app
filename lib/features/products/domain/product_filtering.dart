import '../../../shared/models/product.dart';

/// ترتيب النتائج
enum SortOption { latest, topRated, priceLowToHigh, priceHighToLow }

/// خيارات التصفية والترتيب
class ProductFilterOptions {
  const ProductFilterOptions({
    this.query = '',
    this.categories = const [],
    this.minPrice = 0,
    this.maxPrice = double.infinity,
    this.minRating = 0,
    this.sort = SortOption.latest,
  });

  final String query;
  final List<String> categories;

  /// حد السعر الأدنى — يُستخدم مع [maxPrice] كمدى سعري (مثلاً 1000 إلى 10000)
  final double minPrice;
  final double maxPrice;
  final double minRating;
  final SortOption sort;
}

/// منطق التصفية والبحث والترتيب النقي (يُختبر وحده)
class ProductFiltering {
  const ProductFiltering._();

  /// تطبيق البحث والتصفية والترتيب على قائمة المنتجات
  static List<Product> apply(
    List<Product> products,
    ProductFilterOptions options,
  ) {
    var result = products;

    // فلترة حسب الفئات المختارة
    if (options.categories.isNotEmpty) {
      result = result
          .where((p) => options.categories.contains(p.categoryId))
          .toList();
    }

    // بحث في الاسم/العلامة/الوصف
    final query = options.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.brand.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query);
      }).toList();
    }

    // فلترة السعر ضمن المدى المختار
    if (options.minPrice > 0) {
      result =
          result.where((p) => p.effectivePrice >= options.minPrice).toList();
    }
    if (options.maxPrice.isFinite) {
      result = result.where((p) => p.effectivePrice <= options.maxPrice).toList();
    }

    // فلترة التقييم
    if (options.minRating > 0) {
      result = result.where((p) => p.rating >= options.minRating).toList();
    }

    // الترتيب
    final sorted = [...result];
    switch (options.sort) {
      case SortOption.latest:
        sorted.sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)));
      case SortOption.topRated:
        sorted.sort((a, b) => b.rating.compareTo(a.rating));
      case SortOption.priceLowToHigh:
        sorted.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
      case SortOption.priceHighToLow:
        sorted.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    }

    return sorted;
  }
}
