import 'package:alarabi_crystal/shared/models/app_user.dart';
import 'package:alarabi_crystal/shared/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('تسجيل حساب جديد', () {
    test('ينشئ الحساب ويحفظه ويحدّث المستخدم الحالي', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);

      final user = await auth.registerWithEmail(
        name: 'أحمد',
        email: 'a@test.com',
        phone: '0555555555',
        password: '123456',
      );

      expect(user.uid, isNotEmpty);
      expect(user.name, 'أحمد');
      expect(auth.isLoggedIn, isTrue);
      expect(auth.currentUser?.email, 'a@test.com');
      expect(gateway.users.containsKey(user.uid), isTrue);
    });

    test('يرفض البريد المسجل مسبقاً برسالة واضحة', () async {
      final gateway = FakeAuthGateway();
      gateway.registerAccount(uid: 'u1', name: 'أحمد', email: 'a@test.com');
      final auth = AuthService.forTest(gateway);

      await expectLater(
        auth.registerWithEmail(
          name: 'أحمد',
          email: 'a@test.com',
          phone: '',
          password: '123456',
        ),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'هذا البريد مسجل مسبقاً',
          ),
        ),
      );
    });
  });

  group('تسجيل الدخول', () {
    test('يسجل الدخول بحساب موجود ويحمّل بياناته', () async {
      final gateway = FakeAuthGateway();
      gateway.registerAccount(uid: 'u1', name: 'سارة', email: 's@test.com');
      final auth = AuthService.forTest(gateway);

      final user = await auth.signInWithEmail(
        email: 's@test.com',
        password: '123456',
      );

      expect(user.name, 'سارة');
      expect(auth.isLoggedIn, isTrue);
    });

    test('يسجّل الدخول بحساب بدون حساب Firestore فينشئه تلقائياً', () async {
      final gateway = FakeAuthGateway();
      gateway.registerAccount(uid: 'u1', name: 'خالد', email: 'k@test.com');
      final auth = AuthService.forTest(gateway);

      final user = await auth.signInWithEmail(
        email: 'k@test.com',
        password: '123456',
      );

      expect(gateway.users.containsKey('u1'), isTrue);
      expect(user.email, 'k@test.com');
    });

    test('يرفض كلمة المرور الخاطئة', () async {
      final gateway = FakeAuthGateway();
      gateway.registerAccount(uid: 'u1', name: 'سارة', email: 's@test.com');
      final auth = AuthService.forTest(gateway);

      await expectLater(
        auth.signInWithEmail(email: 's@test.com', password: 'wrong'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'كلمة المرور غير صحيحة',
          ),
        ),
      );
      expect(auth.isLoggedIn, isFalse);
    });

    test('يرفض بريداً غير مسجل', () async {
      final auth = AuthService.forTest(FakeAuthGateway());

      await expectLater(
        auth.signInWithEmail(email: 'x@test.com', password: '123456'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'لا يوجد حساب بهذا البريد الإلكتروني',
          ),
        ),
      );
    });
  });

  group('تسجيل الخروج واستعادة كلمة المرور', () {
    test('يسجّل الخروج ويمسح المستخدم الحالي', () async {
      final gateway = FakeAuthGateway();
      await gateway.seedUser(uid: 'u1', name: 'ليلى', email: 'l@test.com');
      final auth = AuthService.forTest(gateway);
      await auth.signInWithEmail(email: 'l@test.com', password: '123456');
      expect(auth.isLoggedIn, isTrue);

      await auth.signOut();

      expect(auth.isLoggedIn, isFalse);
      expect(auth.currentUser, isNull);
    });

    test('إرسال استعادة كلمة المرور لبريد غير مسجل يرمي خطأ', () async {
      final auth = AuthService.forTest(FakeAuthGateway());

      await expectLater(
        auth.resetPassword('x@test.com'),
        throwsA(isA<AuthException>()),
      );
    });

    test('إرسال استعادة كلمة المرور لبريد مسجل لا يرمي خطأ', () async {
      final gateway = FakeAuthGateway();
      gateway.registerAccount(uid: 'u1', name: 'أحمد', email: 'a@test.com');
      final auth = AuthService.forTest(gateway);

      await auth.resetPassword('a@test.com');
    });
  });

  group('المفضلة السحابية', () {
    test('إضافة منتج للمفضلة يحفظه سحابياً', () async {
      final gateway = FakeAuthGateway();
      await gateway.seedUser(uid: 'u1', name: 'أحمد', email: 'a@test.com');
      final auth = AuthService.forTest(gateway);
      await auth.signInWithEmail(email: 'a@test.com', password: '123456');

      final updated = await auth.toggleFavorite('p1');

      expect(updated.favorites, contains('p1'));
      expect(auth.currentUser?.favorites, contains('p1'));
      expect(gateway.favoritesStore['u1'], contains('p1'));
    });

    test('الضغط مرة أخرى يزيل المنتج من المفضلة', () async {
      final gateway = FakeAuthGateway();
      await gateway.seedUser(
        uid: 'u1',
        name: 'أحمد',
        email: 'a@test.com',
        favorites: ['p1'],
      );
      final auth = AuthService.forTest(gateway);
      await auth.signInWithEmail(email: 'a@test.com', password: '123456');

      final updated = await auth.toggleFavorite('p1');

      expect(updated.favorites, isNot(contains('p1')));
      expect(gateway.favoritesStore['u1'], isNot(contains('p1')));
    });

    test('تبديل المفضلة دون تسجيل دخول يرمي خطأ', () async {
      final auth = AuthService.forTest(FakeAuthGateway());

      await expectLater(
        auth.toggleFavorite('p1'),
        throwsA(
          isA<AuthException>().having(
            (e) => e.message,
            'message',
            'يجب تسجيل الدخول أولاً',
          ),
        ),
      );
    });
  });

  group('مراقبة حالة تسجيل الدخول', () {
    test('يُصدر المستخدم عند الدخول و null عند الخروج', () async {
      final gateway = FakeAuthGateway();
      gateway.registerAccount(uid: 'u1', name: 'أحمد', email: 'a@test.com');
      final auth = AuthService.forTest(gateway);

      final emitted = <String?>[];
      final sub = auth.authStateChanges.listen((user) {
        emitted.add(user?.uid);
      });

      await auth.signInWithEmail(email: 'a@test.com', password: '123456');
      await auth.signOut();
      await Future<void>.delayed(Duration.zero);

      expect(emitted, ['u1', null]);
      await sub.cancel();
    });

    test('السماع مع جلسة موجودة يُصدر المستخدم الحالي فوراً', () async {
      final gateway = FakeAuthGateway();
      await gateway.seedUser(uid: 'u1', name: 'أحمد', email: 'a@test.com');
      final auth = AuthService.forTest(gateway);

      final emitted = <String?>[];
      final sub = auth.authStateChanges.listen((user) {
        emitted.add(user?.uid);
      });

      await Future<void>.delayed(Duration.zero);

      expect(emitted, ['u1']);
      expect(auth.currentUser?.name, 'أحمد');
      await sub.cancel();
    });

    test('فشل جلب بيانات المستخدم (خطأ شبكة/صلاحيات) لا يُسقط التطبيق',
        () async {
      final gateway = _ThrowingFetchGateway();
      await gateway.seedUser(uid: 'u1', name: 'أحمد', email: 'a@test.com');
      final auth = AuthService.forTest(gateway);

      var errorReachedListener = false;
      final emitted = <String?>[];
      final sub = auth.authStateChanges.listen(
        (user) => emitted.add(user?.uid),
        onError: (_) => errorReachedListener = true,
      );

      await Future<void>.delayed(Duration.zero);

      expect(errorReachedListener, isFalse);
      expect(emitted, [null]);
      expect(auth.isLoggedIn, isFalse);
      await sub.cancel();
    });
  });

  group('حساب المدير (الأمان)', () {
    // لا يوجد أي منطق ترقية تلقائية للإدارة بالتطبيق — صلاحية admin تُمنح
    // فقط بتعديل حقل role يدوياً في Firestore (Console)، أو من مدير حالي
    // لاحقاً عبر لوحة التحكم. هذا يمنع أي مستخدم من ترقية نفسه ذاتياً
    // بمجرد معرفة بريد إلكتروني معيّن.
    test('التسجيل ببريد admin@gmail.com لا يمنح صلاحية إدارة تلقائياً', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);

      final user = await auth.registerWithEmail(
        name: 'شخص عادي',
        email: 'admin@gmail.com',
        phone: '',
        password: 'anypassword',
      );

      expect(user.isAdmin, isFalse);
      expect(auth.isAdmin, isFalse);
    });

    test('تسجيل الدخول ببريد غير موجود مرفوض دائماً (لا إنشاء تلقائي)', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);

      await expectLater(
        auth.signInWithEmail(
          email: 'someone@random.com',
          password: 'anything',
        ),
        throwsA(isA<AuthException>()),
      );
      expect(auth.isLoggedIn, isFalse);
      expect(gateway.accounts.isEmpty, isTrue,
          reason: 'لا يُنشأ حساب ولا يُسمح بدخول أحدهم');
    });

    test('مستخدم مُعيَّن مديراً يدوياً في Firestore يحتفظ بصلاحيته عند الدخول',
        () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);
      // محاكاة حساب أُنشئ عادياً ثم رُقّي يدوياً من Firebase Console
      gateway.registerAccount(
        uid: 'admin1',
        name: 'المدير',
        email: 'owner@store.com',
        password: 'realPassword1',
      );
      gateway.users['admin1'] = const AppUser(
        uid: 'admin1',
        name: 'المدير',
        email: 'owner@store.com',
        role: UserRole.admin,
      );

      final user = await auth.signInWithEmail(
        email: 'owner@store.com',
        password: 'realPassword1',
      );

      expect(user.isAdmin, isTrue);
      expect(auth.isAdmin, isTrue);
    });
  });

  group('التحقق من البريد الإلكتروني', () {
    test('حساب جديد غير موثَّق البريد افتراضياً', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);

      await auth.registerWithEmail(
        name: 'سارة',
        email: 'sara@test.com',
        phone: '0555555555',
        password: '123456',
      );

      expect(auth.isEmailVerified, isFalse);
    });

    test('تسجيل الدخول بحساب موثَّق مسبقاً يعكس ذلك فوراً', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);
      gateway.registerAccount(
        uid: 'u1',
        name: 'خالد',
        email: 'khaled@test.com',
        emailVerified: true,
      );

      await auth.signInWithEmail(email: 'khaled@test.com', password: '123456');

      expect(auth.isEmailVerified, isTrue);
    });

    test('refreshEmailVerified يحدّث الحالة بعد نجاح التحقق بالكود', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);
      await auth.registerWithEmail(
        name: 'سارة',
        email: 'sara2@test.com',
        phone: '',
        password: '123456',
      );
      expect(auth.isEmailVerified, isFalse);

      // محاكاة نجاح التحقق من الكود عبر Cloud Function (Admin SDK يعلّم
      // الحساب موثَّقاً بالخادم) — العميل يعيد التحميل بعدها فقط
      gateway.setEmailVerifiedForTest(gateway.currentUid!, true);
      await auth.refreshEmailVerified();

      expect(auth.isEmailVerified, isTrue);
    });

    test('تسجيل الخروج يعيد ضبط حالة التحقق', () async {
      final gateway = FakeAuthGateway();
      final auth = AuthService.forTest(gateway);
      gateway.registerAccount(
        uid: 'u1',
        name: 'خالد',
        email: 'khaled2@test.com',
        emailVerified: true,
      );
      await auth.signInWithEmail(email: 'khaled2@test.com', password: '123456');
      expect(auth.isEmailVerified, isTrue);

      await auth.signOut();

      expect(auth.isEmailVerified, isFalse);
    });
  });
}

/// بوابة تُحاكي فشل جلب بيانات المستخدم من Firestore (شبكة/صلاحيات) عند بدء
/// التطبيق مع جلسة مُسجَّلة مسبقاً — تحديداً السيناريو الذي كان يُسقط
/// التطبيق فور فتحه على جهاز حقيقي قبل معالجة الخطأ في [AuthService]
class _ThrowingFetchGateway extends FakeAuthGateway {
  @override
  Future<AppUser?> fetchUser(String uid) => throw Exception('network error');
}
