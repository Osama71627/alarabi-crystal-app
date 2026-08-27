import 'package:alarabi_crystal/features/admin/domain/repositories/admin_repository.dart';
import 'package:alarabi_crystal/shared/services/notifications_feed.dart';
import 'package:flutter_test/flutter_test.dart';

AdminNotification _n(String id, {int minutesAgo = 0}) => AdminNotification(
      id: id,
      title: id,
      body: '',
      target: NotificationTarget.all,
      createdAt: DateTime(2026, 1, 1, 12).subtract(Duration(minutes: minutesAgo)),
    );

void main() {
  group('NotificationsFeed.merge', () {
    test('يدمج قائمتين بلا تكرار', () {
      final result = NotificationsFeed.merge(
        [_n('a'), _n('b')],
        [_n('c'), _n('a')],
      );
      expect(result.map((n) => n.id).toSet(), {'a', 'b', 'c'});
      expect(result.length, 3);
    });

    test('الأحدث أولاً', () {
      final result = NotificationsFeed.merge(
        [_n('old', minutesAgo: 10)],
        [_n('new', minutesAgo: 0)],
      );
      expect(result.first.id, 'new');
      expect(result.last.id, 'old');
    });

    test('نفس المعرّف في القائمتين لا يتكرر', () {
      final result = NotificationsFeed.merge([_n('x')], [_n('x')]);
      expect(result.length, 1);
    });

    test('يُقصّ على الحد الأعلى', () {
      final a = List.generate(5, (i) => _n('a$i', minutesAgo: i));
      final result = NotificationsFeed.merge(a, const [], limit: 3);
      expect(result.length, 3);
    });

    test('قائمتان فارغتان تعيدان قائمة فارغة', () {
      expect(NotificationsFeed.merge(const [], const []), isEmpty);
    });
  });
}
