import 'package:alarabi_crystal/features/products/domain/repositories/product_repository.dart';
import 'package:alarabi_crystal/features/products/domain/repositories/review_repository.dart';
import 'package:alarabi_crystal/features/products/presentation/pages/product_details_screen.dart';
import 'package:alarabi_crystal/injection.dart';
import 'package:alarabi_crystal/shared/services/auth_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setUp(() {
    sl.reset();
    AuthService.instance.setGateway(FakeAuthGateway());
  });

  tearDown(() {
    AuthService.instance.setGateway(FakeAuthGateway());
  });

  Finder circleDots() => find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      );

  Future<void> pumpDetails(WidgetTester tester) async {
    sl.registerLazySingleton<ProductRepository>(
      () => FakeProductRepository([
        makeProduct(
          'p1',
          name: 'مزهريـة كريستال',
          description: 'وصف تفصيلي للمزهريـة',
          price: 250,
          images: ['img/1.jpg', 'img/2.jpg', 'img/3.jpg'],
        ),
      ]),
    );
    sl.registerLazySingleton<ReviewRepository>(() => FakeReviewRepository());
    await tester.pumpWidget(
      const MaterialApp(
        home: ProductDetailsScreen(productId: 'p1'),
      ),
    );
    // تحميل المنتج من المستودع (ميكروتاسك) + إعطاء وقت لعناصر الشبكة
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('يعرض معلومات المنتج والسعر', (tester) async {
    await pumpDetails(tester);

    expect(find.text('مزهريـة كريستال'), findsWidgets);
    expect(find.text('وصف تفصيلي للمزهريـة'), findsOneWidget);
    expect(find.textContaining('ر.س'), findsWidgets);
  });

  testWidgets('يعرض زر المشاركة وزر المفضلة', (tester) async {
    await pumpDetails(tester);

    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('صور متعددة: نقاط التصفح تعرض الصورة المختارة', (tester) async {
    await pumpDetails(tester);

    // نقطة لكل صورة
    expect(circleDots(), findsNWidgets(3));

    // الصورة الافتراضية هي الأولى
    var image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'img/1.jpg');

    // اختيار النقطة الثانية
    await tester.tap(circleDots().at(1));
    await tester.pump(const Duration(milliseconds: 100));

    image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.imageUrl, 'img/2.jpg');
  });

  testWidgets('منتج بلا صور يعرض أيقونة بديلة', (tester) async {
    sl.registerLazySingleton<ProductRepository>(
      () => FakeProductRepository([makeProduct('p1', name: 'منتج')]),
    );
    sl.registerLazySingleton<ReviewRepository>(() => FakeReviewRepository());
    await tester.pumpWidget(
      const MaterialApp(home: ProductDetailsScreen(productId: 'p1')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.diamond), findsOneWidget);
  });
}
