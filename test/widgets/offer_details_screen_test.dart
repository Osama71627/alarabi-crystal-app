import 'package:alarabi_crystal/features/offers/domain/repositories/offer_repository.dart';
import 'package:alarabi_crystal/features/offers/presentation/pages/offer_details_screen.dart';
import 'package:alarabi_crystal/injection.dart';
import 'package:alarabi_crystal/shared/models/offer.dart';
import 'package:alarabi_crystal/shared/services/cart_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setUp(() {
    sl.reset();
    CartService.instance.resetForTest();
  });

  Future<void> pumpDetails(
    WidgetTester tester,
    String offerId,
    List<Offer> offers,
  ) async {
    sl.registerLazySingleton<OfferRepository>(
      () => FakeOfferRepository(offers),
    );
    await tester.pumpWidget(
      MaterialApp(home: OfferDetailsScreen(offerId: offerId)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('يعرض تفاصيل العرض', (tester) async {
    await pumpDetails(tester, 'o1', [
      makeOffer(
        'o1',
        title: 'خصم 25% على الكريستال',
        description: 'وصف العرض التفصيلي',
        type: OfferType.percentage,
        discountValue: 25,
      ),
    ]);

    expect(find.text('خصم 25% على الكريستال'), findsOneWidget);
    expect(find.text('وصف العرض التفصيلي'), findsOneWidget);
    expect(find.text('-25%'), findsOneWidget);
    expect(find.text('تطبيق العرض'), findsOneWidget);
    expect(find.text('تسوق الآن'), findsOneWidget);
  });

  testWidgets('تطبيق العرض يضيفه إلى السلة', (tester) async {
    await pumpDetails(tester, 'o1', [
      makeOffer('o1', title: 'عرض', type: OfferType.percentage),
    ]);

    await tester.tap(find.text('تطبيق العرض'));
    await tester.pumpAndSettle();

    expect(CartService.instance.appliedOffer, isNotNull);
    expect(find.text('تم تطبيق العرض على سلتك'), findsOneWidget);
  });

  testWidgets('عرض منتهي لا يظهر', (tester) async {
    await pumpDetails(tester, 'o1', [
      makeOffer(
        'o1',
        title: 'منتهي',
        type: OfferType.flash,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);

    expect(find.text('منتهي'), findsNothing);
    expect(find.byIcon(Icons.local_offer_outlined), findsOneWidget);
  });
}
