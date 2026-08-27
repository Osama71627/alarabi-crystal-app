import 'package:alarabi_crystal/features/orders/presentation/pages/order_confirmation_screen.dart';
import 'package:alarabi_crystal/shared/services/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpConfirmation(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: OrderConfirmationScreen(orderId: 'ABC12345', total: 325),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('يعرض رسالة النجاح ورقم الطلب والإجمالي', (tester) async {
    await pumpConfirmation(tester);

    expect(find.text('تم استلام طلبك بنجاح!'), findsOneWidget);
    expect(find.text('رقم الطلب'), findsOneWidget);
    expect(find.text('ABC12345'), findsOneWidget);
    expect(find.text('الإجمالي'), findsOneWidget);
    expect(find.text(CurrencyFormatter.format(325)), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('يعرض زر مواصلة التسوق', (tester) async {
    await pumpConfirmation(tester);

    expect(find.text('مواصلة التسوق'), findsOneWidget);
  });
}
