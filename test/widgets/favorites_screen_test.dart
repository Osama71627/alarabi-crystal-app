import 'package:alarabi_crystal/features/favorites/presentation/pages/favorites_screen.dart';
import 'package:alarabi_crystal/features/products/domain/repositories/product_repository.dart';
import 'package:alarabi_crystal/injection.dart';
import 'package:alarabi_crystal/shared/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  late FakeAuthGateway gateway;

  setUp(() async {
    gateway = FakeAuthGateway();
    AuthService.instance.setGateway(gateway);
    sl.reset();
  });

  tearDown(() {
    AuthService.instance.setGateway(FakeAuthGateway());
  });

  Future<void> pumpScreen(WidgetTester tester, List<String> productIds) async {
    sl.registerLazySingleton<ProductRepository>(
      () => FakeProductRepository(productIds.map((id) => makeProduct(id)).toList()),
    );
    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('يعرض حالة تسجيل الدخول عند عدم وجود مستخدم', (tester) async {
    await pumpScreen(tester, ['p1', 'p2']);

    expect(find.text('سجل دخول للمفضلة'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });

  testWidgets('يعرض المنتجات المفضلة فقط', (tester) async {
    await gateway.seedUser(
      uid: 'u1',
      name: 'أحمد',
      email: 'a@test.com',
      favorites: ['p1'],
    );
    await AuthService.instance
        .signInWithEmail(email: 'a@test.com', password: '123456');

    await pumpScreen(tester, ['p1', 'p2']);

    expect(find.text('منتج p1'), findsOneWidget);
    expect(find.text('منتج p2'), findsNothing);
  });

  testWidgets('يعرض حالة فارغة عند عدم وجود مفضلة', (tester) async {
    await gateway.seedUser(uid: 'u1', name: 'أحمد', email: 'a@test.com');
    await AuthService.instance
        .signInWithEmail(email: 'a@test.com', password: '123456');

    await pumpScreen(tester, ['p1', 'p2']);

    expect(find.text('لا توجد منتجات في المفضلة'), findsOneWidget);
  });

  testWidgets('إزالة من المفضلة من البطاقة يحدّث القائمة', (tester) async {
    await gateway.seedUser(
      uid: 'u1',
      name: 'أحمد',
      email: 'a@test.com',
      favorites: ['p1'],
    );
    await AuthService.instance
        .signInWithEmail(email: 'a@test.com', password: '123456');

    await pumpScreen(tester, ['p1', 'p2']);
    expect(find.text('منتج p1'), findsOneWidget);

    // تبديل زر المفضلة على بطاقة المنتج يزيله
    await tester.tap(find.byIcon(Icons.favorite).first);
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    expect(find.text('منتج p1'), findsNothing);
    expect(find.text('لا توجد منتجات في المفضلة'), findsOneWidget);
  });
}
