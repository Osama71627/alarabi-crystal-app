import '../../../../shared/models/category.dart';

/// واجهة مستودع الفئات
abstract class CategoryRepository {
  /// جلب جميع الفئات
  Future<List<Category>> getCategories();

  /// جلب فئة بالمعرف
  Future<Category?> getCategoryById(String id);

  /// جلب الفئات الفرعية
  Future<List<Category>> getSubCategories(String parentId);
}
