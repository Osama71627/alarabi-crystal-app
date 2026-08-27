import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../core/constants/app_constants.dart';
import '../../shared/models/cart_item.dart';
import '../../shared/models/coupon.dart';
import '../../shared/models/offer.dart';
import 'auth_service.dart';
import 'coupon_service.dart';
import 'offer_engine.dart';

/// خدمة السلة - تدير السلة محلياً مع مزامنة سحابية تلقائية
class CartService {
  CartService._internal();
  static final CartService instance = CartService._internal();

  Box<Map<dynamic, dynamic>>? _box;
  final List<CartItem> _items = [];
  final StreamController<List<CartItem>> _controller =
      StreamController<List<CartItem>>.broadcast();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  String? _activeUid;
  bool _cloudSyncing = false;

  /// الكوبون المطبق حالياً على السلة
  Coupon? _appliedCoupon;

  /// العرض المطبق حالياً على السلة
  Offer? _appliedOffer;

  /// بث التغييرات في السلة
  Stream<List<CartItem>> get itemsStream => _controller.stream;

  /// نسخة من عناصر السلة
  List<CartItem> get items => List.unmodifiable(_items);

  /// عدد العناصر الكلي
  int get totalItems =>
      _items.fold(0, (total, item) => total + item.quantity);

  /// إجمالي السلة الفرعي
  double get subtotal =>
      _items.fold(0, (total, item) => total + item.totalPrice);

  /// الكوبون المطبق
  Coupon? get appliedCoupon => _appliedCoupon;

  /// العرض المطبق
  Offer? get appliedOffer => _appliedOffer;

  /// رمز الكوبون المطبق
  String? get appliedCouponCode => _appliedCoupon?.code;

  /// قيمة الخصم النقدي الناتجة عن الكوبون
  double get couponDiscount => _appliedCoupon == null
      ? 0
      : CouponService.instance.calculateDiscount(_appliedCoupon!, subtotal);

  /// قيمة الخصم النقدي الناتجة عن العرض المطبق
  double get offerDiscount {
    final offer = _appliedOffer;
    if (offer == null) return 0;
    return OfferEngine.discountFor(
      offer,
      subtotal: subtotal,
      productIds: _items.map((e) => e.productId).toList(),
      categoryIds: _items
          .map((e) => e.categoryId ?? '')
          .where((c) => c.isNotEmpty)
          .toList(),
      items: _items,
      memberEligible: AuthService.instance.isLoggedIn,
    );
  }

  /// تطبيق عرض على السلة يدوياً (من شاشة العروض)
  void applyOffer(Offer offer) {
    _appliedOffer = offer;
    _manualOffer = true;
    _notify();
  }

  /// إزالة العرض المطبق
  void removeAppliedOffer() {
    _appliedOffer = null;
    _manualOffer = false;
    _notify();
  }

  /// هل العرض الحالي اختاره المستخدم بنفسه؟ (لا نستبدله تلقائياً حينها)
  bool _manualOffer = false;

  /// العروض النشطة المتاحة للتطبيق التلقائي — تُحدَّث من [refreshAutoOffers]
  List<Offer> _availableOffers = const [];

  /// تحميل العروض النشطة ثم اختيار الأفضل تلقائياً.
  /// تُستدعى عند بدء التطبيق وعند فتح السلة، حتى يستفيد العميل من عرض
  /// الإدارة بلا حاجة لدخول شاشة العروض والضغط على "تطبيق العرض".
  Future<void> refreshAutoOffers(Future<List<Offer>> Function() loadOffers) async {
    try {
      _availableOffers = await loadOffers();
      _autoSelectBestOffer();
    } catch (_) {
      // بلا اتصال: نُبقي العرض الحالي كما هو
    }
  }

  /// يختار العرض الأعلى خصماً على محتويات السلة الحالية.
  /// لا يلمس عرضاً اختاره المستخدم يدوياً، ولا يطبّق عرضاً خصمه صفر.
  void _autoSelectBestOffer() {
    if (_manualOffer) return;
    if (_items.isEmpty || _availableOffers.isEmpty) {
      if (_appliedOffer != null) {
        _appliedOffer = null;
        _notify();
      }
      return;
    }

    final productIds = _items.map((e) => e.productId).toList();
    final categoryIds = _items
        .map((e) => e.categoryId ?? '')
        .where((c) => c.isNotEmpty)
        .toList();

    Offer? best;
    var bestDiscount = 0.0;
    for (final offer in _availableOffers) {
      final discount = OfferEngine.discountFor(
        offer,
        subtotal: subtotal,
        productIds: productIds,
        categoryIds: categoryIds,
        items: _items,
        memberEligible: AuthService.instance.isLoggedIn,
      );
      if (discount > bestDiscount) {
        bestDiscount = discount;
        best = offer;
      }
    }

    if (best?.id != _appliedOffer?.id) {
      _appliedOffer = best;
      _notify();
    }
  }

