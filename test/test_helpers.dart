import 'dart:async';

import 'package:alarabi_crystal/features/offers/domain/repositories/offer_repository.dart';
import 'package:alarabi_crystal/features/products/domain/repositories/product_repository.dart';
import 'package:alarabi_crystal/features/products/domain/repositories/review_repository.dart';
import 'package:alarabi_crystal/shared/models/app_user.dart';
import 'package:alarabi_crystal/shared/models/cart_item.dart';
import 'package:alarabi_crystal/shared/models/offer.dart';
import 'package:alarabi_crystal/shared/models/product.dart';
import 'package:alarabi_crystal/shared/models/review.dart';
import 'package:alarabi_crystal/shared/services/auth_exception.dart';
import 'package:alarabi_crystal/shared/services/auth_gateway.dart';

/// منتج جاهز للاختبار
Product makeProduct(
  String id, {
  String? name,
  String? description,
  double price = 100,
  double? discountPrice,
  String categoryId = 'cat-1',
  String brand = '',
  double rating = 0,
  DateTime? createdAt,
  List<String> images = const [],
  bool isFeatured = false,
  String sku = '',
  double? weight,
  int soldCount = 0,
}) {
  return Product(
    id: id,
    name: name ?? 'منتج $id',
    description: description ?? 'وصف المنتج $id',
    price: price,
    discountPrice: discountPrice,
    images: images,
    categoryId: categoryId,
    stock: 10,
    rating: rating,
    reviewCount: 0,
    specifications: const {},
    isFeatured: isFeatured,
    sku: sku,
    brand: brand,
    weight: weight,
    createdAt: createdAt,
    soldCount: soldCount,
  );
}

/// عنصر سلة جاهز للاختبار
CartItem makeCartItem(
  String productId, {
  String? name,
  double price = 100,
  int quantity = 1,
  String? categoryId,
}) {
  return CartItem(
    productId: productId,
    name: name ?? 'منتج $productId',
    price: price,
    image: '',
    quantity: quantity,
    stock: 10,
    categoryId: categoryId,
  );
}

/// عرض جاهز للاختبار
Offer makeOffer(
  String id, {
  String? title,
  String description = '',
  OfferType type = OfferType.percentage,
  double discountValue = 10,
  OfferApplicableType applicableType = OfferApplicableType.all,
  List<String> applicableIds = const [],
  double minPurchase = 0,
  double? maxDiscount,
  DateTime? endDate,
  int buyQuantity = 0,
  int getQuantity = 0,
  bool isActive = true,
}) {
  return Offer(
    id: id,
    title: title ?? 'عرض $id',
    description: description,
    type: type,
    discountValue: discountValue,
    applicableType: applicableType,
    applicableIds: applicableIds,
    minPurchase: minPurchase,
    maxDiscount: maxDiscount,
    endDate: endDate,
    buyQuantity: buyQuantity,
    getQuantity: getQuantity,
    isActive: isActive,
  );
}

/// مستودع عروض تجريبي
class FakeOfferRepository implements OfferRepository {
  FakeOfferRepository(this.offers);

  final List<Offer> offers;

  @override
  Future<List<Offer>> getActiveOffers() async {
    final now = DateTime.now();
    return offers
        .where((o) => o.isActive && (o.endDate?.isAfter(now) ?? true))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
  }

  @override
  Future<List<Offer>> getAllOffers() async => offers;

  @override
  Stream<List<Offer>> watchOffers() async* {
    yield offers;
  }

  @override
  Future<void> addOffer(Offer offer) async => offers.add(offer);

  @override
  Future<void> updateOffer(Offer offer) async {
    final index = offers.indexWhere((o) => o.id == offer.id);
    if (index >= 0) offers[index] = offer;
  }

  @override
  Future<void> deleteOffer(String id) async {
    offers.removeWhere((o) => o.id == id);
  }
}

/// بوابة مصادقة تجريبية في الذاكرة
class FakeAuthGateway implements AuthGateway {
  final Map<String, AuthAccount> accounts = {};
  final Map<String, String> passwords = {};
  final Map<String, AppUser> users = {};
  final Map<String, List<String>> favoritesStore = {};
  late final StreamController<String?> _uidController;

  String? currentUid;

  FakeAuthGateway() {
    _uidController = StreamController<String?>.broadcast(
      onListen: () {
        // بث الجلسة الحالية فور الاشتراك (مثل Firebase)
        if (currentUid != null) _uidController.add(currentUid);
      },
    );
  }

