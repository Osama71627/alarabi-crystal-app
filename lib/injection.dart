import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'features/admin/data/repositories/firestore_admin_repository.dart';
import 'features/admin/domain/repositories/admin_repository.dart';
import 'features/products/domain/repositories/category_repository.dart';
import 'features/products/data/repositories/firestore_category_repository.dart';
import 'features/products/domain/repositories/product_repository.dart';
import 'features/products/data/repositories/firestore_product_repository.dart';
import 'features/products/domain/repositories/review_repository.dart';
import 'features/products/data/repositories/firestore_review_repository.dart';
import 'features/offers/domain/repositories/offer_repository.dart';
import 'features/offers/data/repositories/firestore_offer_repository.dart';
import 'l10n/localization_service.dart';
import 'shared/services/auth_service.dart';
import 'shared/services/cart_service.dart';
import 'shared/services/compare_service.dart';
import 'shared/services/in_app_notification_service.dart';
import 'shared/services/notification_service.dart';

/// حقن التبعيات المركزي
final GetIt sl = GetIt.instance;

/// تهيئة جميع الخدمات
Future<void> setupLocator() async {
  // التخزين المحلي
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  // إدارة اللغة
  final localizationService = LocalizationService.instance;
  await localizationService.loadLanguage();
  await localizationService.loadOnboardingStatus();
  sl.registerSingleton<LocalizationService>(localizationService);

  // خدمة السلة
  final cartService = CartService.instance;
  await cartService.init();
  sl.registerLazySingleton<CartService>(() => cartService);

  // خدمة المصادقة
  sl.registerLazySingleton<AuthService>(() => AuthService.instance);

  // ربط السلة بحالة تسجيل الدخول (مزامنة سحابية)
  AuthService.instance.authStateChanges.listen(
    (user) => CartService.instance.setActiveUser(user?.uid),
    onError: (_) {},
  );

  // الإشعارات: الأذونات + تسجيل الرمز + المعالجات
  NotificationService.instance.init();

  // إشعارات منبثقة داخل التطبيق (بلا خادم) عند وصول إشعار جديد والتطبيق مفتوح
  InAppNotificationService.instance.init();

  // تطبيق أفضل عرض نشط تلقائياً على السلة (بلا حاجة لضغط "تطبيق العرض")
  unawaited(
    CartService.instance.refreshAutoOffers(
      () => sl<OfferRepository>().getActiveOffers(),
    ),
  );

  // خدمة المقارنة (حفظ محلي)
  await CompareService.instance.init();
  sl.registerLazySingleton<CompareService>(() => CompareService.instance);

  // مستودع المنتجات (Firestore مع رجوع للبيانات التجريبية)
  sl.registerLazySingleton<ProductRepository>(
    () => FirestoreProductRepository(),
  );

  // مستودع تقييمات المنتجات
  sl.registerLazySingleton<ReviewRepository>(
    () => FirestoreReviewRepository(),
  );

  // مستودع الفئات
  sl.registerLazySingleton<CategoryRepository>(
    () => FirestoreCategoryRepository(),
  );

  // مستودع العروض
  sl.registerLazySingleton<OfferRepository>(
    () => FirestoreOfferRepository(),
  );

  // مستودع لوحة الإدارة
  sl.registerLazySingleton<AdminRepository>(
    () => FirestoreAdminRepository(),
  );
}
