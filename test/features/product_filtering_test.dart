import 'package:alarabi_crystal/features/products/domain/product_filtering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('بحث', () {
    test('يبحث في الاسم مع تجاهل حالة الأحرف', () {
      final products = [
        makeProduct('p1', name: 'مزهريـة كريستال'),
        makeProduct('p2', name: 'طقم مائدة'),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(query: 'كريستال'),
      );
      expect(result.map((p) => p.id), ['p1']);
    });

    test('يبحث في العلامة التجارية والوصف', () {
      final products = [
        makeProduct('p1', brand: 'Swarovski'),
        makeProduct('p2', description: 'زجاج كريستالي إيطالي'),
      ];
      expect(
        ProductFiltering.apply(
          products,
          const ProductFilterOptions(query: 'swarovski'),
        ).length,
        1,
      );
      expect(
        ProductFiltering.apply(
          products,
          const ProductFilterOptions(query: 'إيطالي'),
        ).map((p) => p.id),
        ['p2'],
      );
    });
  });

  group('تصفية', () {
    test('يصفّي حسب الفئات المختارة', () {
      final products = [
        makeProduct('p1', categoryId: 'a'),
        makeProduct('p2', categoryId: 'b'),
        makeProduct('p3', categoryId: 'a'),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(categories: ['a']),
      );
      expect(result.map((p) => p.id), ['p1', 'p3']);
    });

    test('يصفّي حسب السعر الأقصى', () {
      final products = [
        makeProduct('p1', price: 100),
        makeProduct('p2', price: 500),
        makeProduct('p3', price: 250),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(maxPrice: 250),
      );
      expect(result.map((p) => p.id), ['p1', 'p3']);
    });

    test('يصفّي ضمن مدى سعري (من — إلى)', () {
      final products = [
        makeProduct('p1', price: 500),
        makeProduct('p2', price: 5000),
        makeProduct('p3', price: 12000),
        makeProduct('p4', price: 1000),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(minPrice: 1000, maxPrice: 10000),
      );
      expect(result.map((p) => p.id).toSet(), {'p2', 'p4'});
    });

    test('حدّا المدى شاملان (inclusive)', () {
      final products = [
        makeProduct('p1', price: 1000),
        makeProduct('p2', price: 10000),
        makeProduct('p3', price: 999),
        makeProduct('p4', price: 10001),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(minPrice: 1000, maxPrice: 10000),
      );
      expect(result.map((p) => p.id).toSet(), {'p1', 'p2'});
    });

    test('المدى يُطبَّق على السعر المخفّض لا الأصلي', () {
      final products = [
        // سعره الأصلي داخل المدى لكن الفعلي (المخفّض) أقل منه
        makeProduct('p1', price: 5000, discountPrice: 300),
        makeProduct('p2', price: 5000),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(minPrice: 1000, maxPrice: 10000),
      );
      expect(result.map((p) => p.id), ['p2']);
    });

    test('يأخذ السعر المخفّض في الاعتبار عند التصفية', () {
      final products = [
        makeProduct('p1', price: 1000, discountPrice: 200),
        makeProduct('p2', price: 100),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(maxPrice: 250),
      );
      expect(result.map((p) => p.id), ['p1', 'p2']);
    });

    test('يصفّي حسب الحد الأدنى للتقييم', () {
      final products = [
        makeProduct('p1', rating: 3.2),
        makeProduct('p2', rating: 4.5),
        makeProduct('p3', rating: 4.8),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(minRating: 4.5),
      );
      expect(result.map((p) => p.id), ['p2', 'p3']);
    });
  });

  group('ترتيب', () {
    test('الأحدث أولاً', () {
      final products = [
        makeProduct('old', createdAt: DateTime(2020)),
        makeProduct('new', createdAt: DateTime(2025)),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(sort: SortOption.latest),
      );
      expect(result.first.id, 'new');
    });

    test('الأعلى تقييماً أولاً', () {
      final products = [
        makeProduct('p1', rating: 3),
        makeProduct('p2', rating: 5),
        makeProduct('p3', rating: 4),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(sort: SortOption.topRated),
      );
      expect(result.map((p) => p.id), ['p2', 'p3', 'p1']);
    });

    test('السعر تصاعدياً', () {
      final products = [
        makeProduct('p1', price: 300),
        makeProduct('p2', price: 100),
        makeProduct('p3', price: 200),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(sort: SortOption.priceLowToHigh),
      );
      expect(result.map((p) => p.id), ['p2', 'p3', 'p1']);
    });

    test('السعر تنازلياً مع مراعاة الخصم', () {
      final products = [
        makeProduct('p1', price: 100, discountPrice: 60),
        makeProduct('p2', price: 500),
        makeProduct('p3', price: 80),
      ];
      final result = ProductFiltering.apply(
        products,
        const ProductFilterOptions(sort: SortOption.priceHighToLow),
      );
      expect(result.map((p) => p.id), ['p2', 'p3', 'p1']);
    });
  });

  test('لا يعدّل القائمة الأصلية (نسخة مستقلة)', () {
    final products = [
      makeProduct('p1', price: 200),
      makeProduct('p2', price: 100),
    ];
    ProductFiltering.apply(
      products,
      const ProductFilterOptions(sort: SortOption.priceLowToHigh),
    );
    expect(products.map((p) => p.id).toList(), ['p1', 'p2']);
  });
}
