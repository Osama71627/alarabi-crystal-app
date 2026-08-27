import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../models/product.dart';

/// نتيجة إضافة منتج للمقارنة
enum CompareToggleResult { added, removed, limitReached }

/// خدمة المقارنة - تدير المنتجات المختارة (حتى 4) مع حفظ محلي
class CompareService extends ChangeNotifier {
  CompareService._internal();
  static final CompareService instance = CompareService._internal();

  Box<Map<dynamic, dynamic>>? _box;
  final List<Product> _items = [];

  /// المنتجات المختارة للمقارنة
  List<Product> get items => List.unmodifiable(_items);

  /// عدد المنتجات في المقارنة
  int get count => _items.length;

  bool contains(String productId) =>
      _items.any((product) => product.id == productId);

  /// فتح صندوق الحفظ المحلي
  Future<void> init() async {
    try {
      _box = await Hive.openBox<Map<dynamic, dynamic>>(
        AppConstants.hiveBoxCompare,
      );
      _loadFromBox();
    } catch (_) {
      // بدون تخزين محلي تبقى المقارنة في الذاكرة
    }
  }

  void _loadFromBox() {
    final data = _box?.values;
    if (data == null) return;
    _items.clear();
    for (final map in data) {
      final decoded = Map<String, dynamic>.from(map);
      _items.add(
        Product.fromMap(decoded, decoded['id'] as String? ?? ''),
      );
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    await _box?.clear();
    for (final product in _items) {
      final map = _sanitize(product.toMap());
      map['id'] = product.id;
      await _box?.put(product.id, map);
    }
    notifyListeners();
  }

  /// إضافة أو إزالة منتج من المقارنة
  Future<CompareToggleResult> toggle(Product product) async {
    final index = _items.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _items.removeAt(index);
      await _persist();
      return CompareToggleResult.removed;
    }
    if (_items.length >= AppConstants.maxCompareItems) {
      return CompareToggleResult.limitReached;
    }
    _items.add(product);
    await _persist();
    return CompareToggleResult.added;
  }

  /// إزالة منتج من المقارنة
  Future<void> remove(String productId) async {
    _items.removeWhere((product) => product.id == productId);
    await _persist();
  }

  /// إفراغ المقارنة
  Future<void> clear() async {
    _items.clear();
    await _persist();
  }

  /// إعادة ضبط المقارنة لأغراض الاختبار فقط
  @visibleForTesting
  Future<void> resetForTest() async {
    _items.clear();
    await _box?.clear();
  }

  /// إزالة القيم الفارغة (Hive لا يحفظ null)
  Map<String, dynamic> _sanitize(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) result[key] = value;
    });
    return result;
  }
}
