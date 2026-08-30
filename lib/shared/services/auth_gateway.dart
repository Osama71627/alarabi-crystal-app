import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/app_user.dart';
import 'auth_exception.dart';

/// حساب مسجل داخل مزود المصادقة
class AuthAccount {
  const AuthAccount({
    required this.uid,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.avatar,
    this.emailVerified = false,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? avatar;

  /// هل تم التحقق من البريد الإلكتروني (بكود عبر Cloud Function)؟
  final bool emailVerified;
}

/// واجهة خلفية المصادقة
/// تُستبدل ببديل تجريبي في الاختبارات لاختبار [AuthService] دون Firebase
abstract class AuthGateway {
  /// بث معرف المستخدم الحالي (null عند تسجيل الخروج)
  Stream<String?> get authUidStream;

  /// بيانات الحساب المسجل حالياً (قد ترجع كياناً فارغاً إن لم يوجد)
  Future<AuthAccount> currentAccountInfo();

  /// تسجيل الدخول بالبريد وكلمة المرور
  /// ترمي [AuthException] برسالة عربية عند الفشل
  Future<AuthAccount> signInWithEmail(String email, String password);

  /// إنشاء حساب جديد بالبريد وكلمة المرور
  /// ترمي [AuthException] برسالة عربية عند الفشل
  Future<AuthAccount> registerWithEmail({
    required String name,
    required String email,
    required String password,
  });

  /// تسجيل الدخول بحساب Google — يفتح نافذة اختيار الحساب، وترمي
  /// [AuthException] عند الإلغاء أو الفشل. يُنشئ حساباً جديداً تلقائياً
  /// في Firebase Auth لأول دخول (سلوك signInWithCredential القياسي).
  Future<AuthAccount> signInWithGoogle();

  /// تسجيل الخروج
  Future<void> signOut();

  /// إرسال رابط استعادة كلمة المرور
  /// ترمي [AuthException] برسالة عربية عند الفشل
  Future<void> resetPassword(String email);

  /// قراءة حساب المستخدم من Firestore (null إن لم يوجد)
  Future<AppUser?> fetchUser(String uid);

  /// حفظ حساب المستخدم في Firestore
  Future<void> saveUser(AppUser user);

  /// إعادة تحميل حالة توثيق البريد من مزود المصادقة (بعد التحقق بالكود
  /// عبر Cloud Function) وإرجاع القيمة المحدَّثة
  Future<bool> reloadEmailVerified();
}

/// التنفيذ الحقيقي عبر Firebase Auth + Firestore
class FirebaseAuthGateway implements AuthGateway {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  @override
  Stream<String?> get authUidStream =>
      _auth.authStateChanges().map((user) => user?.uid);

  @override
  Future<AuthAccount> currentAccountInfo() async =>
      _accountOf(_auth.currentUser);

  @override
  Future<AuthAccount> signInWithEmail(String email, String password) async {
    final trimmedEmail = email.trim();
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      return _accountOf(credential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e.code));
    }
  }

  @override
  Future<AuthAccount> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: trimmedEmail,
        password: password,
      );
      await credential.user!.updateDisplayName(name.trim());
      return _accountOf(credential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e.code));
    }
  }

  /// ⚠️ يتطلب إعداداً لمرة واحدة على Firebase Console لكل بيئة توقيع
  /// (تصحيح/إصدار): Project settings > عام > تطبيقك (Android) > أضف
  /// بصمة SHA-1 (و SHA-256) لشهادة التوقيع، ثم نزّل google-services.json
  /// المحدَّث. بدون هذه الخطوة يفشل الدخول بجوجل برسالة عامة (غالباً
  /// ApiException: 10 / DEVELOPER_ERROR) رغم صحة الكود تماماً.
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Future<AuthAccount> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // العميل أغلق نافذة الاختيار بنفسه — ليس خطأً يستحق رسالة حمراء
        throw AuthException('تم إلغاء تسجيل الدخول');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      return _accountOf(userCredential.user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e.code));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw AuthException('تعذر تسجيل الدخول بحساب Google، حاول مرة أخرى');
    }
  }

  @override
  Future<void> signOut() async {
    // نسجّل خروج Google أيضاً — وإلا يعيد signIn() نفس الحساب صامتاً في
    // المرة القادمة بلا نافذة اختيار، فيبدو وكأن تسجيل الخروج لم يعمل
    await _googleSignIn.signOut().catchError((_) => null);
    await _auth.signOut();
  }

  @override
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapAuthError(e.code));
    }
  }

  @override
  Future<AppUser?> fetchUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, uid);
  }

  @override
  Future<void> saveUser(AppUser user) {
    // دمج (merge) بدل استبدال المستند بالكامل — يحافظ على حقول يديرها
    // الخادم فقط وغير موجودة بنموذج AppUser (مثل نقاط الولاء) بدل مسحها
    // في كل مرة يحفظ فيها العميل بياناته الشخصية
    return _firestore
        .collection('users')
        .doc(user.uid)
        .set(_userMap(user), SetOptions(merge: true));
  }

  @override
  Future<bool> reloadEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  AuthAccount _accountOf(User? user) {
    return AuthAccount(
      uid: user?.uid ?? '',
      name: user?.displayName ?? '',
      email: user?.email ?? '',
      phone: user?.phoneNumber ?? '',
      avatar: user?.photoURL,
      emailVerified: user?.emailVerified ?? false,
    );
  }

  /// إزالة القيم الفارغة قبل الحفظ (Firestore لا يقبل null)
  Map<String, dynamic> _userMap(AppUser user) {
    final map = user.toMap();
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) result[key] = value;
    });
    return result;
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'لا يوجد حساب بهذا البريد الإلكتروني';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'user-disabled':
        return 'هذا الحساب معطل';
      case 'email-already-in-use':
        return 'هذا البريد مسجل مسبقاً';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جداً';
      case 'network-request-failed':
        return 'لا يوجد اتصال بالإنترنت';
      case 'too-many-requests':
        return 'محاولات كثيرة، حاول لاحقاً';
      default:
        return 'فشلت العملية، حاول مرة أخرى';
    }
  }
}