  /// إنشاء حساب وتسجيل الدخول مباشرة (لترتيب حالات الاختبار)
  /// البريد موثَّق افتراضياً هنا لأن الدالة تمثّل جلسة موجودة مسبقاً، وليست
  /// تسجيلاً جديداً يحتاج بوابة التحقق
  Future<void> seedUser({
    required String uid,
    required String name,
    required String email,
    List<String> favorites = const [],
    bool emailVerified = true,
  }) async {
    accounts[uid] =
        AuthAccount(uid: uid, name: name, email: email, emailVerified: emailVerified);
    passwords[uid] = '123456';
    users[uid] = AppUser(
      uid: uid,
      name: name,
      email: email,
      favorites: favorites,
      createdAt: DateTime(2024),
    );
    favoritesStore[uid] = [...favorites];
    currentUid = uid;
    _uidController.add(uid);
  }

  /// محاكاة وجود حساب دون تسجيل الدخول
  void registerAccount({
    required String uid,
    required String name,
    required String email,
    String password = '123456',
    bool emailVerified = false,
  }) {
    accounts[uid] =
        AuthAccount(uid: uid, name: name, email: email, emailVerified: emailVerified);
    passwords[uid] = password;
  }

  /// محاكاة نجاح التحقق من البريد بكود (لأغراض الاختبار فقط)
  void setEmailVerifiedForTest(String uid, bool verified) {
    final a = accounts[uid];
    if (a == null) return;
    accounts[uid] = AuthAccount(
      uid: a.uid,
      name: a.name,
      email: a.email,
      phone: a.phone,
      avatar: a.avatar,
      emailVerified: verified,
    );
  }

  void signOutFake() {
    currentUid = null;
    _uidController.add(null);
  }

  @override
  Stream<String?> get authUidStream => _uidController.stream;

  @override
  Future<AuthAccount> currentAccountInfo() async =>
      currentUid == null ? const AuthAccount(uid: '') : accounts[currentUid]!;

  @override
  Future<AuthAccount> signInWithEmail(String email, String password) async {
    final trimmedEmail = email.trim();
    final match = accounts.values.where((a) => a.email == trimmedEmail).toList();
    if (match.isEmpty) {
      throw AuthException('لا يوجد حساب بهذا البريد الإلكتروني');
    }
    if (passwords[match.first.uid] != password) {
      throw AuthException('كلمة المرور غير صحيحة');
    }
    currentUid = match.first.uid;
    _uidController.add(currentUid);
    return match.first;
  }

  @override
  Future<AuthAccount> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim();
    final already = accounts.values.where((a) => a.email == trimmedEmail).toList();
    if (already.isNotEmpty) {
      throw AuthException('هذا البريد مسجل مسبقاً');
    }
    final uid = 'u${accounts.length + 1}';
    final account = AuthAccount(uid: uid, name: name, email: email);
    accounts[uid] = account;
    passwords[uid] = password;
    favoritesStore[uid] = [];
    currentUid = uid;
    _uidController.add(uid);
    return account;
  }

  @override
  Future<void> signOut() => Future.sync(() => signOutFake());

  @override
  Future<void> resetPassword(String email) async {
    final exists = accounts.values.any((a) => a.email == email);
    if (!exists) throw AuthException('لا يوجد حساب بهذا البريد الإلكتروني');
  }

  @override
  Future<AppUser?> fetchUser(String uid) async => users[uid];

  @override
  Future<void> saveUser(AppUser user) async {
    users[user.uid] = user;
    favoritesStore[user.uid] = [...user.favorites];
  }

  @override
  Future<bool> reloadEmailVerified() async {
    if (currentUid == null) return false;
    return accounts[currentUid]?.emailVerified ?? false;
  }
}

/// مستودع تقييمات تجريبي
class FakeReviewRepository implements ReviewRepository {
  FakeReviewRepository([List<Review> reviews = const []]) : _reviews = List.of(reviews);

  final List<Review> _reviews;

  @override
  Stream<List<Review>> watchReviews(String productId) async* {
    yield _reviews.where((r) => r.productId == productId).toList();
  }

  @override
  Future<void> addReview(Review review) async {
    _reviews.add(review);
  }
}

/// مستودع منتجات تجريبي
class FakeProductRepository implements ProductRepository {
  FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<List<Product>> getProducts() async => products;

  @override
  Future<List<Product>> getProductsByCategory(String categoryId) async =>
      products.where((p) => p.categoryId == categoryId).toList();

  @override
  Future<Product?> getProductById(String id) async {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<Product>> getFeaturedProducts() async =>
      products.where((p) => p.isFeatured).toList();

  @override
  Future<List<Product>> getNewArrivals() async => products;

  @override
  Future<List<Product>> getBestSellers() async => products;

  @override
  Future<List<Product>> searchProducts(String query) async => products;

  @override
  Stream<List<Product>> watchProducts() async* {
    yield products;
  }

  @override
  Future<void> addProduct(Product product) async => products.add(product);

  @override
  Future<void> updateProduct(Product product) async {
    final index = products.indexWhere((p) => p.id == product.id);
    if (index >= 0) products[index] = product;
  }

  @override
  Future<void> deleteProduct(String id) async {
    products.removeWhere((p) => p.id == id);
  }
}
