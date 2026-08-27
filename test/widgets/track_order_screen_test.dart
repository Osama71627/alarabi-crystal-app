import 'package:alarabi_crystal/features/orders/presentation/pages/track_order_screen.dart';
import 'package:alarabi_crystal/shared/models/order.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  Future<void> pumpTrack(
    WidgetTester tester, {
    String? trackingNumber,
    Future<Order?> Function(String)? trackLookup,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TrackOrderScreen(
          trackingNumber: trackingNumber,
          trackLookup: trackLookup,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Order makeTrackedOrder({String trackingNumber = 'TRK12345'}) {
    return Order(
      id: 'ORD-1',
      userId: 'u1',
      items: [makeCartItem('p1', name: 'تمثال الكريستال', price: 200, quantity: 2)],
      total: 400,
      status: OrderStatus.shipped,
      trackingNumber: trackingNumber,
      carrier: 'SMSA',
      createdAt: DateTime(2026, 8, 5),
    );
  }

  testWidgets('يظهر إدخال رقم التتبع وزر التتبع', (tester) async {
    await pumpTrack(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('تتبع الآن'), findsOneWidget);
  });

  testWidgets('تتبع برقم صحيح يعرض حالة الشحنة ورقم التتبع', (tester) async {
    await pumpTrack(
      tester,
      trackLookup: (_) async => makeTrackedOrder(),
    );

    await tester.enterText(find.byType(TextField), 'TRK12345');
    await tester.tap(find.text('تتبع الآن'));
    await tester.pumpAndSettle();

    expect(find.text('تم الشحن'), findsOneWidget);
    expect(find.text('SMSA'), findsOneWidget);
    expect(find.text('TRK12345'), findsNWidgets(2));
    expect(find.text('تمثال الكريستال'), findsOneWidget);
    expect(find.text('2 × 200 ر.س'), findsOneWidget);
  });

  testWidgets('تتبع برقم غير موجود يعرض رسالة عدم العثور', (tester) async {
    await pumpTrack(
      tester,
      trackLookup: (_) async => null,
    );

    await tester.enterText(find.byType(TextField), 'XXXXX');
    await tester.tap(find.text('تتبع الآن'));
    await tester.pumpAndSettle();

    expect(find.text('لم نعثر على شحنة بهذا الرقم'), findsOneWidget);
  });

  testWidgets('رقم تتبع مُعبّأ مسبقاً يبدأ البحث تلقائياً', (tester) async {
    await pumpTrack(
      tester,
      trackingNumber: 'TRK12345',
      trackLookup: (_) async => makeTrackedOrder(),
    );

    expect(find.text('تم الشحن'), findsOneWidget);
    expect(find.text('TRK12345'), findsNWidgets(2));
  });

  testWidgets('طلب ملغي يعرض حالة الإلغاء', (tester) async {
    await pumpTrack(
      tester,
      trackLookup: (_) async =>
          makeTrackedOrder().copyWith(status: OrderStatus.cancelled),
    );

    await tester.enterText(find.byType(TextField), 'TRK12345');
    await tester.tap(find.text('تتبع الآن'));
    await tester.pumpAndSettle();

    expect(find.text('ملغي'), findsOneWidget);
  });
}
