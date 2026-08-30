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

  group('NotificationsFeed.excludeBeforeJoin', () {
    final joinedAt = DateTime(2026, 1, 1, 12);

    test('يستبعد إشعاراً أُنشئ قبل انضمام المستخدم (الخلل المُبلَّغ)', () {
      final old = AdminNotification(
        id: 'old',
        title: 'قبل الانضمام',
        body: '',
        target: NotificationTarget.all,
        createdAt: joinedAt.subtract(const Duration(days: 30)),
      );
      final result = NotificationsFeed.excludeBeforeJoin([old], joinedAt);
      expect(result, isEmpty);
    });

    test('يُبقي إشعاراً أُنشئ بعد انضمام المستخدم', () {
      final fresh = AdminNotification(
        id: 'fresh',
        title: 'بعد الانضمام',
        body: '',
        target: NotificationTarget.all,
        createdAt: joinedAt.add(const Duration(days: 1)),
      );
      final result = NotificationsFeed.excludeBeforeJoin([fresh], joinedAt);
      expect(result.map((n) => n.id), ['fresh']);
    });

    test('إشعار في نفس لحظة الانضمام بالضبط يبقى ظاهراً', () {
      final exact = AdminNotification(
        id: 'exact',
        title: 'لحظة الانضمام',
        body: '',
        target: NotificationTarget.all,
        createdAt: joinedAt,
      );
      final result = NotificationsFeed.excludeBeforeJoin([exact], joinedAt);
      expect(result.map((n) => n.id), ['exact']);
    });

    test('إشعار بلا تاريخ معروف يبقى ظاهراً بدل إخفائه بالخطأ', () {
      final noDate = AdminNotification(
        id: 'no-date',
        title: 'بلا تاريخ',
        body: '',
        target: NotificationTarget.all,
      );
      final result = NotificationsFeed.excludeBeforeJoin([noDate], joinedAt);
      expect(result.map((n) => n.id), ['no-date']);
    });

    test('بلا تاريخ انضمام معروف (joinedAt=null) لا يُستبعَد شيء', () {
      final old = AdminNotification(
        id: 'old',
        title: 'قديم',
        body: '',
        target: NotificationTarget.all,
        createdAt: DateTime(2020),
      );
      final result = NotificationsFeed.excludeBeforeJoin([old], null);
      expect(result.map((n) => n.id), ['old']);
    });
  });
}
