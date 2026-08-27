import 'package:alarabi_crystal/shared/services/csv_product_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('CsvProductService', () {
    test('تصدير CSV يحتوي الترويسة وسطراً لكل منتج', () {
      final csv = CsvProductService.export([
        makeProduct('p1', name: 'منتج 1', price: 100),
        makeProduct('p2', name: 'منتج 2', price: 200, soldCount: 5),
      ]);

      expect(csv, startsWith(CsvProductService.header));
      expect(csv.contains('p1,منتج 1'), isTrue);
      expect(csv.contains('p2,منتج 2'), isTrue);
      expect(csv.split('\n').where((l) => l.isNotEmpty).length, 3);
    });

    test('تصدير ثم استيراد يحافظ على البيانات الأساسية', () {
      final products = [
        makeProduct('p1', name: 'منتج 1', price: 100, categoryId: 'cat-1'),
        makeProduct(
          'p2',
          name: 'منتج 2',
          price: 200,
          discountPrice: 150,
          categoryId: 'cat-2',
          soldCount: 3,
          sku: 'SKU-2',
        ),
      ];

      final csv = CsvProductService.export(products);
      final parsed = CsvProductService.parse(csv);

      expect(parsed.length, 2);
      expect(parsed[0].id, 'p1');
      expect(parsed[0].name, 'منتج 1');
      expect(parsed[0].price, 100);
      expect(parsed[1].discountPrice, 150);
      expect(parsed[1].soldCount, 3);
      expect(parsed[1].sku, 'SKU-2');
    });

    test('يتجاهل الأسطر الفارغة', () {
      final products = CsvProductService.parse(
        '${CsvProductService.header}\n\n\n',
      );
      expect(products, isEmpty);
    });

    test('سطر ناقص الحقول يرمي CsvImportException', () {
      expect(
        () => CsvProductService.parse('a,b,c'),
        throwsA(isA<CsvImportException>()),
      );
    });

    test('يُفلت الحقول المحتوية على فواصل بين علامتي تنصيص', () {
      final csv = CsvProductService.export([
        makeProduct('p1', name: 'منتج, فاخر'),
      ]);

      expect(csv.contains('"منتج, فاخر"'), isTrue);
      final parsed = CsvProductService.parse(csv);
      expect(parsed.first.name, 'منتج, فاخر');
    });
  });
}
