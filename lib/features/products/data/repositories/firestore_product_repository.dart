import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/product.dart';
import '../../domain/repositories/product_repository.dart';

/// مستودع منتجات عبر Firestore
/// يعود للبيانات التجريبية إن كانت قاعدة البيانات فارغة أو تعذر الاتصال
class FirestoreProductRepository implements ProductRepository {
  FirestoreProductRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  Future<List<Product>> _fetchAll() async {
    try {
      final snapshot = await _products.get();
      if (snapshot.docs.isEmpty) return DemoData.products;
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    } catch (_) {
      return DemoData.products;
    }
  }

  @override
  Future<List<Product>> getProducts() => _fetchAll();

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    final products = await _fetchAll();
    return products.where((p) => p.categoryId == categoryId).toList();
  }

  @override
  Future<Product?> getProductById(String id) async {
    try {
      final doc = await _products.doc(id).get();
      if (!doc.exists) return null;
      return Product.fromMap(doc.data()!, doc.id);
    } catch (_) {
      for (final p in DemoData.products) {
        if (p.id == id) return p;
      }
      return null;
    }
  }

  @override
  Future<List<Product>> getFeaturedProducts() async {
    final products = await _fetchAll();
    return products.where((p) => p.isFeatured).toList();
  }

  @override
  Future<List<Product>> getNewArrivals() async {
    final products = await _fetchAll();
    final sorted = [...products]
      ..sort((a, b) => (b.createdAt ?? DateTime(2000))
          .compareTo(a.createdAt ?? DateTime(2000)));
    return sorted.take(6).toList();
  }

  @override
  Future<List<Product>> getBestSellers() async {
    final products = await _fetchAll();
    final sorted = [...products]
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    return sorted.take(6).toList();
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    final products = await _fetchAll();
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.description.toLowerCase().contains(q) ||
          p.brand.toLowerCase().contains(q);
    }).toList();
  }

  /// حدّ أعلى مقصود (المرحلة 13 — M6): بلا حدّ، يحمّل الاستماع كامل كتالوج
  /// المنتجات ويعيد مزامنته عند أي تغيير في أي منتج — تكلفة قراءة/ذاكرة
  /// تنمو بلا سقف مع نمو المتجر. سخي بما يكفي ألا يُخفي أي منتج حالياً.
  static const int _productsLimit = 500;

  @override
  Stream<List<Product>> watchProducts() {
    return _products.limit(_productsLimit).snapshots().map((snapshot) {
      if (snapshot.docs.isEmpty) return DemoData.products;
      return snapshot.docs
          .map((doc) => Product.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  @override
  Future<void> addProduct(Product product) {
    return _products
        .doc(product.id)
        .set(_sanitize(product.toMap()));
  }

  @override
  Future<void> updateProduct(Product product) {
    return _products
        .doc(product.id)
        .set(_sanitize(product.toMap()));
  }

  @override
  Future<void> deleteProduct(String id) {
    return _products.doc(id).delete();
  }

  /// إزالة القيم الفارغة (Firestore لا يقبل null)
  Map<String, dynamic> _sanitize(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value == null) return;
      if (value is Map<String, dynamic>) {
        result[key] = _sanitize(value);
      } else if (value is Map) {
        result[key] = _sanitize(
          value.map((k, v) => MapEntry(k.toString(), v)),
        );
      } else {
        result[key] = value;
      }
    });
    return result;
  }
}
