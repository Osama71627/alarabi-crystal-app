import 'address.dart';

/// دور المستخدم في التطبيق
enum UserRole { customer, admin }

/// المستخدم
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.phone = '',
    this.avatar,
    this.addresses = const [],
    this.favorites = const [],
    this.role = UserRole.customer,
    this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? avatar;
  final List<Address> addresses;
  final List<String> favorites;
  final UserRole role;
  final DateTime? createdAt;

  /// هل المستخدم مدير؟
  bool get isAdmin => role == UserRole.admin;

  /// العنوان الافتراضي إن وجد
  Address? get defaultAddress {
    for (final address in addresses) {
      if (address.isDefault) return address;
    }
    return addresses.isEmpty ? null : addresses.first;
  }

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    final addresses = (map['addresses'] as List?)
            ?.map((e) => Address.fromMap(
                Map<String, dynamic>.from(e), e['id']?.toString() ?? ''))
            .toList() ??
        const <Address>[];

    return AppUser(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      avatar: map['avatar'] as String?,
      addresses: addresses,
      favorites:
          (map['favorites'] as List?)?.cast<String>() ?? const [],
      role: _roleFromString(map['role'] as String? ?? 'customer'),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'addresses': addresses.map((e) => e.toMap()).toList(),
      'favorites': favorites,
      'role': role.name,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  AppUser copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatar,
    List<Address>? addresses,
    List<String>? favorites,
    UserRole? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      addresses: addresses ?? this.addresses,
      favorites: favorites ?? this.favorites,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// إضافة/إزالة منتج من المفضلة، ترجع القائمة الجديدة
  List<String> toggleFavorite(String productId) {
    if (favorites.contains(productId)) {
      return favorites.where((e) => e != productId).toList();
    }
    return [...favorites, productId];
  }

  static UserRole _roleFromString(String value) {
    return UserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UserRole.customer,
    );
  }
}
