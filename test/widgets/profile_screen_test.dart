import 'package:alarabi_crystal/features/profile/presentation/pages/profile_screen.dart';
import 'package:alarabi_crystal/shared/models/app_user.dart';
import 'package:alarabi_crystal/shared/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  late FakeAuthGateway gateway;

  setUp(() {
    gateway = FakeAuthGateway();
    AuthService.instance.setGateway(gateway);
  });

  tearDown(() {
    AuthService.instance.setGateway(FakeAuthGateway());
  });

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('عميل عادي لا يرى زر لوحة التحكم', (tester) async {
    await gateway.seedUser(uid: 'u1', name: 'أحمد', email: 'a@test.com');
    await AuthService.instance
        .signInWithEmail(email: 'a@test.com', password: '123456');

    await pumpProfile(tester);

    expect(find.text('لوحة التحكم'), findsNothing);
  });

  testWidgets('المدير يرى زر لوحة التحكم', (tester) async {
    // محاكاة مستخدم رُقّي مديراً يدوياً في Firestore (Console) —
    // لا يوجد أي ترقية تلقائية بالتطبيق بعد الآن
    gateway.registerAccount(
      uid: 'admin1',
      name: 'المدير',
      email: 'admin@gmail.com',
      password: 'admin@123',
    );
    gateway.users['admin1'] = const AppUser(
      uid: 'admin1',
      name: 'المدير',
      email: 'admin@gmail.com',
      role: UserRole.admin,
    );
    await AuthService.instance.signInWithEmail(
      email: 'admin@gmail.com',
      password: 'admin@123',
    );
    expect(AuthService.instance.isAdmin, isTrue);

    await pumpProfile(tester);

    expect(find.text('لوحة التحكم'), findsOneWidget);
  });

  testWidgets('غير مسجل لا يرى زر لوحة التحكم', (tester) async {
    await pumpProfile(tester);

    expect(find.text('لوحة التحكم'), findsNothing);
  });
}
