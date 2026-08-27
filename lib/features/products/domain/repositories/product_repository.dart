import '../../../../shared/models/product.dart';

/// واجهة مستودع المنتجات
abstract class ProductRepository {
  /// جلب جميع المنتجات
  Future<List<Product>> getProducts();

  /// جلب المنتجات حسب الفئة
  Future<List<Product>> getProductsByCategory(String categoryId);

  /// جلب منتج بالمعرف
  Future<Product?> getProductById(String id);

  /// جلب المنتجات المميزة
  Future<List<Product>> getFeaturedProducts();

  /// جلب المنتجات الأحدث
  Future<List<Product>> getNewArrivals();

  /// جلب المنتجات الأكثر مبيعاً
  Future<List<Product>> getBestSellers();

  /// البحث في المنتجات
  Future<List<Product>> searchProducts(String query);

  /// بث جميع المنتجات (محدث تلقائياً - للوحة الإدارة)
  Stream<List<Product>> watchProducts();

  /// إضافة منتج جديد
  Future<void> addProduct(Product product);

  /// تحديث منتج موجود
  Future<void> updateProduct(Product product);

  /// حذف منتج
  Future<void> deleteProduct(String id);
}
