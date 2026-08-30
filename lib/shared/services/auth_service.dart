import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import 'auth_exception.dart';
import 'auth_gateway.dart';

export 'auth_exception.dart';

/// خدمة المصادقة
/// تدير حالة تسجيل الدخول وحساب المستخدم في Firestore
/// عبر واجهة [AuthGateway] (قابلة للاستبدال في الاختبارات)
class AuthService extends ChangeNotifier {
  AuthService._() : _gateway = FirebaseAuthGateway();

  /// اختبارات: إنشاء خدمة ببوابة تجريبية
  @visibleForTesting
  AuthService.forTest(AuthGateway gateway) : _gateway = gateway;

  static final AuthService instance = AuthService._();

  AuthGateway _gateway;

  AppUser? _currentUser;
  bool _emailVerified = false;

  /// المستخدم الحالي (إن كان مسجلاً)
  AppUser? get currentUser => _currentUser;

  /// هل يوجد مستخدم مسجل دخوله؟
  bool get isLoggedIn => _currentUser != null;

  /// هل المستخدم الحالي مدير؟
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  /// هل تم التحقق من بريد المستخدم الحالي؟ (بكود عبر Cloud Function)
  bool get isEmailVerified => _emailVerified;

  /// استبدال البوابة لأغراض الاختبار فقط
  @visibleForTesting
  void setGateway(AuthGateway gateway) {
    _gateway = gateway;
    _currentUser = null;
    _emailVerified = false;
    notifyListeners();
  }

  /// مستمع تغيير حالة تسجيل الدخول
  ///
  /// لا يُسمح لأي خطأ هنا (فشل شبكة، صلاحيات Firestore، مستند تالف...) بأن
  /// يتسرب كاستثناء غير مُعالَج، لأن هذا التدفق يُستمع إليه عند بدء تشغيل
  /// التطبيق مباشرة (setupLocator) — أي استثناء غير مُعالَج هنا يوقف
  /// التطبيق بالكامل فور فتحه على الجهاز الحقيقي.
  Stream<AppUser?> get authStateChanges {
    return _gateway.authUidStream.asyncMap((uid) async {
      if (uid == null) {
        _currentUser = null;
        _emailVerified = false;
        notifyListeners();
        return null;
      }
      try {
        final account = await _gateway.currentAccountInfo();
        _emailVerified = account.emailVerified;
        _currentUser = await _loadUser(uid);
        // حساب أوقفته الإدارة (راجع lib/shared/models/app_user.dart) —
        // نسجّل خروجه فوراً بصمت هنا (بلا BuildContext لعرض رسالة)؛
        // signInWithEmail أدناه يعرض الرسالة الصريحة عند محاولة دخول جديدة
        if (_currentUser?.disabled == true) {
          await _gateway.signOut();
          _currentUser = null;
        }
      } catch (_) {
        _currentUser = null;
        _emailVerified = false;
      }
      notifyListeners();
      return _currentUser;
    });
  }

  /// إعادة تحميل حالة توثيق البريد من الخادم (تُستدعى بعد إدخال كود صحيح)
  Future<void> refreshEmailVerified() async {
    _emailVerified = await _gateway.reloadEmailVerified();
    notifyListeners();
  }

  /// جلب حساب المستخدم (مع إنشائه إن لم يوجد)
  ///
  /// صلاحية الإدارة لا تُمنح هنا مطلقاً — تُعيَّن يدوياً فقط بتحديث حقل
  /// role إلى 'admin' من Firebase Console (أو من مدير حالي عبر لوحة
  /// التحكم لاحقاً)، حتى لا يقدر أي مستخدم يرقّي نفسه ذاتياً.
  Future<AppUser> _loadUser(String uid) async {
    final existing = await _gateway.fetchUser(uid);
    if (existing != null) return existing;
    final account = await _gateway.currentAccountInfo();
    final user = AppUser(
      uid: uid,
      name: account.name,
      email: account.email,
      phone: account.phone,
      avatar: account.avatar,
      createdAt: DateTime.now(),
    );
    await _gateway.saveUser(user);
    return user;
  }

  /// تسجيل الدخول بالبريد وكلمة المرور
  Future<AppUser> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final account = await _gateway.signInWithEmail(email, password);
    final user = await _loadUser(account.uid);
    if (user.disabled) {
      await _gateway.signOut();
      throw AuthException('تم إيقاف هذا الحساب من قبل الإدارة، تواصل مع الدعم');
    }
    _emailVerified = account.emailVerified;
    _currentUser = user;
    notifyListeners();
    return _currentUser!;
  }

  /// إنشاء حساب جديد بالبريد وكلمة المرور
  Future<AppUser> registerWithEmail({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final account = await _gateway.registerWithEmail(
      name: name,
      email: email,
      password: password,
    );
    _emailVerified = account.emailVerified;
    final user = AppUser(
      uid: account.uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      createdAt: DateTime.now(),
    );
    await _gateway.saveUser(user);
    _currentUser = user;
    notifyListeners();
    return user;
  }

  /// تسجيل الخروج
  Future<void> signOut() async {
    await _gateway.signOut();
    _currentUser = null;
    _emailVerified = false;
    notifyListeners();
  }

  /// إرسال رابط استعادة كلمة المرور
  Future<void> resetPassword(String email) {
    return _gateway.resetPassword(email);
  }

  /// تحديث بيانات المستخدم في Firestore
  Future<void> updateUser(AppUser user) async {
    await _gateway.saveUser(user);
    _currentUser = user;
    notifyListeners();
  }

  /// تبديل منتج في المفضلة سحابياً
  Future<AppUser> toggleFavorite(String productId) async {
    final user = _currentUser;
    if (user == null) throw AuthException('يجب تسجيل الدخول أولاً');
    final updated = user.copyWith(favorites: user.toggleFavorite(productId));
    await updateUser(updated);
    return updated;
  }
}
