import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/category.dart';
import '../../domain/repositories/category_repository.dart';

/// مستودع فئات عبر Firestore
/// يعود للبيانات التجريبية إن كانت القاعدة فارغة أو تعذر الاتصال
class FirestoreCategoryRepository implements CategoryRepository {
  FirestoreCategoryRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('categories');

  @override
  Future<List<Category>> getCategories() async {
    try {
      final snapshot = await _categories.get();
      if (snapshot.docs.isEmpty) return DemoData.categories;
      return snapshot.docs
          .map((doc) => Category.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (_) {
      return DemoData.categories;
    }
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    try {
      final doc = await _categories.doc(id).get();
      if (!doc.exists) return null;
      return Category.fromMap(doc.data()!, doc.id);
    } catch (_) {
      for (final c in DemoData.categories) {
        if (c.id == id) return c;
      }
      return null;
    }
  }

  @override
  Future<List<Category>> getSubCategories(String parentId) async {
    final categories = await getCategories();
    return categories.where((c) => c.parentId == parentId).toList();
  }
}
