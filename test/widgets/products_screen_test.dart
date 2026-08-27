import 'package:alarabi_crystal/features/products/domain/repositories/product_repository.dart';
import 'package:alarabi_crystal/features/products/presentation/pages/products_screen.dart';
import 'package:alarabi_crystal/injection.dart';
import 'package:alarabi_crystal/shared/services/auth_service.dart';
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

  Future<void> pumpScreen(WidgetTester tester) async {
    sl.registerLazySingleton<ProductRepository>(() => FakeProductRepository([
          makeProduct(
            'p1',
            name: 'مزهريـة كريستال',
            price: 100,
            categoryId: 'cat_italian_crystal',
          ),
          makeProduct(
            'p2',
            name: 'طقم كريستال',
            price: 300,
            categoryId: 'cat_italian_crystal',
            rating: 4.8,
          ),
          makeProduct(
            'p3',
            name: 'طقم مائدة',
            price: 200,
            categoryId: 'cat_cutlery',
          ),
        ]));
    await tester.pumpWidget(const MaterialApp(home: ProductsScreen()));
    await tester.pumpAndSettle();
  }

  double topOf(WidgetTester tester, String text) =>
      tester.getTopLeft(find.text(text).first).dy;

  testWidgets('يعرض المنتجات في شبكة عند التحميل', (tester) async {
    await pumpScreen(tester);

    expect(find.text('مزهريـة كريستال'), findsOneWidget);
    expect(find.text('طقم كريستال'), findsOneWidget);

    // العنصر الثالث خارج نافذة العرض في الشبكة الكسولة
    await tester.scrollUntilVisible(
      find.text('طقم مائدة'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('طقم مائدة'), findsOneWidget);
  });

  testWidgets('البحث يصفّي النتائج', (tester) async {
    await pumpScreen(tester);

    await tester.enterText(find.byType(TextField), 'كريستال');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(find.text('مزهريـة كريستال'), findsOneWidget);
    expect(find.text('طقم كريستال'), findsOneWidget);
    expect(find.text('طقم مائدة'), findsNothing);
  });

  testWidgets('فلترة الفئات من النافذة السفلية', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.text('الفئات'), findsOneWidget);
    await tester.tap(find.text('أدوات المائدة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تطبيق'));
    await tester.pumpAndSettle();

    expect(find.text('طقم مائدة'), findsOneWidget);
    expect(find.text('مزهريـة كريستال'), findsNothing);
  });

  testWidgets('التبديل بين الشبكة والقائمة', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);

    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();

    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('الترتيب بالسعر تصاعدياً يعيد ترتيب القائمة', (tester) async {
    await pumpScreen(tester);

    // قائمة العرض لتسهيل فحص الترتيب
    await tester.tap(find.byIcon(Icons.view_list));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.sort));
    await tester.pumpAndSettle();
    await tester.tap(find.text('السعر: من الأقل').last);
    await tester.pumpAndSettle();

    final p1Y = topOf(tester, 'مزهريـة كريستال');
    final p3Y = topOf(tester, 'طقم مائدة');
    final p2Y = topOf(tester, 'طقم كريستال');

    expect(p1Y < p3Y, isTrue, reason: 'الأرخص (100) قبل (200)');
    expect(p3Y < p2Y, isTrue, reason: '(200) قبل الأعلى (300)');
  });
}
