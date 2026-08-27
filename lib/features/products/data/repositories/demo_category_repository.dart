import '../../../../shared/data/demo_data.dart';
import '../../../../shared/models/category.dart';
import '../../domain/repositories/category_repository.dart';

/// مستودع فئات تجريبي
class DemoCategoryRepository implements CategoryRepository {
  const DemoCategoryRepository();

  @override
  Future<List<Category>> getCategories() async {
    return DemoData.categories;
  }

  @override
  Future<Category?> getCategoryById(String id) async {
    for (final c in DemoData.categories) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<Category>> getSubCategories(String parentId) async {
    return DemoData.categories
        .where((c) => c.parentId == parentId)
        .toList();
  }
}
