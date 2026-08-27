import 'package:alarabi_crystal/features/admin/domain/admin_stats.dart';
import 'package:alarabi_crystal/shared/models/app_user.dart';
import 'package:alarabi_crystal/shared/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  group('AdminStatsCalculator', () {
    final now = DateTime(2025, 5, 15, 12);

    Order makeOrder({
      required String id,
      required double total,
      required DateTime createdAt,
      OrderStatus status = OrderStatus.delivered,
    }) {
      return Order(
        id: id,
        userId: 'u1',
        items: const [],
        total: total,
        status: status,
        createdAt: createdAt,
      );
    }

    test('يحسب مبيعات اليوم والشهر والسنة وعدد الطلبات', () {
      final stats = AdminStatsCalculator.calculate(
        orders: [
          makeOrder(
            id: 'o1',
            total: 100,
            createdAt: DateTime(2025, 5, 15, 10),
          ),
          makeOrder(
            id: 'o2',
            total: 50,
            createdAt: DateTime(2025, 5, 10),
          ),
          makeOrder(
            id: 'o3',
            total: 200,
            createdAt: DateTime(2024, 12, 1),
          ),
        ],
        users: const [],
        products: const [],
        now: now,
      );

      expect(stats.salesToday, 100);
      expect(stats.salesThisMonth, 150);
      expect(stats.salesThisYear, 150);
      expect(stats.ordersCount, 3);
    });

    test('الطلبات الملغاة والمرتجعة لا تُحتسب مبيعات', () {
      final stats = AdminStatsCalculator.calculate(
        orders: [
          makeOrder(
            id: 'o1',
            total: 100,
            createdAt: DateTime(2025, 5, 15),
            status: OrderStatus.cancelled,
          ),
          makeOrder(
            id: 'o2',
            total: 50,
            createdAt: DateTime(2025, 5, 15),
            status: OrderStatus.returned,
          ),
        ],
        users: const [],
        products: const [],
        now: now,
      );

      expect(stats.salesToday, 0);
      expect(stats.salesThisMonth, 0);
      expect(stats.ordersCount, 2);
    });

    test('يعدّ الطلبات المعلقة والمستخدمين الجدد', () {
      final stats = AdminStatsCalculator.calculate(
        orders: [
          makeOrder(
            id: 'o1',
            total: 10,
            createdAt: DateTime(2025, 5, 15),
            status: OrderStatus.pending,
          ),
        ],
        users: [
          AppUser(
            uid: 'u1',
            name: 'أ',
            email: 'a@a.com',
            createdAt: DateTime(2025, 5, 15),
          ),
          AppUser(
            uid: 'u2',
            name: 'ب',
            email: 'b@b.com',
            createdAt: DateTime(2025, 5, 1),
          ),
          AppUser(
            uid: 'u3',
            name: 'ج',
            email: 'c@c.com',
            createdAt: DateTime(2024, 1, 1),
          ),
        ],
        products: const [],
        now: now,
      );

      expect(stats.pendingOrders, 1);
      expect(stats.newUsersToday, 1);
      expect(stats.newUsersThisMonth, 2);
      expect(stats.totalUsers, 3);
    });

    test('يرتب الأكثر مبيعاً تنازلياً ويأخذ الخمسة الأوائل فقط', () {
      final stats = AdminStatsCalculator.calculate(
        orders: const [],
        users: const [],
        products: [
          makeProduct('p1', soldCount: 10),
          makeProduct('p2', soldCount: 30),
          makeProduct('p3', soldCount: 20),
          makeProduct('p4', soldCount: 5),
          makeProduct('p5', soldCount: 15),
          makeProduct('p6', soldCount: 100),
        ],
        now: now,
      );

      expect(stats.bestSellers.length, 5);
      expect(stats.bestSellers.first.id, 'p6');
      expect(stats.bestSellers[1].id, 'p2');
      expect(stats.bestSellers.last.id, 'p1');
    });

    test('الرسم البياني اليومي يغطي آخر 7 أيام بترتيب زمني', () {
      final stats = AdminStatsCalculator.calculate(
        orders: [
          makeOrder(
            id: 'o1',
            total: 77,
            createdAt: DateTime(2025, 5, 15),
          ),
          makeOrder(
            id: 'o2',
            total: 10,
            createdAt: DateTime(2025, 5, 9),
          ),
        ],
        users: const [],
        products: const [],
        now: now,
      );

      expect(stats.dailySales.length, 7);
      expect(stats.dailySales.first.date, DateTime(2025, 5, 9));
      expect(stats.dailySales.last.date, DateTime(2025, 5, 15));
      expect(stats.dailySales.first.amount, 10);
      expect(stats.dailySales.last.amount, 77);
    });
  });
}
