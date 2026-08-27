import '../../features/products/domain/repositories/product_repository.dart';
import '../../features/products/data/repositories/firestore_product_repository.dart';
import '../models/product.dart';

/// خطأ استيراد CSV
class CsvImportException implements Exception {
  CsvImportException(this.message);
  final String message;
}

/// خدمة تصدير/استيراد المنتجات بصيغة CSV
/// (نقية قابلة للاختبار دون اتصال)
class CsvProductService {
  CsvProductService._();

  static const String header =
      'id,name,description,price,discountPrice,categoryId,stock,isFeatured,sku,brand,weight,soldCount';

  /// تحويل قائمة المنتجات إلى نص CSV
  static String export(List<Product> products) {
    final buffer = StringBuffer();
    buffer.writeln(header);
    for (final p in products) {
      final row = [
        _escape(p.id),
        _escape(p.name),
        _escape(p.description),
        '${p.price}',
        p.discountPrice?.toString() ?? '',
        _escape(p.categoryId),
        '${p.stock}',
        p.isFeatured ? 'true' : 'false',
        _escape(p.sku),
        _escape(p.brand),
        p.weight?.toString() ?? '',
        '${p.soldCount}',
      ];
      buffer.writeln(row.join(','));
    }
    return buffer.toString();
  }

  /// تحليل نص CSV إلى قائمة منتجات جاهزة للحفظ
  static List<Product> parse(String csv) {
    final lines = csv.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return const [];
    var start = 0;
    if (lines.first.trim() == header) start = 1;

    final products = <Product>[];
    for (var i = start; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final cols = _splitRow(line);
      if (cols.length < 5) {
        throw CsvImportException('سطر $i غير صالح: حقول ناقصة');
      }
      final id = cols[0];
      final name = cols[1];
      if (id.isEmpty || name.isEmpty) continue;
      products.add(
        Product(
          id: id,
          name: name,
          description: cols.length > 2 ? cols[2] : '',
          price: _parseDouble(cols[3]),
          discountPrice: cols.length > 4 && cols[4].isNotEmpty
              ? _parseDouble(cols[4])
              : null,
          images: const [],
          categoryId: cols.length > 5 ? cols[5] : '',
          stock: cols.length > 6 ? int.tryParse(cols[6]) ?? 0 : 0,
          isFeatured: cols.length > 7 && cols[7].toLowerCase() == 'true',
          sku: cols.length > 8 ? cols[8] : '',
          brand: cols.length > 9 ? cols[9] : '',
          weight: cols.length > 10 && cols[10].isNotEmpty
              ? _parseDouble(cols[10])
              : null,
          soldCount: cols.length > 11 ? int.tryParse(cols[11]) ?? 0 : 0,
          createdAt: DateTime.now(),
        ),
      );
    }
    return products;
  }

  /// استيراد منتجات من CSV وحفظها في Firestore
  static Future<void> importToFirestore(
    String csv, {
    ProductRepository? repository,
  }) async {
    final products = parse(csv);
    if (products.isEmpty) return;
    final repo = repository ?? FirestoreProductRepository();
    for (final product in products) {
      await repo.addProduct(product);
    }
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  /// تقسيم صف CSV مع احترام علامات التنصيص
  static List<String> _splitRow(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else if (char == '"') {
        inQuotes = true;
      } else if (char == ',') {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  static double _parseDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }
}