  /// هل الكوبون يوفر شحناً مجانياً؟
  bool get freeShippingApplied =>
      _appliedCoupon?.type == CouponType.freeShipping;

  /// تطبيق كوبون على السلة
  void applyCoupon(Coupon coupon) {
    _appliedCoupon = coupon;
    _notify();
  }

  /// إزالة الكوبون المطبق
  void clearCoupon() {
    _appliedCoupon = null;
    _notify();
  }

  /// تهيئة السلة من التخزين المحلي
  Future<void> init() async {
    await Hive.initFlutter();
    await _openBox();
  }

  /// فتح الصندوق وتحميل البيانات (يُستخدم أيضاً في الاختبارات مع Hive.init)
  @visibleForTesting
  Future<void> initForTest() => _openBox();

  Future<void> _openBox() async {
    _box = await Hive.openBox<Map<dynamic, dynamic>>(
      AppConstants.hiveBoxCart,
    );
    _loadFromBox();
  }

  void _loadFromBox() {
    _items.clear();
    final data = _box?.values;
    if (data == null) return;
    for (final map in data) {
      _items.add(CartItem.fromMap(Map<String, dynamic>.from(map)));
    }
    _notify();
  }

  Future<void> _persist() async {
    await _box?.clear();
    for (final item in _items) {
      await _box?.put(item.productId, item.toMap());
    }
    // تغيّر محتويات السلة قد يغيّر أفضل عرض منطبق (أو يُلغيه)
    _autoSelectBestOffer();
    _notify();
    await _pushToCloud();
  }

  /// ربط السلة بمستخدم سحابي عند الدخول/الخروج
  Future<void> setActiveUser(String? uid) async {
    if (uid == _activeUid) return;
    _activeUid = uid;
    if (uid == null) return;
    await syncFromCloud(uid);
  }

  /// تحميل السلة من السحابة (مع ترحيل سلة الزائر المحلية عند أول دخول)
  Future<void> syncFromCloud(String uid) async {
    try {
      final doc = await _firestore.collection('carts').doc(uid).get();
      final cloudItems = (doc.data()?['items'] as List?) ?? const [];
      if (cloudItems.isEmpty) {
        if (_items.isNotEmpty) await _pushToCloud();
        return;
      }
      _cloudSyncing = true;
      _items.clear();
      for (final entry in cloudItems) {
        _items.add(CartItem.fromMap(Map<String, dynamic>.from(entry)));
      }
      await _persist();
      _cloudSyncing = false;
    } catch (_) {
      // بلا اتصال: ابقِ السلة المحلية
    }
  }

  /// دفع السلة الحالية إلى السحابة
  Future<void> _pushToCloud() async {
    final uid = _activeUid;
    if (uid == null || _cloudSyncing) return;
    try {
      await _firestore.collection('carts').doc(uid).set({
        'items': _items.map((item) => _cloudItemMap(item.toMap())).toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // بلا اتصال: ستُرفع لاحقاً عند التغيير القادم
    }
  }

  /// إزالة القيم الفارغة (Firestore لا يقبل null)
  Map<String, dynamic> _cloudItemMap(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) result[key] = value;
    });
    return result;
  }

  void _notify() {
    if (!_controller.isClosed) {
      _controller.add(_items);
    }
  }

  /// إضافة منتج للسلة
  Future<void> addItem(CartItem item) async {
    final index = _items.indexWhere((e) => e.productId == item.productId);
    if (index >= 0) {
      final current = _items[index];
      final newQuantity = current.quantity + item.quantity;
      final maxQuantity = current.stock > 0 ? current.stock : newQuantity;
      _items[index] = current.copyWith(
        quantity: newQuantity > maxQuantity ? maxQuantity : newQuantity,
      );
    } else {
      _items.add(item);
    }
    await _persist();
  }

  /// تعديل كمية منتج
  Future<void> updateQuantity(String productId, int quantity) async {
    final index = _items.indexWhere((e) => e.productId == productId);
    if (index < 0) return;
    if (quantity <= 0) {
      await removeItem(productId);
      return;
    }
    final current = _items[index];
    final maxQuantity = current.stock > 0 ? current.stock : quantity;
    _items[index] = current.copyWith(
      quantity: quantity > maxQuantity ? maxQuantity : quantity,
    );
    await _persist();
  }

  /// حذف منتج من السلة
  Future<void> removeItem(String productId) async {
    _items.removeWhere((e) => e.productId == productId);
    await _persist();
  }

  /// إفراغ السلة
  Future<void> clear() async {
    _items.clear();
    _appliedCoupon = null;
    _appliedOffer = null;
    _manualOffer = false;
    await _persist();
  }

  void dispose() {
    _controller.close();
  }

  /// إعادة ضبط السلة لأغراض الاختبار فقط
  @visibleForTesting
  void resetForTest() {
    _items.clear();
    _appliedCoupon = null;
    _appliedOffer = null;
    _manualOffer = false;
    _availableOffers = const [];
    _activeUid = null;
    _cloudSyncing = false;
  }
}
