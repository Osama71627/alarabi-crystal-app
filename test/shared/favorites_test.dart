import 'package:alarabi_crystal/shared/models/app_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppUser user({List<String> favorites = const []}) {
    return AppUser(
      uid: 'u1',
      name: 'أحمد',
      email: 'a@test.com',
      favorites: favorites,
    );
  }

  group('المفضلة المحلية (AppUser)', () {
    test('إضافة منتج جديد للمفضلة', () {
      final updated = user().toggleFavorite('p1');
      expect(updated, ['p1']);
    });

    test('إزالة منتج موجود', () {
      final updated = user(favorites: ['p1', 'p2']).toggleFavorite('p1');
      expect(updated, ['p2']);
    });

    test('لا تُعدّل القائمة الأصلية', () {
      final original = ['p1'];
      user(favorites: original).toggleFavorite('p2');
      expect(original, ['p1']);
    });

    test('copyWith يحتفظ بالحقول الأخرى', () {
      final u = user(favorites: ['p1']);
      final updated = u.copyWith(favorites: u.toggleFavorite('p1'));
      expect(updated.name, 'أحمد');
      expect(updated.email, 'a@test.com');
      expect(updated.uid, 'u1');
    });
  });
}
