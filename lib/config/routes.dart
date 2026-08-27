import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/pages/admin_home_screen.dart';
import '../../features/products/presentation/pages/product_details_screen.dart';
import '../../features/cart/presentation/pages/cart_screen.dart';
import '../../features/offers/presentation/pages/offers_screen.dart';
import '../../features/offers/presentation/pages/offer_details_screen.dart';
import '../../features/profile/presentation/pages/profile_screen.dart';
import '../../features/favorites/presentation/pages/favorites_screen.dart';
import '../../features/favorites/presentation/pages/shared_wishlist_screen.dart';
import '../../features/profile/presentation/pages/points_screen.dart';
import '../../features/support/presentation/pages/support_chat_screen.dart';
import '../../features/orders/presentation/pages/orders_screen.dart';
import '../../features/products/presentation/pages/products_screen.dart';
import '../../features/products/presentation/pages/categories_screen.dart';
import '../../features/products/presentation/pages/compare_screen.dart';
import '../../features/notifications/presentation/pages/notifications_screen.dart';
import '../../features/auth/presentation/pages/login_screen.dart';
import '../../features/auth/presentation/pages/register_screen.dart';
import '../../features/auth/presentation/pages/email_verification_screen.dart';
import '../../features/cart/presentation/pages/checkout_screen.dart';
import '../../features/orders/presentation/pages/order_details_screen.dart';
import '../../features/orders/presentation/pages/order_confirmation_screen.dart';
import '../../features/orders/presentation/pages/track_order_screen.dart';
import '../../features/splash/presentation/pages/splash_screen.dart';
import '../../features/onboarding/presentation/pages/onboarding_screen.dart';
import '../../core/theme/storefront_theme.dart';
import '../main_shell.dart';
import '../shared/services/auth_service.dart';

/// أسماء المسارات
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String onboarding = '/onboarding';
  static const String home = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String products = '/products';
  static const String productDetails = '/products/details';
  static const String categories = '/categories';
  static const String cart = '/cart';
  static const String checkout = '/checkout';
  static const String offers = '/offers';
  static const String offerDetails = '/offers/details';
  static const String profile = '/profile';
  static const String favorites = '/favorites';
  static const String orders = '/orders';
  static const String orderDetails = '/orders/details';
  static const String orderConfirmation = '/orders/confirmation';
  static const String trackOrder = '/orders/track';
  static const String compare = '/compare';
  static const String notifications = '/notifications';
  static const String admin = '/admin';
  static const String verifyEmail = '/verify-email';
  static const String sharedWishlist = '/shared-wishlist';
  static const String points = '/points';
  static const String supportChat = '/support-chat';

  /// روابط المنتجات مع المعامل
  static String productDetailsLink(String id, {String? heroTag}) =>
      '$productDetails?id=$id'
      '${heroTag != null && heroTag.isNotEmpty ? '&heroTag=$heroTag' : ''}';
  static String orderDetailsLink(String id) => '$orderDetails?id=$id';
  static String trackOrderLink({String? trackingNumber}) =>
      '$trackOrder${trackingNumber != null && trackingNumber.isNotEmpty ? '?trackingNumber=$trackingNumber' : ''}';
  static String offerDetailsLink(String id) => '$offerDetails?id=$id';
  static String orderConfirmationLink(String id, double total) =>
      '$orderConfirmation?id=$id&total=$total';
  static String productsByCategoryLink(String categoryId) =>
      '$products?categoryId=$categoryId';
  static String sharedWishlistLink(String code) =>
      '$sharedWishlist?code=$code';
}

/// بناء صفحة مع انتقال ناعم (تلاشي + انزلاق خفيف)
///
/// [storefront] يلفّ الصفحة بثيم المتجر الأبيض/الذهبي (هوية العلامة
/// التجارية للعميل) — يُعطَّل فقط لمسارات لوحة تحكم الإدارة التي تحتفظ
/// بهويتها الزرقاء المستقلة.
Page<T> _page<T>({
  required Widget child,
  String? name,
  bool fullscreenDialog = false,
  bool storefront = true,
}) {
  final content = storefront ? StorefrontTheme(child: child) : child;
  return CustomTransitionPage<T>(
    name: name,
    fullscreenDialog: fullscreenDialog,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.05),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    child: content,
  );
}

/// إعدادات التوجيه الرئيسية
class AppRouter {
  AppRouter._();

