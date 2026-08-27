import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/product.dart';
import '../../domain/repositories/product_repository.dart';

/// مستودع منتجات تجريبي
class DemoProductRepository implements ProductRepository {
  const DemoProductRepository();

  @override
  Future<List<Product>> getProducts() async {
    return DemoData.products;
  }

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    return DemoData.products
        .where((p) => p.categoryId == categoryId)
        .toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    for (final p in DemoData.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<Product>> getFeaturedProducts() async {
    return DemoData.products.where((p) => p.isFeatured).toList();
  }

  @override
  Future<List<Product>> getNewArrivals() async {
    final sorted = [...DemoData.products]
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
    return sorted.take(6).toList();
  }

  @override
  Future<List<Product>> getBestSellers() async {
    final sorted = [...DemoData.products]
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    return sorted.take(6).toList();
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return DemoData.products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Stream<List<Product>> watchProducts() async* {
    yield DemoData.products;
  }

  @override
  Future<void> addProduct(Product product) async {}

  @override
  Future<void> updateProduct(Product product) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}
