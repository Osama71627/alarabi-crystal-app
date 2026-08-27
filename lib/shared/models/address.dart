/// عنوان التوصيل
class Address {
  const Address({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.street,
    required this.city,
    this.state = '',
    this.postalCode = '',
    this.country = 'السعودية',
    this.landmark = '',
    this.isDefault = false,
  });

  final String id;
  final String fullName;
  final String phone;
  final String street;
  final String city;
  final String state;
  final String postalCode;
  final String country;
  final String landmark;
  final bool isDefault;

  String get formatted {
    final parts = [street, landmark, city, state, country]
        .where((e) => e.trim().isNotEmpty)
        .toList();
    return parts.join('، ');
  }

  factory Address.fromMap(Map<String, dynamic> map, String id) {
    return Address(
      id: id,
      fullName: map['fullName'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      street: map['street'] as String? ?? '',
      city: map['city'] as String? ?? '',
      state: map['state'] as String? ?? '',
      postalCode: map['postalCode'] as String? ?? '',
      country: map['country'] as String? ?? 'السعودية',
      landmark: map['landmark'] as String? ?? '',
      isDefault: map['isDefault'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'phone': phone,
      'street': street,
      'city': city,
      'state': state,
      'postalCode': postalCode,
      'country': country,
      'landmark': landmark,
      'isDefault': isDefault,
    };
  }

  Address copyWith({
    String? fullName,
    String? phone,
    String? street,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? landmark,
    bool? isDefault,
  }) {
    return Address(
      id: id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      street: street ?? this.street,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      landmark: landmark ?? this.landmark,
      isDefault: isDefault ?? this.isDefault,
    );
  }
}