  /// إيقاف مؤقت لإلزامية التحقق من البريد بعد تسجيل الدخول (بطلب من
  /// المتجر) — الشاشة والكود الخلفي ما زالا موجودَين بالكامل، فقط بوابة
  /// إعادة التوجيه هنا مُعطَّلة. لإعادة التفعيل: أعد هذا القيمة إلى true
  static const bool requireEmailVerification = false;

  /// مفتاح تنقّل عام (يُستخدم من الإشعارات للتنقل خارج أي شاشة)
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// مفتاح عام لعرض إشعارات منبثقة (SnackBar) من أي مكان بلا حاجة لسياق
  /// شاشة محدّدة — يُستخدم من [InAppNotificationService]
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final GoRouter router = GoRouter(
    initialLocation: AppRoutes.splash,
    navigatorKey: navigatorKey,
    refreshListenable: AuthService.instance,
    redirect: (context, state) {
      final path = state.uri.path;
      final auth = AuthService.instance;

      // بوابة الإدارة: لا وصول لأي مسار /admin بلا صلاحية مدير
      if (path.startsWith(AppRoutes.admin)) {
        return auth.isAdmin ? null : AppRoutes.home;
      }

      // بوابة التحقق من البريد: تُطبَّق فقط على مستخدم مسجَّل دخوله ببريد
      // غير موثَّق بعد؛ الزوار (غير المسجَّلين) لا يتأثرون بها إطلاقاً
      const verificationExempt = {
        AppRoutes.splash,
        AppRoutes.onboarding,
        AppRoutes.login,
        AppRoutes.register,
        AppRoutes.verifyEmail,
      };
      if (requireEmailVerification &&
          auth.isLoggedIn &&
          !auth.isEmailVerified &&
          !verificationExempt.contains(path)) {
        return AppRoutes.verifyEmail;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) =>
            _page(child: const SplashScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (context, state) =>
            _page(child: const OnboardingScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) =>
            _page(child: const MainShell(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _page(child: const LoginScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _page(child: const RegisterScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        pageBuilder: (context, state) => _page(
          child: const EmailVerificationScreen(),
          name: state.uri.toString(),
        ),
      ),
      GoRoute(
        path: AppRoutes.products,
        pageBuilder: (context, state) {
          final categoryId = state.uri.queryParameters['categoryId'];
          return _page(
            child: ProductsScreen(categoryId: categoryId),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.productDetails,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          final heroTag = state.uri.queryParameters['heroTag'];
          return _page(
            child: ProductDetailsScreen(productId: id, heroTag: heroTag),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.categories,
        pageBuilder: (context, state) =>
            _page(child: const CategoriesScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.cart,
        pageBuilder: (context, state) =>
            _page(child: const CartScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.checkout,
        pageBuilder: (context, state) =>
            _page(child: const CheckoutScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.offers,
        pageBuilder: (context, state) =>
            _page(child: const OffersScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.offerDetails,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _page(
            child: OfferDetailsScreen(offerId: id),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) =>
            _page(child: const ProfileScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.favorites,
        pageBuilder: (context, state) =>
            _page(child: const FavoritesScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.sharedWishlist,
        pageBuilder: (context, state) {
          final code = state.uri.queryParameters['code'];
          return _page(
            child: SharedWishlistScreen(initialCode: code),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.orders,
        pageBuilder: (context, state) =>
            _page(child: const OrdersScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.orderDetails,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          return _page(
            child: OrderDetailsScreen(orderId: id),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.trackOrder,
        pageBuilder: (context, state) {
          final trackingNumber = state.uri.queryParameters['trackingNumber'];
          return _page(
            child: TrackOrderScreen(trackingNumber: trackingNumber),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.orderConfirmation,
        pageBuilder: (context, state) {
          final id = state.uri.queryParameters['id'] ?? '';
          final total =
              double.tryParse(state.uri.queryParameters['total'] ?? '') ?? 0;
          return _page(
            child: OrderConfirmationScreen(orderId: id, total: total),
            name: state.uri.toString(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.compare,
        pageBuilder: (context, state) =>
            _page(child: const CompareScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        pageBuilder: (context, state) =>
            _page(child: const NotificationsScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.points,
        pageBuilder: (context, state) =>
            _page(child: const PointsScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.supportChat,
        pageBuilder: (context, state) =>
            _page(child: const SupportChatScreen(), name: state.uri.toString()),
      ),
      GoRoute(
        path: AppRoutes.admin,
        pageBuilder: (context, state) => _page(
          child: const AdminHomeScreen(),
          name: state.uri.toString(),
          storefront: false,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
}
