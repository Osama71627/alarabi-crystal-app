import 'package:alarabi_crystal/features/offers/domain/repositories/offer_repository.dart';
import 'package:alarabi_crystal/features/offers/presentation/pages/offers_screen.dart';
import 'package:alarabi_crystal/injection.dart';
import 'package:alarabi_crystal/shared/models/offer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers.dart';

void main() {
  setUp(() {
    sl.reset();
  });

  Future<void> pumpOffers(
    WidgetTester tester,
    List<Offer> offers,
  ) async {
    sl.registerLazySingleton<OfferRepository>(
      () => FakeOfferRepository(offers),
    );
    await tester.pumpWidget(const MaterialApp(home: OffersScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('يعرض العروض عند التحميل', (tester) async {
    await pumpOffers(tester, [
      makeOffer('o1', title: 'خصم 25%', type: OfferType.percentage),
      makeOffer('o2', title: 'فلاش سيل: تمثال البجعة', type: OfferType.flash),
    ]);

    expect(find.text('خصم 25%'), findsOneWidget);
    expect(find.text('فلاش سيل: تمثال البجعة'), findsOneWidget);
  });

  testWidgets('فلترة حسب النوع تعزل العروض المطابقة', (tester) async {
    await pumpOffers(tester, [
      makeOffer('o1', title: 'خصم 25%', type: OfferType.percentage),
      makeOffer('o2', title: 'تمثال البجعة', type: OfferType.flash),
    ]);

    await tester.tap(find.text('فلاش سيل'));
    await tester.pumpAndSettle();

    expect(find.text('تمثال البجعة'), findsOneWidget);
    expect(find.text('خصم 25%'), findsNothing);
  });

  testWidgets('العروض المنتهية لا تظهر', (tester) async {
    await pumpOffers(tester, [
      makeOffer(
        'o1',
        title: 'منتهي',
        type: OfferType.flash,
        endDate: DateTime.now().subtract(const Duration(days: 1)),
      ),
      makeOffer('o2', title: 'ساري', type: OfferType.percentage),
    ]);

    expect(find.text('منتهي'), findsNothing);
    expect(find.text('ساري'), findsOneWidget);
  });

  testWidgets('عرض فلاش يعرض عدّاداً تنازلياً', (tester) async {
    await pumpOffers(tester, [
      makeOffer(
        'o1',
        title: 'فلاش سيل',
        type: OfferType.flash,
        endDate: DateTime.now().add(const Duration(hours: 5)),
      ),
    ]);

    expect(find.textContaining('ينتهي خلال'), findsOneWidget);

    // تفكيك الشجرة لإيقاف المؤقت الدوري قبل نهاية الاختبار
    await tester.pumpWidget(const SizedBox());
  });
}
