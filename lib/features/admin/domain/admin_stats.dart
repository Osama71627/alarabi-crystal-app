import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/app_user.dart';

/// نقطة مبيعات لرسم بياني
class SalesPoint {
  const SalesPoint({required this.date, required this.amount});

  final DateTime date;
  final double amount;
}

/// إحصاءات لوحة التحكم
class AdminStats {
  const AdminStats({
    required this.salesToday,
    required this.salesThisMonth,
    required this.salesThisYear,
    required this.ordersCount,
    required this.pendingOrders,
    required this.newUsersToday,
    required this.newUsersThisMonth,
    required this.totalUsers,
    required this.dailySales,
    required this.bestSellers,
  });

  final double salesToday;
  final double salesThisMonth;
  final double salesThisYear;
  final int ordersCount;
  final int pendingOrders;
  final int newUsersToday;
  final int newUsersThisMonth;
  final int totalUsers;
  final List<SalesPoint> dailySales;
  final List<Product> bestSellers;
}

/// حساب إحصاءات اللوحة من البيانات الأولية (منطق نقي قابل للاختبار)
class AdminStatsCalculator {
  AdminStatsCalculator._();

  static const int _chartDays = 7;

  /// الطلبات الملغاة أو المرتجعة لا تُحتسب مبيعات
  static bool _isValidSale(Order order) {
    return order.status != OrderStatus.cancelled &&
        order.status != OrderStatus.returned;
  }

  static AdminStats calculate({
    required List<Order> orders,
    required List<AppUser> users,
    required List<Product> products,
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    final today = DateTime(current.year, current.month, current.day);
    final monthStart = DateTime(current.year, current.month, 1);
    final yearStart = DateTime(current.year, 1, 1);

    double salesToday = 0;
    double salesThisMonth = 0;
    double salesThisYear = 0;
    var pendingCount = 0;

    final dailyMap = <String, double>{};
    final chartStart = today.subtract(Duration(days: _chartDays - 1));
    for (var i = 0; i < _chartDays; i++) {
      final day = today.subtract(Duration(days: i));
      dailyMap[_dayKey(day)] = 0;
    }

    for (final order in orders) {
      final createdAt = order.createdAt;
      if (createdAt == null) continue;
      final createdDay = DateTime(
        createdAt.year,
        createdAt.month,
        createdAt.day,
      );

      if (!createdDay.isBefore(chartStart) && !createdDay.isAfter(today)) {
        dailyMap[_dayKey(createdDay)] =
            (dailyMap[_dayKey(createdDay)] ?? 0) + order.total;
      }

      if (!_isValidSale(order)) continue;
      if (order.status == OrderStatus.pending) pendingCount++;
      if (!createdDay.isBefore(today)) salesToday += order.total;
      if (!createdAt.isBefore(monthStart)) salesThisMonth += order.total;
      if (!createdAt.isBefore(yearStart)) salesThisYear += order.total;
    }
    var newUsersToday = 0;
    var newUsersThisMonth = 0;
    for (final user in users) {
      final createdAt = user.createdAt;
      if (createdAt == null) continue;
      final createdDay = DateTime(createdAt.year, createdAt.month, createdAt.day);
      if (!createdDay.isBefore(today)) newUsersToday++;
      if (!createdAt.isBefore(monthStart)) newUsersThisMonth++;
    }

    final dailySales = <SalesPoint>[];
    for (var i = _chartDays - 1; i >= 0; i--) {
      final day = today.subtract(Duration(days: i));
      dailySales.add(
        SalesPoint(date: day, amount: dailyMap[_dayKey(day)] ?? 0),
      );
    }

    final bestSellers = [...products]
      ..sort((a, b) => b.soldCount.compareTo(a.soldCount));
    final topSellers = bestSellers.take(5).toList();

    return AdminStats(
      salesToday: salesToday,
      salesThisMonth: salesThisMonth,
      salesThisYear: salesThisYear,
      ordersCount: orders.length,
      pendingOrders: pendingCount,
      newUsersToday: newUsersToday,
      newUsersThisMonth: newUsersThisMonth,
      totalUsers: users.length,
      dailySales: dailySales,
      bestSellers: topSellers,
    );
  }

  static String _dayKey(DateTime day) =>
      '${day.year}-${day.month}-${day.day}';
}
