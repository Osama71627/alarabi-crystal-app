import 'dart:io';

import 'package:alarabi_crystal/shared/services/compare_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../test_helpers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('compare_test');
    Hive.init(tempDir.path);
    await CompareService.instance.init();
    await CompareService.instance.resetForTest();
  });

  tearDown(() async {
    await Hive.close();
    tempDir.deleteSync(recursive: true);
  });

  test('إضافة منتج للمقارنة', () async {
    final result = await CompareService.instance.toggle(makeProduct('p1'));
    expect(result, CompareToggleResult.added);
    expect(CompareService.instance.contains('p1'), isTrue);
    expect(CompareService.instance.count, 1);
  });

  test('الضغط مرة أخرى يزيل المنتج', () async {
    await CompareService.instance.toggle(makeProduct('p1'));
    final result = await CompareService.instance.toggle(makeProduct('p1'));
    expect(result, CompareToggleResult.removed);
    expect(CompareService.instance.contains('p1'), isFalse);
    expect(CompareService.instance.count, 0);
  });

  test('يحدّ المقارنة بحد أقصى 4 منتجات', () async {
    for (var i = 1; i <= 4; i++) {
      final result = await CompareService.instance.toggle(makeProduct('p$i'));
      expect(result, CompareToggleResult.added);
    }
    final result =
        await CompareService.instance.toggle(makeProduct('p5'));
    expect(result, CompareToggleResult.limitReached);
    expect(CompareService.instance.count, 4);
  });

  test('المنتجات محفوظة بعد إعادة الفتح', () async {
    await CompareService.instance.toggle(makeProduct('p1'));
    await CompareService.instance.toggle(makeProduct('p2'));
    await CompareService.instance.init();
    expect(CompareService.instance.count, 2);
    expect(CompareService.instance.contains('p1'), isTrue);
    expect(CompareService.instance.contains('p2'), isTrue);
  });

  test('إزالة وإفراغ المقارنة', () async {
    await CompareService.instance.toggle(makeProduct('p1'));
    await CompareService.instance.toggle(makeProduct('p2'));
    await CompareService.instance.remove('p1');
    expect(CompareService.instance.contains('p1'), isFalse);
    expect(CompareService.instance.count, 1);

    await CompareService.instance.clear();
    expect(CompareService.instance.count, 0);
  });
}
