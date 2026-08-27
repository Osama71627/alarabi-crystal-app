import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// قائمة أمنيات مشتركة (نسخة عامة القراءة من مفضلة أحد المستخدمين)
class SharedWishlist {
  const SharedWishlist({required this.ownerName, required this.productIds});

  final String ownerName;
  final List<String> productIds;
}

/// خدمة مشاركة قائمة الأمنيات — تنشر نسخة عامة من مفضلة المستخدم
/// (معرّفات المنتجات فقط) بمستند مستقل قابل للقراءة للجميع، حتى لا يُكشَف
/// أي شيء آخر من ملف المستخدم الخاص
class WishlistShareService {
  WishlistShareService._internal();
  static final WishlistShareService instance = WishlistShareService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _wishlists =>
      _firestore.collection('sharedWishlists');

  /// ينشر المفضلة الحالية للمستخدم، ويرجع رمز المشاركة (لاسترجاعها لاحقاً)
  Future<String> publish(AppUser user) async {
    await _wishlists.doc(user.uid).set({
      'name': user.name,
      'productIds': user.favorites,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    return user.uid;
  }

  /// جلب قائمة أمنيات مشتركة برمزها
  Future<SharedWishlist?> fetch(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final doc = await _wishlists.doc(trimmed).get();
    if (!doc.exists) return null;
    final data = doc.data()!;
    final productIds = (data['productIds'] as List?)?.cast<String>() ?? const [];
    if (productIds.isEmpty) return null;
    return SharedWishlist(
      ownerName: data['name'] as String? ?? '',
      productIds: productIds,
    );
  }
}
