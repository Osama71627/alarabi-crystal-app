import 'dart:io';

import 'package:alarabi_crystal/features/products/presentation/pages/compare_screen.dart';
import 'package:alarabi_crystal/shared/services/compare_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('compare_widget');
    Hive.init(tempDir.path);
    await CompareService.instance.init();
    await CompareService.instance.resetForTest();
  });

  tearDown(() async {
    await CompareService.instance.clear();
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  Future<void> addProducts(WidgetTester tester, List<String> ids) async {
    await tester.runAsync(() async {
      for (final id in ids) {
        await CompareService.instance.toggle(makeProduct(id, name: 'منتج $id'));
      }
    });
  }

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CompareScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('يعرض الحالة الفارغة مع زر تصفح المنتجات', (tester) async {
    await pumpScreen(tester);

    expect(find.text('لا توجد منتجات للمقارنة'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('يعرض المنتجات المضافـة في جدول المقارنة', (tester) async {
    await addProducts(tester, ['p1', 'p2']);

    await pumpScreen(tester);

    expect(find.text('منتج p1'), findsOneWidget);
    expect(find.text('منتج p2'), findsOneWidget);
    expect(find.text('التقييم'), findsOneWidget);
    expect(find.text('السعر'), findsWidgets);
  });

  testWidgets('زر الحذف يزيل منتجاً من المقارنة', (tester) async {
    await addProducts(tester, ['p1', 'p2']);

    await pumpScreen(tester);
    expect(CompareService.instance.count, 2);

    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.close).first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(CompareService.instance.count, 1);
    expect(find.text('منتج p2'), findsOneWidget);
  });

  testWidgets('زر الإفراغ يمسح كل المنتجات ويعرض الحالة الفارغة', (tester) async {
    await addProducts(tester, ['p1']);

    await pumpScreen(tester);
    await tester.runAsync(() async {
      await tester.tap(find.byIcon(Icons.delete_sweep_outlined));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();

    expect(CompareService.instance.count, 0);
    expect(find.text('لا توجد منتجات للمقارنة'), findsOneWidget);
  });
}
